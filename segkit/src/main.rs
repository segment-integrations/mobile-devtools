use std::process::ExitCode;

use clap::{Parser, Subcommand};

mod config_cmd;
mod delegate;
mod doctor;
mod init_cmd;
mod state;
mod uninstall;
mod update;
mod util;

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
    /// Metro bundler commands (delegates to metro.sh)
    Metro {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },
    /// Check environment health and report missing dependencies
    Doctor {
        /// Automatically install missing dependencies
        #[arg(long)]
        fix: bool,
    },
    /// Remove segkit and any dependencies installed by segkit
    Uninstall {
        /// Also remove dependencies installed by 'segkit doctor --fix'
        #[arg(long)]
        all: bool,
        /// Keep specific packages when using --all (e.g. --keep homebrew --keep devbox)
        #[arg(long, value_name = "PACKAGE")]
        keep: Vec<String>,
    },
    /// Scaffold a new project from a template
    Init {
        /// SDK template to use (swift)
        #[arg(long)]
        sdk: Option<String>,
        /// Project name
        #[arg(long)]
        name: Option<String>,
        /// Organization identifier prefix (bundle ID = org.name)
        #[arg(long)]
        org: Option<String>,
        /// Segment write key
        #[arg(long)]
        write_key: Option<String>,
        /// Segment SDK destination plugins to include (e.g. amplitude, firebase, mixpanel, braze, appsflyer, facebook, survicate)
        #[arg(long, value_delimiter = ',')]
        plugins: Vec<String>,
    },
    /// Update segkit to the latest version from main
    Update,
    /// View or modify project configuration (write key, plugins)
    Config {
        #[command(subcommand)]
        action: ConfigAction,
    },
}

#[derive(Subcommand)]
enum ConfigAction {
    /// Show current configuration
    Show,
    /// Update configuration values
    Set {
        /// Set the Segment write key
        #[arg(long)]
        write_key: Option<String>,
        /// Replace the enabled plugins list (comma-separated)
        #[arg(long, value_delimiter = ',')]
        plugins: Option<Vec<String>>,
        /// Add plugins to the enabled list (comma-separated)
        #[arg(long, value_delimiter = ',')]
        add_plugins: Vec<String>,
        /// Remove plugins from the enabled list (comma-separated)
        #[arg(long, value_delimiter = ',')]
        remove_plugins: Vec<String>,
    },
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    match cli.command {
        Some(Commands::Android { args }) => delegate::run("android.sh", &args),
        Some(Commands::Ios { args }) => delegate::run("ios.sh", &args),
        Some(Commands::Rn { args }) => delegate::run("rn.sh", &args),
        Some(Commands::Metro { args }) => delegate::run("metro.sh", &args),
        Some(Commands::Doctor { fix }) => doctor::run(fix),
        Some(Commands::Uninstall { all, keep }) => uninstall::run(all, &keep),
        Some(Commands::Init { sdk, name, org, write_key, plugins }) => {
            init_cmd::run(sdk, name, org, write_key, plugins)
        }
        Some(Commands::Update) => update::run(),
        Some(Commands::Config { action }) => match action {
            ConfigAction::Show => config_cmd::run_show(),
            ConfigAction::Set { write_key, plugins, add_plugins, remove_plugins } => {
                config_cmd::run_set(write_key, plugins, add_plugins, remove_plugins)
            }
        },
        None => {
            println!("segkit {}", env!("CARGO_PKG_VERSION"));
            ExitCode::SUCCESS
        }
    }
}
