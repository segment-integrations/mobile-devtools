use std::process::Command;

pub struct ExternalCli {
    pub name: &'static str,
    pub install_hint: &'static str,
}

impl ExternalCli {
    pub fn is_available(&self) -> bool {
        Command::new("which")
            .arg(self.name)
            .output()
            .is_ok_and(|o| o.status.success())
    }

    pub fn require(&self) -> Result<(), Box<dyn std::error::Error>> {
        if self.is_available() {
            Ok(())
        } else {
            Err(format!(
                "'{}' is not installed. Install it with: {}",
                self.name, self.install_hint
            )
            .into())
        }
    }
}

pub static GH: ExternalCli = ExternalCli {
    name: "gh",
    install_hint: "brew install gh",
};

pub static JIRA: ExternalCli = ExternalCli {
    name: "jira",
    install_hint: "go install github.com/ankitpokhrel/jira-cli/cmd/jira@latest",
};

pub static GIT: ExternalCli = ExternalCli {
    name: "git",
    install_hint: "brew install git",
};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn git_is_available() {
        assert!(GIT.is_available());
    }

    #[test]
    fn nonexistent_cli_is_not_available() {
        let fake = ExternalCli {
            name: "this-cli-does-not-exist-abc123",
            install_hint: "",
        };
        assert!(!fake.is_available());
    }

    #[test]
    fn require_fails_for_missing_cli() {
        let fake = ExternalCli {
            name: "this-cli-does-not-exist-abc123",
            install_hint: "brew install fake",
        };
        let err = fake.require().unwrap_err();
        assert!(err.to_string().contains("is not installed"));
        assert!(err.to_string().contains("brew install fake"));
    }
}
