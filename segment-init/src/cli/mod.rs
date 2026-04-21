pub mod flags;
pub mod interactive;

use crate::error::Result;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectConfig {
    pub name: String,
    pub output_path: String,
    pub platforms: Vec<Platform>,
    pub package_id: Option<String>,
    pub bundle_id: Option<String>,
    pub plugin_ref: String,
    pub git_init: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum Platform {
    Android,
    Ios,
    ReactNative,
}

impl Platform {
    pub fn from_str(s: &str) -> Result<Self> {
        match s.to_lowercase().as_str() {
            "android" => Ok(Platform::Android),
            "ios" => Ok(Platform::Ios),
            "react-native" | "react_native" | "rn" => Ok(Platform::ReactNative),
            _ => Err(crate::error::SegmentInitError::InvalidPlatform(s.to_string())),
        }
    }

    pub fn as_str(&self) -> &str {
        match self {
            Platform::Android => "android",
            Platform::Ios => "ios",
            Platform::ReactNative => "react-native",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_platform_from_str() {
        assert_eq!(Platform::from_str("android").unwrap(), Platform::Android);
        assert_eq!(Platform::from_str("Android").unwrap(), Platform::Android);
        assert_eq!(Platform::from_str("ios").unwrap(), Platform::Ios);
        assert_eq!(Platform::from_str("IOS").unwrap(), Platform::Ios);
        assert_eq!(Platform::from_str("react-native").unwrap(), Platform::ReactNative);
        assert_eq!(Platform::from_str("react_native").unwrap(), Platform::ReactNative);
        assert_eq!(Platform::from_str("rn").unwrap(), Platform::ReactNative);
        assert!(Platform::from_str("invalid").is_err());
    }

    #[test]
    fn test_platform_as_str() {
        assert_eq!(Platform::Android.as_str(), "android");
        assert_eq!(Platform::Ios.as_str(), "ios");
        assert_eq!(Platform::ReactNative.as_str(), "react-native");
    }
}
