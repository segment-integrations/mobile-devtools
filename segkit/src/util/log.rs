pub fn info(msg: &str) {
    eprintln!("\x1b[1;34m==> {}\x1b[0m", msg);
}

pub fn warn(msg: &str) {
    eprintln!("\x1b[1;33m==> {}\x1b[0m", msg);
}

pub fn err(msg: &str) {
    eprintln!("\x1b[1;31m==> {}\x1b[0m", msg);
}
