# Android Plugin Configuration

This directory contains configuration files for the Android Devbox plugin.

## Files

### `devices/*.json`
Device definitions for Android emulators. These define the AVD configurations that will be created.

**Location:** `devbox.d/plugin-name/devices/`  
**Committed:** ✅ Yes  
**Purpose:** Define emulator configurations for the team

Example:
```json
{
  "name": "max",
  "api": 36,
  "abi": "arm64-v8a",
  "tag": "google_apis"
}
```

### `hash-overrides.json` (Optional)
Temporary workarounds for Android SDK hash mismatches caused by Google updating files on their servers.

**Location:** `devbox.d/plugin-name/hash-overrides.json`  
**Committed:** ✅ Yes (for reproducibility)  
**Purpose:** Fix hash mismatches until nixpkgs is updated  
**Auto-generated:** By `devbox run android:hash-fix`

Example:
```json
{
  "dl.google.com-android-repository-platform-tools_r37.0.0-darwin.zip": "8c4c926d0ca192376b2a04b0318484724319e67c"
}
```

**When to commit:**
- ✅ **Always commit** when auto-generated - ensures everyone on the team gets the fix
- 🗑️ **Remove when obsolete** - once nixpkgs is updated, the override is no longer needed
- ✓ **Safe to keep** - having stale overrides is harmless (they're just not used if nixpkgs already has the correct hash)

**Why commit it:**
- **Reproducibility**: Everyone on the team uses the same fixed hash
- **CI/CD**: Automated builds get the fix automatically
- **Onboarding**: New team members don't hit the same error

This prevents the scenario where one developer fixes a hash mismatch but others keep hitting the same error.

## Hash Mismatch Issue

This is a **recurring problem** with Android SDK where Google updates files at stable URLs without changing version numbers, breaking Nix's content-addressable builds.

**Symptoms:**
```
error: hash mismatch in fixed-output derivation
         specified: sha1-XXXXXXX
            got:    sha1-YYYYYYY
```

**Automatic fix:**
The plugin automatically detects and fixes this during `devbox shell`. Just run `devbox shell` twice:
1. First run: Detects error + auto-fixes + saves to hash-overrides.json
2. Second run: Uses fixed hash + builds successfully

**Then commit the file:**
```bash
git add devbox.d/*/hash-overrides.json
git commit -m "fix(android): add SDK hash override"
```

See: [HASH_MISMATCH_ISSUE.md](../../../notes/HASH_MISMATCH_ISSUE.md) for full details.
