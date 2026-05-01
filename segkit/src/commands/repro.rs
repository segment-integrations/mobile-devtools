use clap::{Args, Subcommand};

#[derive(Subcommand)]
pub enum ReproCommand {
    /// Package current directory as a timestamped zip
    Package(PackageArgs),
    /// Package and share reproduction to GitHub or Jira
    Share(ShareArgs),
}

#[derive(Args)]
pub struct PackageArgs {
    /// Output directory for zip file
    #[arg(long, default_value = ".")]
    pub output: String,

    /// Custom zip filename
    #[arg(long)]
    pub name: Option<String>,
}

#[derive(Args)]
pub struct ShareArgs {
    /// Issue number or ID
    #[arg(long)]
    pub issue: String,

    /// Target: "github" or "jira"
    #[arg(long, default_value = "github")]
    pub target: String,

    /// Auto-generate comment with repro steps
    #[arg(long, default_value_t = false)]
    pub comment: bool,

    /// GitHub repo (format: owner/repo)
    #[arg(long)]
    pub repo: Option<String>,
}

pub fn run(cmd: ReproCommand) -> Result<(), Box<dyn std::error::Error>> {
    match cmd {
        ReproCommand::Package(_args) => {
            eprintln!("segkit repro package is not yet implemented");
            std::process::exit(1);
        }
        ReproCommand::Share(_args) => {
            eprintln!("segkit repro share is not yet implemented");
            std::process::exit(1);
        }
    }
}
