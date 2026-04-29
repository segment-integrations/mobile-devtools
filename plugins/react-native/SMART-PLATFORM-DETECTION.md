# Smart Platform Detection

The React Native plugin automatically detects which platform you're using and skips initialization of the unused platform. This significantly speeds up shell initialization and eliminates confusing warnings.

## How It Works

### 1. Command-Based Detection (Highest Priority)

When you run a devbox command, the plugin examines the command to determine which platform is needed:

```bash
# iOS commands → automatically sets ANDROID_SKIP_SETUP=1
devbox run start:ios
devbox run build:ios  
devbox run ios.sh simulator start

# Android commands → automatically sets IOS_SKIP_SETUP=1
devbox run start:android
devbox run build:android
devbox run android.sh emulator start
```

**Detected patterns:**
- iOS: `ios.sh`, `pod`, `xcodebuild`, `xcrun`, `simulator`
- Android: `android.sh`, `gradlew`, `adb`, `emulator`, `/android/`

### 2. Project Structure Detection (Fallback)

If command detection doesn't apply (e.g., `devbox shell`), the plugin checks your project structure:

```bash
# iOS-only project (has ios/ but no android/)
your-project/
├── ios/          ← has this
├── src/
└── devbox.json
# → Sets ANDROID_SKIP_SETUP=1 automatically

# Android-only project (has android/ but no ios/)  
your-project/
├── android/      ← has this
├── src/
└── devbox.json
# → Sets IOS_SKIP_SETUP=1 automatically

# Full React Native project (has both)
your-project/
├── ios/          ← has both
├── android/      ← 
├── src/
└── devbox.json
# → Initializes both platforms
```

### 3. Manual Override (Always Respected)

Explicitly set skip flags always take precedence:

```bash
# Force iOS-only (even if project has both platforms)
export ANDROID_SKIP_SETUP=1
devbox shell

# Force Android-only
export IOS_SKIP_SETUP=1
devbox shell

# Force both platforms (override auto-detection)
export RN_REQUIRE_ALL_PLATFORMS=1
devbox shell
```

## Performance Benefits

**Before (without smart detection):**
```bash
$ time devbox run start:ios
🔍 Evaluating Android SDK from Nix flake...  # ← Unnecessary!
WARNING: Android SDK evaluation failed...     # ← Confusing!
iOS simulator booted
real    0m45.2s
```

**After (with smart detection):**
```bash
$ time devbox run start:ios
iOS simulator booted                          # ← Clean!
real    0m8.5s
```

**Speed improvement:** ~5-6x faster for single-platform commands

## Opt-Out

If you need both platforms initialized simultaneously (rare), set:

```bash
export RN_REQUIRE_ALL_PLATFORMS=1
```

Then both Android and iOS will be initialized regardless of command or project structure.

## Use Cases

### iOS Development on macOS

```bash
# Just works - no Android SDK errors
cd my-rn-app
devbox run start:ios
devbox run build:ios
```

### Android Development

```bash
# Just works - no iOS setup overhead
cd my-rn-app
devbox run start:android
devbox run build:android
```

### Cross-Platform Development

```bash
# Need both platforms in same shell
export RN_REQUIRE_ALL_PLATFORMS=1
devbox shell

# Or use separate shells (recommended)
# Terminal 1:
devbox run -e ANDROID_SKIP_SETUP=1 start:ios

# Terminal 2:
devbox run -e IOS_SKIP_SETUP=1 start:android
```

## Troubleshooting

**Q: I'm seeing "Android SDK evaluation failed" on macOS**
A: This warning should be gone with smart detection. If you still see it, check:
- Is your command pattern recognized? (see patterns above)
- Did you set `RN_REQUIRE_ALL_PLATFORMS=1`?
- Try explicit flag: `devbox run -e ANDROID_SKIP_SETUP=1 <command>`

**Q: iOS commands are slow on first run**
A: First run evaluates the iOS SDK from Nix. Subsequent runs use cached evaluation (~instant).

**Q: I need both platforms but don't want to set RN_REQUIRE_ALL_PLATFORMS**
A: Use two separate devbox shells - one for iOS, one for Android. This is the recommended workflow.

## Migration Guide

**If you were using manual skip flags:**

```bash
# Before
devbox run -e ANDROID_SKIP_SETUP=1 start:ios
devbox run -e IOS_SKIP_SETUP=1 start:android

# After (automatic!)
devbox run start:ios
devbox run start:android
```

**If you were adding export statements to scripts:**

```bash
# Before (in devbox.json)
"build:ios": [
  "export ANDROID_SKIP_SETUP=1",
  "..."
]

# After (remove export - automatic!)
"build:ios": [
  "..."
]
```

The manual flags still work (and take precedence), but are no longer necessary for common cases.
