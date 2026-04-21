use anyhow::Result;
use clap::{Parser, Subcommand};

mod cli;
mod config;
mod error;
mod template;
mod transform;
mod validation;

/// CLI tool for creating reproducible Segment mobile projects
#[derive(Parser, Debug)]
#[command(name = "segment-init")]
#[command(version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Create a new Segment project from templates
    Create {
        /// Output directory path
        path: Option<String>,

        /// Project name
        #[arg(short, long)]
        name: Option<String>,

        /// Platforms to include (comma-separated: android,ios,react-native)
        #[arg(short, long)]
        platform: Option<String>,

        /// Android package ID (e.g., com.example.app)
        #[arg(long)]
        package_id: Option<String>,

        /// iOS bundle ID
        #[arg(long)]
        bundle_id: Option<String>,

        /// Plugin reference (tag, branch, or commit)
        #[arg(long, default_value = "main")]
        plugin_ref: String,

        /// Disable interactive prompts
        #[arg(long)]
        no_interactive: bool,

        /// Show what would be generated without creating files
        #[arg(long)]
        dry_run: bool,

        /// Overwrite existing directory
        #[arg(long)]
        overwrite: bool,

        /// Initialize git repository
        #[arg(long)]
        git_init: bool,

        /// Verbose output
        #[arg(short, long)]
        verbose: bool,
    },

    /// List available SDKs
    ListSdks,

    /// List available destination plugins
    ListDestinations,

    /// List available templates
    ListTemplates,

    /// Validate an existing project
    Validate {
        /// Project path to validate
        path: Option<String>,
    },

    /// Update plugin references in existing project
    UpdatePlugins {
        /// Project path
        path: Option<String>,

        /// New plugin reference
        #[arg(long)]
        ref_name: String,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Create {
            path,
            name,
            platform,
            package_id,
            bundle_id,
            plugin_ref,
            no_interactive,
            dry_run,
            overwrite,
            git_init,
            verbose,
        } => {
            if verbose {
                println!("Creating new Segment project...");
                println!("  Path: {:?}", path);
                println!("  Name: {:?}", name);
                println!("  Platform: {:?}", platform);
                println!("  Plugin ref: {}", plugin_ref);
            }

            // TODO: Implement project creation
            println!("Project creation is not yet implemented");
            Ok(())
        }

        Commands::ListSdks => {
            println!("Available Segment SDKs:");
            println!("  - analytics-android");
            println!("  - analytics-ios");
            println!("  - analytics-react-native");
            Ok(())
        }

        Commands::ListDestinations => {
            println!("Available destination plugins:");
            println!("  - Amplitude");
            println!("  - Braze");
            println!("  - Firebase");
            println!("  - Mixpanel");
            Ok(())
        }

        Commands::ListTemplates => {
            println!("Available templates:");
            println!("  - android     - Android native application");
            println!("  - ios         - iOS native application");
            println!("  - react-native - React Native cross-platform application");
            Ok(())
        }

        Commands::Validate { path } => {
            println!("Validating project at: {:?}", path.unwrap_or_else(|| ".".to_string()));
            // TODO: Implement validation
            println!("Validation is not yet implemented");
            Ok(())
        }

        Commands::UpdatePlugins { path, ref_name } => {
            println!(
                "Updating plugins in {} to ref: {}",
                path.unwrap_or_else(|| ".".to_string()),
                ref_name
            );
            // TODO: Implement plugin update
            println!("Plugin update is not yet implemented");
            Ok(())
        }
    }
}
