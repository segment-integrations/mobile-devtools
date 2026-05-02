use std::process::ExitCode;

use clap::{Parser, Subcommand};

mod ci;
mod delegate;
mod setup;

#[derive(Parser)]
#[command(name = "segkit", version, about = "Segment SDK developer toolkit")]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Android platform commands (delegates to android.sh)
    Android {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },
    /// iOS platform commands (delegates to ios.sh)
    Ios {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },
    /// React Native commands (delegates to rn.sh)
    Rn {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },
    /// CI helper commands (wrap, summary)
    Ci {
        #[command(subcommand)]
        command: CiCommands,
    },
    /// Check and install required dependencies (devbox)
    Setup,
}

#[derive(Subcommand)]
enum CiCommands {
    /// Run a command and capture timing/exit/stderr to reports
    Wrap {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        command: Vec<String>,
    },
    /// Generate markdown summary from timing/error artifacts
    Summary {
        /// Platform name for the summary header
        #[arg(long)]
        platform: Option<String>,
        /// Device name for the summary header
        #[arg(long)]
        device: Option<String>,
    },
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    match cli.command {
        Some(Commands::Android { args }) => delegate::run("android.sh", &args),
        Some(Commands::Ios { args }) => delegate::run("ios.sh", &args),
        Some(Commands::Rn { args }) => delegate::run("rn.sh", &args),
        Some(Commands::Ci { command }) => match command {
            CiCommands::Wrap { command } => ci::wrap(&command),
            CiCommands::Summary { platform, device } => {
                ci::summary(platform.as_deref(), device.as_deref())
            }
        },
        Some(Commands::Setup) => setup::run(),
        None => {
            println!("segkit {}", env!("CARGO_PKG_VERSION"));
            ExitCode::SUCCESS
        }
    }
}
