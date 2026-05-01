use clap::Parser;

#[derive(Parser)]
#[command(name = "segkit", version, about = "Segment SDK developer toolkit")]
struct Cli {}

fn main() {
    let _cli = Cli::parse();
    println!("segkit {}", env!("CARGO_PKG_VERSION"));
}
