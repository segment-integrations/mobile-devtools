/// Line-preserving xcconfig parser.
/// Stores raw lines and provides get/set that edit in-place,
/// preserving comments and ordering.
pub struct XCConfig {
    lines: Vec<String>,
}

impl XCConfig {
    pub fn parse(content: &str) -> Self {
        Self {
            lines: content.lines().map(|l| l.to_string()).collect(),
        }
    }

    pub fn get(&self, key: &str) -> Option<String> {
        for line in &self.lines {
            let trimmed = line.trim();
            if trimmed.starts_with("//") || trimmed.is_empty() {
                continue;
            }
            if let Some((k, v)) = trimmed.split_once('=') {
                if k.trim() == key {
                    return Some(v.trim().to_string());
                }
            }
        }
        None
    }

    pub fn set(&mut self, key: &str, value: &str) {
        for line in &mut self.lines {
            let trimmed = line.trim();
            if trimmed.starts_with("//") || trimmed.is_empty() {
                continue;
            }
            if let Some((k, _)) = trimmed.split_once('=') {
                if k.trim() == key {
                    *line = format!("{} = {}", key, value);
                    return;
                }
            }
        }
        // Key not found — append it
        self.lines.push(format!("{} = {}", key, value));
    }

    pub fn to_string(&self) -> String {
        let mut out = self.lines.join("\n");
        if !out.ends_with('\n') {
            out.push('\n');
        }
        out
    }
}
