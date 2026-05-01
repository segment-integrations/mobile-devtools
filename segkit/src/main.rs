use std::process::ExitCode;

use clap::{Parser, Subcommand};

mod delegate;

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
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    match cli.command {
        Some(Commands::Android { args }) => delegate::run("android.sh", &args),
        Some(Commands::Ios { args }) => delegate::run("ios.sh", &args),
        Some(Commands::Rn { args }) => delegate::run("rn.sh", &args),
        None => {
            println!("segkit {}", env!("CARGO_PKG_VERSION"));
            ExitCode::SUCCESS
        }
    }
}
