{
  description = "Android SDK tools for Devbox (plugin local flake)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Read generated android.json (created from env vars by android-init.sh)
      # On first initialization, android.json may not exist yet, so provide defaults
      configFileExists = builtins.pathExists ./android.json;
      versionData = if configFileExists
        then builtins.fromJSON (builtins.readFile ./android.json)
        else {
          # Default values for initial flake evaluation before android-init.sh runs
          ANDROID_BUILD_TOOLS_VERSION = "36.1.0";
          ANDROID_CMDLINE_TOOLS_VERSION = "19.0";
          ANDROID_SYSTEM_IMAGE_TAG = "google_apis";
          ANDROID_INCLUDE_NDK = false;
          ANDROID_NDK_VERSION = "27.0.12077973";
          ANDROID_INCLUDE_CMAKE = false;
          ANDROID_CMAKE_VERSION = "3.22.1";
        };
      defaultsData = if builtins.hasAttr "defaults" versionData then versionData.defaults else versionData;
      getVar =
        name:
        if builtins.hasAttr name defaultsData then toString (builtins.getAttr name defaultsData)
        else builtins.throw "Missing required value in android.json: ${name}";

      unique =
        list:
        builtins.foldl' (
          acc: item: if builtins.elem item acc then acc else acc ++ [ item ]
        ) [ ] list;

      lockData =
        if builtins.pathExists ./devices.lock
        then builtins.fromJSON (builtins.readFile ./devices.lock)
        else { devices = [ ]; };

      # Extract API versions from lock file devices array, default to latest if empty
      deviceApis =
        if builtins.hasAttr "devices" lockData && (builtins.length lockData.devices) > 0
        then map (device: device.api) lockData.devices
        else [ 36 ]; # Default to latest stable API

      # Include ANDROID_COMPILE_SDK in platform versions if set (for projects
      # that compile against a different API than the emulator/device targets)
      compileSdkApis =
        if builtins.hasAttr "ANDROID_COMPILE_SDK" defaultsData
        then [ (toString defaultsData.ANDROID_COMPILE_SDK) ]
        else [];

      androidSdkConfig = {
        platformVersions = unique ((map toString deviceApis) ++ compileSdkApis);
        buildToolsVersion = getVar "ANDROID_BUILD_TOOLS_VERSION";
        cmdLineToolsVersion = getVar "ANDROID_CMDLINE_TOOLS_VERSION";
        systemImageTypes = [ (getVar "ANDROID_SYSTEM_IMAGE_TAG") ];
        includeNDK =
          if builtins.hasAttr "ANDROID_INCLUDE_NDK" defaultsData then defaultsData.ANDROID_INCLUDE_NDK else false;
        ndkVersion = getVar "ANDROID_NDK_VERSION";
        includeCMake =
          if builtins.hasAttr "ANDROID_INCLUDE_CMAKE" defaultsData then defaultsData.ANDROID_INCLUDE_CMAKE else false;
        cmakeVersion = getVar "ANDROID_CMAKE_VERSION";
      };

      # Hash overrides for when Google updates files on their servers
      # These can be set in android.json to work around nixpkgs hash mismatches
      hashOverrides = if builtins.hasAttr "hash_overrides" versionData
        then versionData.hash_overrides
        else {};

      forAllSystems =
        f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f system;
          }) systems
        );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              android_sdk.accept_license = true;
            };
          };

          abiVersions = if builtins.match "aarch64-.*" system != null then [ "arm64-v8a" ] else [ "x86_64" ];

          # Apply hash overrides to nixpkgs if any are specified
          pkgsWithOverrides = if (builtins.length (builtins.attrNames hashOverrides)) > 0
            then pkgs.appendOverlays [(final: prev: {
              fetchurl = args: prev.fetchurl (args // (
                if builtins.hasAttr (args.url or "") hashOverrides
                then { sha256 = hashOverrides.${args.url}; }
                else {}
              ));
            })]
            else pkgs;

          androidPkgs =
            config:
            pkgsWithOverrides.androidenv.composeAndroidPackages {
              platformVersions = config.platformVersions;
              buildToolsVersions = [ config.buildToolsVersion ];
              cmdLineToolsVersion = config.cmdLineToolsVersion;
              includeEmulator = true;
              includeSystemImages = true;
              includeNDK = config.includeNDK;
              ndkVersions = if config.includeNDK && config.ndkVersion != "" then [ config.ndkVersion ] else [ ];
              includeCmake = config.includeCMake;
              cmakeVersions = if config.includeCMake && config.cmakeVersion != "" then [ config.cmakeVersion ] else [ ];
              abiVersions = abiVersions;
              systemImageTypes = config.systemImageTypes;
            };
        in
        {
          android-sdk = (androidPkgs androidSdkConfig).androidsdk;
          default = (androidPkgs androidSdkConfig).androidsdk;
        }
      );

      androidSdkConfig = androidSdkConfig;
    };
}
