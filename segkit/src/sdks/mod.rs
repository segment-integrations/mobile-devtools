pub mod registry;

use std::fmt;
use std::str::FromStr;

#[derive(Debug, Clone)]
pub enum SdkName {
    Swift,
    Kotlin,
    ReactNative,
}

impl FromStr for SdkName {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "swift" => Ok(Self::Swift),
            "kotlin" => Ok(Self::Kotlin),
            "react-native" | "rn" => Ok(Self::ReactNative),
            _ => Err(format!(
                "unknown SDK '{s}'. Valid options: swift, kotlin, react-native"
            )),
        }
    }
}

impl fmt::Display for SdkName {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Swift => write!(f, "swift"),
            Self::Kotlin => write!(f, "kotlin"),
            Self::ReactNative => write!(f, "react-native"),
        }
    }
}

pub enum BuildTool {
    Swift,
    Gradle,
    Npm,
}

pub struct SdkMetadata {
    pub name: &'static str,
    pub github_repo: &'static str,
    pub example_paths: &'static [&'static str],
    pub build_tool: BuildTool,
    pub default_org: &'static str,
    pub devbox_plugin: &'static str,
    pub jira_project: &'static str,
    pub jira_labels: &'static [&'static str],
}
