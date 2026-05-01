use std::process::{Command, ExitCode};

const DEVBOX_INSTALL_URL: &str = "https://get.jetify.com/devbox";

fn is_installed(cmd: &str) -> bool {
    which::which(cmd).is_ok()
}

fn install_devbox() -> Result<(), String> {
    eprintln!("segkit: devbox not found, installing via {DEVBOX_INSTALL_URL}");

    let curl_available = is_installed("curl");
    let wget_available = is_installed("wget");

    let status = if curl_available {
        Command::new("sh")
            .args(["-c", &format!("curl -fsSL {DEVBOX_INSTALL_URL} | bash")])
            .status()
    } else if wget_available {
        Command::new("sh")
            .args(["-c", &format!("wget -qO- {DEVBOX_INSTALL_URL} | bash")])
            .status()
    } else {
        return Err("neither curl nor wget found — cannot download devbox installer".into());
    };

    match status {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => Err(format!(
            "devbox installer exited with code {}",
            s.code().unwrap_or(-1)
        )),
        Err(e) => Err(format!("failed to run installer: {e}")),
    }
}

pub fn run() -> ExitCode {
    if is_installed("devbox") {
        println!("devbox: installed");
    } else {
        if let Err(e) = install_devbox() {
            eprintln!("segkit: {e}");
            return ExitCode::FAILURE;
        }
        if !is_installed("devbox") {
            eprintln!(
                "segkit: devbox installed but not found on PATH — you may need to restart your shell"
            );
            return ExitCode::FAILURE;
        }
        println!("devbox: installed");
    }

    ExitCode::SUCCESS
}
