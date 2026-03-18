//! {{PROJECT_NAME}} - Commander X16 Rust Program (EXPERIMENTAL)
//!
//! Built with rust-mos, a fork of the Rust compiler targeting 6502 via llvm-mos.
//! Requires Docker: docker pull mrkits/rust-mos

#![no_std]
#![no_main]

use core::panic::PanicInfo;

// KERNAL CHROUT - print a character
const CHROUT: usize = 0xFFD2;
// KERNAL GETIN - get a character from keyboard
const GETIN: usize = 0xFFE4;

#[no_mangle]
pub extern "C" fn main() -> u8 {
    let msg = b"HELLO FROM {{PROJECT_NAME}}!\r\rBUILT WITH RUST-MOS\rPRESS ANY KEY...\r";
    for &byte in msg {
        unsafe {
            let chrout: extern "C" fn(u8) = core::mem::transmute(CHROUT);
            chrout(byte);
        }
    }

    // Wait for keypress
    loop {
        let ch: u8;
        unsafe {
            let getin: extern "C" fn() -> u8 = core::mem::transmute(GETIN);
            ch = getin();
        }
        if ch != 0 {
            break;
        }
    }

    0
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
