//! Debug-build-only logging to stdout/stderr.
//! Release builds must not emit Rust prints (logcat / sensitive data); see security audit C-1.

#[macro_export]
macro_rules! dev_println {
    ($($arg:tt)*) => {
        if cfg!(debug_assertions) {
            println!($($arg)*);
        }
    };
}

#[macro_export]
macro_rules! dev_eprintln {
    ($($arg:tt)*) => {
        if cfg!(debug_assertions) {
            eprintln!($($arg)*);
        }
    };
}
