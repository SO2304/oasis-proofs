//! OASIS on-silicon test firmware — STAGE B (T0..T6) for RP2040.
//!
//! Runs OASIS's own `no_std` code on real silicon and emits one parsable log
//! line per test over USB-CDC:
//!   OASIS|<board_id>|<test_id>|PASS|FAIL|<value>|<unit>|<git_hash>
//!
//! Host control bytes: 'r' = run the full suite now, 'b' = reboot to BOOTSEL.
//!
//! Test vectors (T1/T2/T3) were locked on the host from oasis-rt's own output
//! and checked against the published RFC anchors before being embedded here:
//!   T1 ChaCha20-Poly1305 RFC 8439 §2.8.2 — ct||tag byte-for-byte (tag==RFC).
//!   T2 X25519 RFC 7748 §6.1 — Alice/Bob public keys byte-for-byte.
//!   T3 Ed25519 (ed25519-compact) — deterministic KAT (fixed seed), + tamper
//!      reject. NOT an RFC-8032 numbered vector (honest scope).

#![no_std]
#![no_main]

extern crate alloc;

use core::fmt::Write as _;
use rp2040_hal as hal;

// Any crash (panic OR hardfault) reboots into BOOTSEL instead of freezing the
// CPU. The board is then immediately reflashable and the failure is VISIBLE
// (an RPI-RP2 volume reappears), instead of a silent dead USB port.
#[panic_handler]
fn on_panic(_info: &core::panic::PanicInfo) -> ! {
    hal::rom_data::reset_to_usb_boot(0, 0);
    loop {}
}
#[cortex_m_rt::exception]
unsafe fn HardFault(_ef: &cortex_m_rt::ExceptionFrame) -> ! {
    hal::rom_data::reset_to_usb_boot(0, 0);
    loop {}
}

use embedded_alloc::Heap;
use hal::clocks::Clock;
use hal::pac;
use usb_device::class_prelude::UsbBusAllocator;
use usb_device::device::{StringDescriptors, UsbDevice};
use usb_device::prelude::{UsbDeviceBuilder, UsbVidPid};
use usbd_serial::SerialPort;

use ed25519_compact::{KeyPair, Seed, Signature};
use oasis_rt::hyper_state::{agent_new, inject_sensory};
use oasis_rt::mesh::{
    mesh_v10_pubkey_from_seed, mesh_v10_sign, mesh_v10_verify, MeshDecision, MeshEdSeed,
    MeshMacKey, MeshPubRegistry, MeshRouter,
};
use oasis_rt::spore_crypto::{decrypt_envelope, encrypt_envelope_with_nonce, x25519_pub_from_priv};
use oasis_rt::vitality::{Vitality, VitalityState};

#[global_allocator]
static HEAP: Heap = Heap::empty();

#[link_section = ".boot2"]
#[used]
pub static BOOT2: [u8; 256] = rp2040_boot2::BOOT_LOADER_W25Q080;

const XTAL_HZ: u32 = 12_000_000;
const BOARD_ID: &str = env!("OASIS_BOARD_ID");
const GIT_HASH: &str = env!("OASIS_GIT_HASH");

// ── Locked vectors (from the host locker; see module docs) ──────────────────
const T1_CTTAG_HEX: &str = "d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b61161ae10b594f09e26a7e902ecbd0600691";
const T2_ALICE_HEX: &str = "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a";
const T2_BOB_HEX: &str = "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f";
const T3_PUB_HEX: &str = "79b5562e8fe654f94078b112e8a98ba7901f853ae695bed7e0e3910bad049664";
const T3_SIG_HEX: &str = "434cdd848c171e99eedcec3069e97a052acde9c07e22e2f52602a4c5f1d7113ccbcd37759398cf9e3d4e2f3c1efeffbb813f7cc31db215c9a603b3cc6083a50e";

type Usb = hal::usb::UsbBus;

#[hal::entry]
fn main() -> ! {
    {
        use core::mem::MaybeUninit;
        // Each MeshRouter heap-allocates a 4096-deep dedup VecDeque<u64> (~32 KB)
        // + 2 KB Bloom ≈ 34 KB. T5 is scoped so only ~2 routers live at once, but
        // we give generous margin (RP2040 has 264 KB RAM; routers are heap, stacks
        // are small).
        const HEAP_SIZE: usize = 160 * 1024;
        static mut HEAP_MEM: [MaybeUninit<u8>; HEAP_SIZE] = [MaybeUninit::uninit(); HEAP_SIZE];
        unsafe { HEAP.init(core::ptr::addr_of_mut!(HEAP_MEM) as usize, HEAP_SIZE) }
    }

    let mut pac = pac::Peripherals::take().unwrap();
    let mut watchdog = hal::Watchdog::new(pac.WATCHDOG);
    let clocks = hal::clocks::init_clocks_and_plls(
        XTAL_HZ,
        pac.XOSC,
        pac.CLOCKS,
        pac.PLL_SYS,
        pac.PLL_USB,
        &mut pac.RESETS,
        &mut watchdog,
    )
    .ok()
    .unwrap();
    let sysclk_hz = clocks.system_clock.freq().to_Hz();
    let timer = hal::Timer::new(pac.TIMER, &mut pac.RESETS, &clocks);
    let core = pac::CorePeripherals::take().unwrap();
    let measured_hz = measure_core_hz(core.SYST, &timer);

    let usb_bus = UsbBusAllocator::new(hal::usb::UsbBus::new(
        pac.USBCTRL_REGS,
        pac.USBCTRL_DPRAM,
        clocks.usb_clock,
        true,
        &mut pac.RESETS,
    ));
    let mut serial = SerialPort::new(&usb_bus);
    let mut usb_dev = UsbDeviceBuilder::new(&usb_bus, UsbVidPid(0x16c0, 0x27dd))
        .strings(&[StringDescriptors::default()
            .manufacturer("OASIS")
            .product("oasis-silicon-test")
            .serial_number(BOARD_ID)])
        .unwrap()
        .device_class(usbd_serial::USB_CLASS_CDC)
        .build();

    let mut io = Io { usb_dev, serial };
    // Run ONLY on host command 'r' (so the host opens the port at idle, never
    // during a compute burst). 'b' reboots to BOOTSEL for reflashing.
    loop {
        io.poll();
        let mut rx = [0u8; 16];
        if let Ok(n) = io.serial.read(&mut rx) {
            if rx[..n].contains(&b'b') {
                hal::rom_data::reset_to_usb_boot(0, 0);
            }
            if rx[..n].contains(&b'r') {
                run_suite(&mut io, &timer, sysclk_hz, measured_hz);
            }
        }
    }
}

/// Emit a `BEGIN` marker before a test runs. If a crash reboots the board, the
/// last BEGIN captured identifies the offending test.
fn begin(io: &mut Io, test: &str) {
    let mut l = Line::new();
    let _ = write!(l, "OASIS|{}|{}|BEGIN|-|mark|{}\r\n", BOARD_ID, test, GIT_HASH);
    io.write_all(l.bytes());
}

/// Flush-forced marker: emit, then spin the USB poll ~120 ms so the host
/// actually receives it BEFORE the next (possibly faulting) op — a crash
/// reboots faster than a normal emit flushes.
fn markf(io: &mut Io, timer: &hal::Timer, tag: &str) {
    let mut l = Line::new();
    let _ = write!(l, "OASIS|{}|T5|MARK|{}|mark|{}\r\n", BOARD_ID, tag, GIT_HASH);
    io.write_all(l.bytes());
    let t0 = timer.get_counter().ticks();
    while timer.get_counter().ticks().wrapping_sub(t0) < 120_000 {
        io.poll();
    }
}

// ── USB plumbing ────────────────────────────────────────────────────────────
struct Io<'a> {
    usb_dev: UsbDevice<'a, Usb>,
    serial: SerialPort<'a, Usb>,
}
impl Io<'_> {
    fn poll(&mut self) {
        let _ = self.usb_dev.poll(&mut [&mut self.serial]);
    }
    fn write_all(&mut self, mut data: &[u8]) {
        let mut guard: u32 = 0;
        while !data.is_empty() && guard < 400_000 {
            guard += 1;
            self.poll();
            match self.serial.write(data) {
                Ok(0) => {}
                Ok(k) => data = &data[k..],
                Err(usbd_serial::UsbError::WouldBlock) => {}
                Err(_) => break,
            }
        }
        let _ = self.serial.flush();
    }
}

struct Line {
    b: [u8; 256],
    n: usize,
}
impl Line {
    fn new() -> Self {
        Line { b: [0; 256], n: 0 }
    }
    fn bytes(&self) -> &[u8] {
        &self.b[..self.n]
    }
}
impl core::fmt::Write for Line {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        let by = s.as_bytes();
        let end = (self.n + by.len()).min(self.b.len());
        self.b[self.n..end].copy_from_slice(&by[..end - self.n]);
        self.n = end;
        Ok(())
    }
}

/// Emit one `OASIS|id|test|PASS/FAIL|value|unit|git` line.
fn emit(io: &mut Io, test: &str, pass: bool, value: core::fmt::Arguments, unit: &str) {
    let mut l = Line::new();
    let _ = write!(
        l,
        "OASIS|{}|{}|{}|{}|{}|{}\r\n",
        BOARD_ID,
        test,
        if pass { "PASS" } else { "FAIL" },
        value,
        unit,
        GIT_HASH
    );
    io.write_all(l.bytes());
}

// ── helpers ─────────────────────────────────────────────────────────────────
fn hex_eq(bytes: &[u8], expect: &str) -> bool {
    const H: &[u8; 16] = b"0123456789abcdef";
    let e = expect.as_bytes();
    if bytes.len() * 2 != e.len() {
        return false;
    }
    for (i, &b) in bytes.iter().enumerate() {
        if e[2 * i] != H[(b >> 4) as usize] || e[2 * i + 1] != H[(b & 0xf) as usize] {
            return false;
        }
    }
    true
}

struct Lcg(u64);
impl Lcg {
    fn f(&mut self) -> f64 {
        self.0 = self
            .0
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        ((self.0 >> 11) as f64) / ((1u64 << 53) as f64)
    }
}

/// median/min/max nanoseconds-per-op over K batched runs of M iterations.
fn timeit<F: FnMut()>(io: &mut Io, timer: &hal::Timer, k: usize, m: usize, mut f: F) -> (u64, u64, u64) {
    let mut s = [0u64; 16];
    let k = k.min(16);
    for slot in s.iter_mut().take(k) {
        io.poll(); // keep USB alive between batches (outside the measured window)
        let t0 = timer.get_counter().ticks();
        for _ in 0..m {
            f();
        }
        let t1 = timer.get_counter().ticks();
        *slot = (t1.wrapping_sub(t0) * 1000) / (m as u64);
    }
    let a = &mut s[..k];
    a.sort_unstable();
    (a[k / 2], a[0], a[k - 1])
}

/// Count core cycles (SysTick, core clock) across a 100 ms window of the 1 MHz
/// hardware TIMER. Both clocks derive from the same 12 MHz crystal, so this
/// checks the PLL configuration actually took effect, not crystal accuracy.
fn measure_core_hz(mut syst: cortex_m::peripheral::SYST, timer: &hal::Timer) -> u32 {
    use cortex_m::peripheral::syst::SystClkSource;
    const WINDOW_US: u64 = 100_000; // 12.5 M cycles at 125 MHz, below the 24-bit wrap
    syst.set_clock_source(SystClkSource::Core);
    syst.set_reload(0x00FF_FFFF);
    syst.clear_current();
    syst.enable_counter();
    let start = timer.get_counter().ticks();
    while timer.get_counter().ticks() == start {}
    let t0 = timer.get_counter().ticks();
    let s0 = cortex_m::peripheral::SYST::get_current();
    while timer.get_counter().ticks().wrapping_sub(t0) < WINDOW_US {}
    let s1 = cortex_m::peripheral::SYST::get_current();
    syst.disable_counter();
    let cycles = s0.wrapping_sub(s1) & 0x00FF_FFFF; // SysTick counts down
    (cycles as u64 * 1_000_000 / WINDOW_US) as u32
}

// ── the suite ────────────────────────────────────────────────────────────────
fn run_suite(io: &mut Io, timer: &hal::Timer, sysclk_hz: u32, measured_hz: u32) {
    // T0: the configured clock must match the clock measured against TIMER (±1 %).
    let clk_ok = measured_hz.abs_diff(sysclk_hz) <= sysclk_hz / 100;
    emit(
        io,
        "T0",
        clk_ok,
        format_args!("clk_cfg={}Hz,clk_measured={}Hz,usb_serial={}", sysclk_hz, measured_hz, BOARD_ID),
        "clock",
    );

    // ── T1: ChaCha20-Poly1305, RFC 8439 §2.8.2 ──
    begin(io, "T1");
    {
        let mut key = [0u8; 32];
        for (i, k) in key.iter_mut().enumerate() {
            *k = 0x80 + i as u8;
        }
        let nonce = [0x07, 0, 0, 0, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47];
        let aad = [0x50u8, 0x51, 0x52, 0x53, 0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7];
        let pt = b"Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.";
        match encrypt_envelope_with_nonce(&key, &nonce, pt, &aad) {
            Ok(env) => {
                let cttag = &env[22..];
                let ct_ok = hex_eq(cttag, T1_CTTAG_HEX);
                let rt_ok = decrypt_envelope(&key, &env, &aad).map(|d| d == pt).unwrap_or(false);
                emit(
                    io,
                    "T1",
                    ct_ok && rt_ok,
                    format_args!("rfc8439_cttag_match={},decrypt_roundtrip={}", ct_ok, rt_ok),
                    "aead",
                );
            }
            Err(e) => emit(io, "T1", false, format_args!("encrypt_err={}", e), "aead"),
        }
    }

    // ── T2: X25519 public-key derivation, RFC 7748 §6.1 ──
    begin(io, "T2");
    {
        let apriv = unhex32("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a");
        let bpriv = unhex32("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb");
        let a_ok = x25519_pub_from_priv(&apriv).map(|p| hex_eq(&p, T2_ALICE_HEX)).unwrap_or(false);
        let b_ok = x25519_pub_from_priv(&bpriv).map(|p| hex_eq(&p, T2_BOB_HEX)).unwrap_or(false);
        emit(
            io,
            "T2",
            a_ok && b_ok,
            format_args!("rfc7748_alice={},bob={}", a_ok, b_ok),
            "x25519",
        );
    }

    // ── T3: Ed25519 deterministic KAT + tamper/verify (ed25519-compact) ──
    begin(io, "T3");
    {
        let seed = unhex32("0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20");
        let kp = KeyPair::from_seed(Seed::new(seed));
        let msg = b"OASIS-silicon-T3";
        let sig = kp.sk.sign(msg, None);
        let pub_ok = hex_eq(kp.pk.as_ref(), T3_PUB_HEX);
        let sig_ok = hex_eq(sig.as_ref(), T3_SIG_HEX);
        let verify_ok = kp.pk.verify(msg, &sig).is_ok();
        let mut bad = [0u8; 64];
        bad.copy_from_slice(sig.as_ref());
        bad[0] ^= 0x01;
        let tamper_rejected = Signature::from_slice(&bad)
            .map(|s| kp.pk.verify(msg, &s).is_err())
            .unwrap_or(true);
        emit(
            io,
            "T3",
            pub_ok && sig_ok && verify_ok && tamper_rejected,
            format_args!(
                "kat_pub={},kat_sig={},verify={},tamper_rejected={}",
                pub_ok, sig_ok, verify_ok, tamper_rejected
            ),
            "ed25519",
        );
    }

    // ── T4: R14 gate — 1000 faults above threshold must all be blocked ──
    begin(io, "T4");
    {
        // Reduced from the x86 bench's 1000 faults: each R14 fault is heavy f64
        // (entropy softmax = 9 exp) and the Cortex-M0+ has NO FPU, so soft-float
        // makes it ~325 ms/fault (measured) → 1000 ≈ 5 min, 200 ≈ 65 s. 50/50
        // proves the gate identically (the property is per-fault); a standalone
        // 200/200 run is archived separately. Per-fault cost is reported by T6.
        const T4_FAULTS: usize = 50;
        let mut blocked = 0u32;
        let mut rng = Lcg(0x1234_5678_9abc_def0);
        for fault_id in 0..T4_FAULTS {
            io.poll(); // service USB EVERY iteration — one soft-float fault is slow
            if fault_id % 10 == 0 {
                // progress marker
                let mut l = Line::new();
                let _ = write!(l, "OASIS|{}|T4|PROG|{}|mark|{}\r\n", BOARD_ID, fault_id, GIT_HASH);
                io.write_all(l.bytes());
            }
            let mut agent = agent_new(fault_id % 9);
            let mut vit = VitalityState::new();
            for _ in 0..10 {
                inject_sensory(&mut agent, 0.1 + 0.05 * rng.f());
            }
            inject_sensory(&mut agent, 0.85 + 0.15 * rng.f());
            vit.update(&[(false, Vitality::Important)]);
            let signal = (agent.entropy + vit.entropy_contribution).min(1.0);
            if signal > 0.95 {
                blocked += 1;
            }
        }
        // Negative control: nominal ticks (all sensors alive, low readings) must
        // NOT be blocked, otherwise a gate that blocks everything would pass.
        // Host probe over 1000 nominal cases: signal max 0.919 < 0.95.
        let mut false_blocks = 0u32;
        let mut nominal_rng = Lcg(0x0bad_5eed_1234_5678);
        for nominal_id in 0..T4_FAULTS {
            io.poll();
            let mut agent = agent_new(nominal_id % 9);
            let mut vit = VitalityState::new();
            for _ in 0..11 {
                inject_sensory(&mut agent, 0.1 + 0.05 * nominal_rng.f());
            }
            vit.update(&[(true, Vitality::Important)]);
            let signal = (agent.entropy + vit.entropy_contribution).min(1.0);
            if signal > 0.95 {
                false_blocks += 1;
            }
        }
        emit(
            io,
            "T4",
            blocked == T4_FAULTS as u32 && false_blocks == 0,
            format_args!(
                "blocked={}/{},nominal_false_blocks={}/{},threshold=0.95",
                blocked, T4_FAULTS, false_blocks, T4_FAULTS
            ),
            "r14",
        );
    }

    // ── T5: mesh v8/v9/v0A wrap→process, dedup, forge-reject ──
    begin(io, "T5");
    {
        let fp_a = [0xAAu8; 8];
        let fp_b = [0xBBu8; 8];
        // Each MeshRouter heap-allocates ~34 KB (4096-deep dedup VecDeque + Bloom).
        // Scope every sub-test so its routers DROP before the next — only ~2 live
        // at once, well within the heap.
        {
            markf(io, timer, "v8");
            let mut a8 = MeshRouter::new(fp_a);
            let mut b8 = MeshRouter::new(fp_b);
            let e8 = a8.origin_wrap(b"oasis-v8");
            let v8_arrived = matches!(b8.process(&e8), MeshDecision::Arrived { .. });
            let v8_dedup = matches!(b8.process(&e8), MeshDecision::Drop("duplicate"));
            emit(io, "T5", v8_arrived && v8_dedup, format_args!("v8_arrived={},v8_dedup={}", v8_arrived, v8_dedup), "mesh");
        }
        {
            markf(io, timer, "v9");
            let mut a9 = MeshRouter::new_signed(fp_a, MeshMacKey([0x42u8; 32]));
            let mut b9 = MeshRouter::new_signed(fp_b, MeshMacKey([0x42u8; 32]));
            let e9 = a9.origin_wrap(b"oasis-v9");
            let v9_arrived = matches!(b9.process(&e9), MeshDecision::Arrived { .. });
            // Flip a byte of msg_id (covered by the v9 MAC; offset 6..14) and send
            // it to a fresh receiver with an empty dedup cache. Re-sending to b9
            // would be dropped as "duplicate" whatever the MAC says. The payload
            // itself is NOT covered by the v9 MAC (nor by v0A): its integrity must
            // come from the AEAD layer above the mesh.
            drop(b9);
            let mut e9t = e9.clone();
            e9t[8] ^= 0x01;
            let mut fresh9 = MeshRouter::new_signed(fp_b, MeshMacKey([0x42u8; 32]));
            let v9_tamper = matches!(fresh9.process(&e9t), MeshDecision::Drop("bad mesh mac"));
            emit(io, "T5", v9_arrived && v9_tamper, format_args!("v9_arrived={},v9_tamper_rejected={}", v9_arrived, v9_tamper), "mesh");
        }
        {
            markf(io, timer, "v0A");
            let seed_a = MeshEdSeed([0x11u8; 32]);
            let seed_b = MeshEdSeed([0x22u8; 32]);
            let seed_bad = MeshEdSeed([0x99u8; 32]);
            let pub_a = mesh_v10_pubkey_from_seed(&seed_a).unwrap();
            let mut reg_b = MeshPubRegistry::new();
            reg_b.insert(fp_a, pub_a);
            // Receiver b0 persists; sender a0 and the forger are each scoped so
            // only 2 routers are ever live at once.
            let mut b0 = MeshRouter::new_ed25519_signed(fp_b, seed_b, reg_b);
            let e0 = {
                let mut a0 = MeshRouter::new_ed25519_signed(fp_a, seed_a, MeshPubRegistry::new());
                a0.origin_wrap(b"oasis-v0A")
            };
            let v0a_arrived = matches!(b0.process(&e0), MeshDecision::Arrived { .. });
            // forger: claims fp_a but signs with the wrong seed
            let e_forged = {
                let mut forger = MeshRouter::new_ed25519_signed(fp_a, seed_bad, MeshPubRegistry::new());
                forger.origin_wrap(b"forged")
            };
            let v0a_forge_rejected = matches!(b0.process(&e_forged), MeshDecision::Drop("bad mesh signature"));
            emit(io, "T5", v0a_arrived && v0a_forge_rejected, format_args!("v0A_arrived={},v0A_forge_rejected={}", v0a_arrived, v0a_forge_rejected), "mesh");
        }
    }

    // ── T6: on-silicon timing (hardware TIMER, K=5 batches) ──
    begin(io, "T6");
    {
        // R14 one-fault signal compute
        let mut agent = agent_new(3);
        let mut vit = VitalityState::new();
        for _ in 0..10 {
            inject_sensory(&mut agent, 0.2);
        }
        let (r14_med, r14_min, r14_max) = timeit(io, timer, 5, 1, || {
            inject_sensory(&mut agent, 0.9);
            vit.update(&[(false, Vitality::Important)]);
            let _ = (agent.entropy + vit.entropy_contribution).min(1.0);
        });
        emit(io, "T6", true, format_args!("op=r14_fault,median={},min={},max={}", r14_med, r14_min, r14_max), "ns");

        // v9 origin_wrap
        let mut a9 = MeshRouter::new_signed([0xAAu8; 8], MeshMacKey([0x42u8; 32]));
        let (w_med, w_min, w_max) = timeit(io, timer, 5, 50, || {
            let _ = a9.origin_wrap(b"x");
        });
        emit(io, "T6", true, format_args!("op=v9_wrap,median={},min={},max={}", w_med, w_min, w_max), "ns");

        // v0A sign + verify
        let seed = MeshEdSeed([0x11u8; 32]);
        let pubk = mesh_v10_pubkey_from_seed(&seed).unwrap();
        let fp = [0xAAu8; 8];
        let (s_med, s_min, s_max) = timeit(io, timer, 5, 1, || {
            let _ = mesh_v10_sign(&seed, 7, fp);
        });
        emit(io, "T6", true, format_args!("op=v0A_sign,median={},min={},max={}", s_med, s_min, s_max), "ns");
        let sig = mesh_v10_sign(&seed, 7, fp).unwrap();
        let (v_med, v_min, v_max) = timeit(io, timer, 5, 1, || {
            let _ = mesh_v10_verify(&pubk, 7, fp, &sig);
        });
        emit(io, "T6", true, format_args!("op=v0A_verify,median={},min={},max={}", v_med, v_min, v_max), "ns");
    }

    emit(io, "SUITE", true, format_args!("done"), "end");
}

fn unhex32(s: &str) -> [u8; 32] {
    let mut out = [0u8; 32];
    let b = s.as_bytes();
    for (i, o) in out.iter_mut().enumerate() {
        let hi = (b[2 * i] as char).to_digit(16).unwrap() as u8;
        let lo = (b[2 * i + 1] as char).to_digit(16).unwrap() as u8;
        *o = (hi << 4) | lo;
    }
    out
}
