use clap::Args;

use crate::sdks::SdkName;

#[derive(Args)]
pub struct InitArgs {
    /// SDK to use
    #[arg(long)]
    pub sdk: SdkName,

    /// Project name (required unless --issue is provided)
    #[arg(long)]
    pub name: Option<String>,

    /// Issue number (triggers bug reproduction mode)
    #[arg(long)]
    pub issue: Option<String>,

    /// Package namespace
    #[arg(long, default_value = "com.example")]
    pub org: String,

    /// Git ref: "latest", "main", tag, or commit SHA
    #[arg(long, default_value = "latest")]
    pub r#ref: String,

    /// Segment write key
    #[arg(long)]
    pub write_key: Option<String>,

    /// Output directory
    #[arg(long)]
    pub output: Option<String>,

    /// Skip git repository initialization
    #[arg(long, default_value_t = false)]
    pub no_git: bool,
}

pub fn run(args: InitArgs) -> Result<(), Box<dyn std::error::Error>> {
    let project_name = match (&args.name, &args.issue) {
        (Some(name), _) => name.clone(),
        (None, Some(issue)) => format!("repro-{issue}"),
        (None, None) => {
            return Err("Either --name or --issue is required".into());
        }
    };

    let output_dir = args
        .output
        .clone()
        .unwrap_or_else(|| format!("./{project_name}"));

    let sdk = crate::sdks::registry::get(&args.sdk);

    println!("Initializing {project_name} with {} SDK...", sdk.name);
    println!("  Repo: {}", sdk.github_repo);
    println!("  Ref: {}", args.r#ref);
    println!("  Output: {output_dir}");
    println!("  Devbox plugin: {}", sdk.devbox_plugin);

    // TODO: implement cloning, native tooling delegation, devbox setup
    eprintln!("segkit init is not yet implemented");
    std::process::exit(1);
}
