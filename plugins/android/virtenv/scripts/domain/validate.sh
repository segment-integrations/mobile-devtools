#!/usr/bin/env bash
# Android Plugin - Validation Functions
# See SCRIPTS.md for detailed documentation
# Philosophy: Warn, don't block

set -e

# Validate that ANDROID_SDK_ROOT points to an existing directory (non-blocking)
android_validate_sdk() {
  if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ ! -d "$ANDROID_SDK_ROOT" ]; then
    echo "WARNING: ANDROID_SDK_ROOT points to non-existent directory: $ANDROID_SDK_ROOT" >&2
  fi

  return 0
}

# Validate that project's build.gradle uses env vars instead of hardcoded versions (non-blocking)
android_validate_build_config() {
  # Skip if no android directory exists yet
  if [ ! -d "android" ] || [ ! -f "android/build.gradle" ]; then
    return 0
  fi

  local build_gradle="android/build.gradle"
  local has_issues=0

  # Look for hardcoded compileSdkVersion that doesn't read from env
  if grep -q "compileSdkVersion\s*=\s*[0-9]" "$build_gradle" 2>/dev/null; then
    # Check if it's reading from System.getenv - if so, it's OK
    if ! grep -q "System.getenv.*ANDROID_COMPILE_SDK\|System.getenv.*ANDROID_MAX_API" "$build_gradle" 2>/dev/null; then
      local hardcoded_compile=$(grep -o "compileSdkVersion\s*=\s*[0-9]*" "$build_gradle" 2>/dev/null | grep -o "[0-9]*$" | head -1)
      local plugin_compile="${ANDROID_COMPILE_SDK:-35}"

      if [ -n "$hardcoded_compile" ] && [ "$hardcoded_compile" != "$plugin_compile" ]; then
        has_issues=1
        echo "" >&2
        echo "⚠️  WARNING: SDK version mismatch detected" >&2
        echo "" >&2
        echo "Your android/build.gradle has hardcoded compileSdkVersion=$hardcoded_compile" >&2
        echo "But this plugin provides Android API $plugin_compile" >&2
        echo "" >&2
        echo "This will cause build failures because Gradle will try to download API $hardcoded_compile," >&2
        echo "but only API $plugin_compile is available in the Nix store." >&2
        echo "" >&2
        echo "📋 To fix, update your android/build.gradle to read from environment variables:" >&2
        echo "" >&2
        echo "    buildscript {" >&2
        echo "        ext {" >&2
        echo "            def compileSdkEnv = System.getenv(\"ANDROID_COMPILE_SDK\") ?: System.getenv(\"ANDROID_MAX_API\") ?: \"35\"" >&2
        echo "            def targetSdkEnv = System.getenv(\"ANDROID_TARGET_SDK\") ?: System.getenv(\"ANDROID_MAX_API\") ?: \"35\"" >&2
        echo "            buildToolsVersion = System.getenv(\"ANDROID_BUILD_TOOLS_VERSION\") ?: \"35.0.0\"" >&2
        echo "            compileSdkVersion = compileSdkEnv.toInteger()" >&2
        echo "            targetSdkVersion = targetSdkEnv.toInteger()" >&2
        echo "        }" >&2
        echo "    }" >&2
        echo "" >&2
        echo "Or, to use API $hardcoded_compile, set it in your devbox.json:" >&2
        echo "" >&2
        echo "    \"env\": {" >&2
        echo "        \"ANDROID_MAX_API\": \"$hardcoded_compile\"" >&2
        echo "    }" >&2
        echo "" >&2
        echo "Then regenerate the device lock file: devbox run android.sh devices eval" >&2
        echo "" >&2
      fi
    fi
  fi

  # Check for hardcoded buildToolsVersion that doesn't read from env
  if grep -q "buildToolsVersion\s*=\s*\"[0-9]" "$build_gradle" 2>/dev/null; then
    if ! grep -q "System.getenv.*ANDROID_BUILD_TOOLS_VERSION" "$build_gradle" 2>/dev/null; then
      local hardcoded_tools=$(grep -o "buildToolsVersion\s*=\s*\"[0-9][^\"]*\"" "$build_gradle" 2>/dev/null | grep -o "[0-9][^\"]*" | head -1)
      local plugin_tools="${ANDROID_BUILD_TOOLS_VERSION:-35.0.0}"

      if [ -n "$hardcoded_tools" ] && [ "$hardcoded_tools" != "$plugin_tools" ]; then
        if [ "$has_issues" = "0" ]; then
          has_issues=1
          echo "" >&2
          echo "⚠️  WARNING: Build tools version mismatch detected" >&2
          echo "" >&2
        fi
        echo "Your build.gradle has hardcoded buildToolsVersion=\"$hardcoded_tools\"" >&2
        echo "But this plugin provides build-tools $plugin_tools" >&2
        echo "" >&2
        echo "Update build.gradle to: buildToolsVersion = System.getenv(\"ANDROID_BUILD_TOOLS_VERSION\") ?: \"35.0.0\"" >&2
        echo "" >&2
      fi
    fi
  fi

  return 0
}
