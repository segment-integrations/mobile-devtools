use crate::cli::{Platform, ProjectConfig};
use crate::error::Result;
use inquire::{MultiSelect, Select, Text};

/// Prompt user interactively for project configuration
pub fn prompt_project_config() -> Result<ProjectConfig> {
    let name = Text::new("Project name:")
        .with_default("My Segment App")
        .prompt()
        .map_err(|_| crate::error::SegmentInitError::MissingField("name".to_string()))?;

    let output_path = Text::new("Output directory:")
        .with_default(&format!("./{}", to_kebab_case(&name)))
        .prompt()
        .map_err(|_| crate::error::SegmentInitError::MissingField("output_path".to_string()))?;

    let platform_options = vec![
        ("Android", Platform::Android),
        ("iOS", Platform::Ios),
        ("React Native", Platform::ReactNative),
    ];

    let selected_indices = MultiSelect::new("Select platforms:", platform_options.clone())
        .prompt()
        .map_err(|_| {
            crate::error::SegmentInitError::MissingField("platforms".to_string())
        })?;

    let platforms: Vec<Platform> = selected_indices.into_iter().map(|(_, p)| p).collect();

    let package_id = if platforms.contains(&Platform::Android) {
        Some(
            Text::new("Android package ID:")
                .with_default(&format!("com.example.{}", to_snake_case(&name)))
                .prompt()
                .map_err(|_| {
                    crate::error::SegmentInitError::MissingField("package_id".to_string())
                })?,
        )
    } else {
        None
    };

    let bundle_id = if platforms.contains(&Platform::Ios)
        || platforms.contains(&Platform::ReactNative)
    {
        Some(
            Text::new("iOS bundle ID:")
                .with_default(&format!("com.example.{}", to_snake_case(&name)))
                .prompt()
                .map_err(|_| {
                    crate::error::SegmentInitError::MissingField("bundle_id".to_string())
                })?,
        )
    } else {
        None
    };

    let plugin_ref = Select::new("Plugin reference:", vec!["main", "latest", "v0.1.0"])
        .with_starting_cursor(0)
        .prompt()
        .map_err(|_| crate::error::SegmentInitError::MissingField("plugin_ref".to_string()))?
        .to_string();

    let git_init = inquire::Confirm::new("Initialize git repository?")
        .with_default(true)
        .prompt()
        .unwrap_or(false);

    Ok(ProjectConfig {
        name,
        output_path,
        platforms,
        package_id,
        bundle_id,
        plugin_ref,
        git_init,
    })
}

fn to_kebab_case(s: &str) -> String {
    s.to_lowercase().replace(' ', "-")
}

fn to_snake_case(s: &str) -> String {
    s.to_lowercase().replace(' ', "").replace('-', "")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_to_kebab_case() {
        assert_eq!(to_kebab_case("My Segment App"), "my-segment-app");
        assert_eq!(to_kebab_case("Test"), "test");
    }

    #[test]
    fn test_to_snake_case() {
        assert_eq!(to_snake_case("My Segment App"), "mysegmentapp");
        assert_eq!(to_snake_case("Test"), "test");
    }
}
