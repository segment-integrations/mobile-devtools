use thiserror::Error;

#[derive(Debug, Error)]
pub enum SegmentInitError {
    #[error("Template not found: {0}")]
    TemplateNotFound(String),

    #[error("Invalid platform: {0}")]
    InvalidPlatform(String),

    #[error("Failed to parse devbox.json: {0}")]
    DevboxJsonParse(#[from] serde_json::Error),

    #[error("Failed to rewrite plugin URL: {0}")]
    PluginRewrite(String),

    #[error("Project validation failed: {0}")]
    ValidationFailed(String),

    #[error("Project directory already exists: {0}")]
    DirectoryExists(String),

    #[error("Missing required field: {0}")]
    MissingField(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

pub type Result<T> = std::result::Result<T, SegmentInitError>;
