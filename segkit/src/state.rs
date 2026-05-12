use std::path::PathBuf;

fn home_dir() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."))
}

pub fn state_dir() -> PathBuf {
    home_dir().join(".segkit")
}

pub fn breadcrumb_exists(name: &str) -> bool {
    state_dir().join(name).exists()
}

pub fn set_breadcrumb(name: &str) {
    let dir = state_dir();
    let _ = std::fs::create_dir_all(&dir);
    let _ = std::fs::write(dir.join(name), "");
}

pub fn remove_breadcrumb(name: &str) {
    let _ = std::fs::remove_file(state_dir().join(name));
}
