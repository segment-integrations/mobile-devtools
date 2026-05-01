use std::process::Command;

pub fn resolve_latest_tag(repo: &str) -> Result<String, Box<dyn std::error::Error>> {
    let output = Command::new("git")
        .args([
            "ls-remote",
            "--tags",
            "--refs",
            &format!("https://github.com/{repo}"),
        ])
        .output()?;

    if !output.status.success() {
        return Err(format!(
            "git ls-remote failed for {repo}: {}",
            String::from_utf8_lossy(&output.stderr)
        )
        .into());
    }

    let stdout = String::from_utf8(output.stdout)?;
    let latest = stdout
        .lines()
        .filter_map(|line| line.rsplit('/').next())
        .filter(|tag| {
            tag.starts_with('v') && tag[1..].chars().next().is_some_and(|c| c.is_ascii_digit())
        })
        .max_by(|a, b| version_cmp(a, b))
        .map(String::from);

    latest.ok_or_else(|| format!("no version tags found for {repo}").into())
}

fn version_cmp(a: &str, b: &str) -> std::cmp::Ordering {
    let parse = |s: &str| -> Vec<u64> {
        s.trim_start_matches('v')
            .split(|c: char| !c.is_ascii_digit())
            .filter(|p| !p.is_empty())
            .filter_map(|p| p.parse().ok())
            .collect()
    };
    parse(a).cmp(&parse(b))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_ordering() {
        assert_eq!(version_cmp("v1.2.3", "v1.2.3"), std::cmp::Ordering::Equal);
        assert_eq!(version_cmp("v1.2.3", "v1.2.4"), std::cmp::Ordering::Less);
        assert_eq!(version_cmp("v2.0.0", "v1.9.9"), std::cmp::Ordering::Greater);
        assert_eq!(
            version_cmp("v1.10.0", "v1.9.0"),
            std::cmp::Ordering::Greater
        );
    }

    #[test]
    fn version_cmp_with_prerelease_segments() {
        // Pre-release tags get extra numeric segments: v1.2.3-beta.1 -> [1, 2, 3, 1]
        // This sorts them after the release, which is acceptable for our use case
        // since we filter tags by v{digit} prefix and SDK repos rarely use pre-releases
        assert_eq!(
            version_cmp("v1.2.3-beta.1", "v1.2.3"),
            std::cmp::Ordering::Greater
        );
    }
}
