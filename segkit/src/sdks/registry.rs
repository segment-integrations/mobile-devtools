use super::{BuildTool, SdkMetadata, SdkName};

static SWIFT: SdkMetadata = SdkMetadata {
    name: "swift",
    github_repo: "segmentio/analytics-swift",
    example_paths: &[
        "Examples/apps/DestinationsExample",
        "Examples/apps/BasicExample",
        "Examples/",
        "Example/",
    ],
    build_tool: BuildTool::Swift,
    default_org: "com.example",
    devbox_plugin: "github:segment-integrations/devbox-plugins?dir=plugins/ios",
    jira_project: "MOBILEBUGS",
    jira_labels: &["ios", "sdk"],
};

static KOTLIN: SdkMetadata = SdkMetadata {
    name: "kotlin",
    github_repo: "segmentio/analytics-kotlin",
    example_paths: &[
        "samples/kotlin-android-app",
        "samples/",
        "example/",
        "Examples/",
    ],
    build_tool: BuildTool::Gradle,
    default_org: "com.example",
    devbox_plugin: "github:segment-integrations/devbox-plugins?dir=plugins/android",
    jira_project: "MOBILEBUGS",
    jira_labels: &["android", "sdk"],
};

static REACT_NATIVE: SdkMetadata = SdkMetadata {
    name: "react-native",
    github_repo: "segmentio/analytics-react-native",
    example_paths: &["packages/example", "example/", "Examples/"],
    build_tool: BuildTool::Npm,
    default_org: "com.example",
    devbox_plugin: "github:segment-integrations/devbox-plugins?dir=plugins/react-native",
    jira_project: "MOBILEBUGS",
    jira_labels: &["react-native", "sdk"],
};

pub fn get(sdk: &SdkName) -> &'static SdkMetadata {
    match sdk {
        SdkName::Swift => &SWIFT,
        SdkName::Kotlin => &KOTLIN,
        SdkName::ReactNative => &REACT_NATIVE,
    }
}

pub fn all() -> [&'static SdkMetadata; 3] {
    [&SWIFT, &KOTLIN, &REACT_NATIVE]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_sdks_have_at_least_one_example_path() {
        for sdk in all() {
            assert!(
                !sdk.example_paths.is_empty(),
                "{} has no example paths",
                sdk.name
            );
        }
    }

    #[test]
    fn all_sdks_have_github_repo() {
        for sdk in all() {
            assert!(
                sdk.github_repo.contains('/'),
                "{} github_repo missing org/repo format",
                sdk.name
            );
        }
    }

    #[test]
    fn all_sdks_have_devbox_plugin() {
        for sdk in all() {
            assert!(
                sdk.devbox_plugin.starts_with("github:"),
                "{} devbox_plugin should be a github reference",
                sdk.name
            );
        }
    }

    #[test]
    fn sdk_name_parsing() {
        assert!(matches!("swift".parse::<SdkName>(), Ok(SdkName::Swift)));
        assert!(matches!("kotlin".parse::<SdkName>(), Ok(SdkName::Kotlin)));
        assert!(matches!(
            "react-native".parse::<SdkName>(),
            Ok(SdkName::ReactNative)
        ));
        assert!(matches!("rn".parse::<SdkName>(), Ok(SdkName::ReactNative)));
        assert!("invalid".parse::<SdkName>().is_err());
    }

    #[test]
    fn get_returns_correct_sdk() {
        assert_eq!(get(&SdkName::Swift).name, "swift");
        assert_eq!(get(&SdkName::Kotlin).name, "kotlin");
        assert_eq!(get(&SdkName::ReactNative).name, "react-native");
    }
}
