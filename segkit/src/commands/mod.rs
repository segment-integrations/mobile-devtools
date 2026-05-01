mod init;
mod repro;

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "segkit", about = "Segment SDK developer toolkit")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand)]
pub enum Command {
    /// Generate a new SDK project from an example app
    Init(init::InitArgs),
    /// Bug reproduction workflows (package, share)
    #[command(subcommand)]
    Repro(repro::ReproCommand),
}

pub fn run(cli: Cli) -> Result<(), Box<dyn std::error::Error>> {
    match cli.command {
        Command::Init(args) => init::run(args),
        Command::Repro(cmd) => repro::run(cmd),
    }
}
