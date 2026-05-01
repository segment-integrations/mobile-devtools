#![allow(dead_code)]

mod commands;
mod sdks;
mod utils;

use clap::Parser;
use commands::Cli;

fn main() {
    let cli = Cli::parse();
    if let Err(e) = commands::run(cli) {
        eprintln!("Error: {e}");
        std::process::exit(1);
    }
}
