# Deployment to Play Store, App Store and Linux bundles

This project uses **Fastlane** and **GitHub Actions** to automatically deploy the `Diatar` and `DiaVetito` apps to the Google Play Store and Apple App Store when a version tag (e.g., `v1.0.0`) is pushed.

## Flatpak (Linux)

`Deploy` calls the reusable `.github/workflows/flatpak.yml` after its Linux
x64 and arm64 builds succeed. It packages those exact artifacts, not a later
checkout of the default branch. Each app gets an `x86_64` and an `aarch64`
bundle on the stable Flatpak branch; no Flutter SDK or network-dependent
`pub get` runs inside the packaging sandbox.

The manifests and desktop/AppStream metadata live in `flatpak/`.
`tools/prepare-flatpak.py` reads the version and icon from the built Flutter
assets and injects the packaging date. GNOME 49 provides GTK, GStreamer and
libsecret. Packaging
checks the desktop/AppStream files and resolves the executable and plugin
libraries against the **Platform** runtime, not just the SDK.
The unused Android JNI native asset (`libdartjni.so`) is omitted when present;
neither app uses Java on Linux, so no JVM is required.

Actions artifacts are named `<App>-flatpak-<arch>`. On `release` and `web`
deploys, Pages publishes the four bundles:

- `https://web.diatar.eu/downloads/Diatar/Diatar-x86_64.flatpak`
- `https://web.diatar.eu/downloads/Diatar/Diatar-aarch64.flatpak`
- `https://web.diatar.eu/downloads/DiaVetito/DiaVetito-x86_64.flatpak`
- `https://web.diatar.eu/downloads/DiaVetito/DiaVetito-aarch64.flatpak`

Published GitHub Release runs also attach the bundles as release assets.
Ordinary CI builds only upload Actions artifacts. Flatpak packaging and Pages
do not depend on successful store uploads.

Install Flatpak using the distribution's package manager, then install a
downloaded bundle (use `aarch64` instead on 64-bit ARM):

```bash
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user ./Diatar-x86_64.flatpak
flatpak install --user ./DiaVetito-x86_64.flatpak
flatpak run eu.diatar.diatar
flatpak run eu.diatar.vetito
```

The first install downloads the shared GNOME runtime from Flathub, so it
needs internet access. These are **unsigned, downloadable bundles**, not a
Flathub submission or a self-hosted update repository. Updates require
downloading the newer bundle and running
`flatpak install --user --reinstall ./Diatar-x86_64.flatpak` (or the matching
receiver/ARM filename); app data is retained. `flatpak update` alone
does not download new app versions. Download only from the trusted HTTPS
site or this repository's release assets.

Home-directory access supports user-selected songs, orders and media.
Network, display and audio access support projection and playback; device
access also permits WebRTC's direct V4L2 camera capture. This is not a
minimal-permission sandbox. Test file import/export, TCP/MQTT, multiple
windows, audio and cameras on real Linux/Pi hardware before release.
Official Flathub publication would need a separate submission and a
reviewable, reproducible source-build manifest.

To package an existing build locally on Linux with Python 3.12+, Flatpak,
flatpak-builder and GNOME Platform/SDK 49 installed:

```bash
python3 tools/prepare-flatpak.py Diatar Diatar-linux.tar.gz build/flatpak-input
flatpak-builder --user --sandbox --disable-rofiles-fuse --state-dir=build/flatpak-state \
  --default-branch=stable --repo=build/flatpak-repo build/flatpak-app build/flatpak-input/eu.diatar.diatar.yaml
flatpak build --runtime build/flatpak-app sh < tools/check-flatpak-libraries.sh
flatpak build-bundle --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
  build/flatpak-repo Diatar-x86_64.flatpak eu.diatar.diatar stable
```

## How it works

When you push a tag starting with `v` (e.g., `git tag v1.2.3 && git push origin v1.2.3`), the workflow in `.github/workflows/deploy.yml` runs:

- **Android**: Builds the app bundle and uploads it to the Play Store **production** track via Fastlane (`upload_to_play_store`).
- **iOS**: Builds the IPA, signs it, and uploads it to App Store Connect, submitting it for review and automatic release via Fastlane (`upload_to_app_store`).

No new screenshots are uploaded; only the application binary and the localized "What's New" release notes (from `release-notes/<App>/<locale>/release_notes.txt`) are pushed to production.

### Flatpak and Web are part of Deploy

`deploy.yml` builds the web apps and calls the reusable Flatpak workflow in
the same run. Both use that run's build outputs; neither waits for the entire
store deployment to finish. Pages publication is enabled for the `web` and
`release` channels.

### Web: downloadable artifacts

Besides the web apps, the Web deploy also builds the Windows, Linux and Android artifacts and uploads them to the Pages site under `downloads/<App>/`. They are **not** linked from the landing page, but are directly downloadable at:

- `https://web.diatar.eu/downloads/Diatar/Diatar.apk`
- `https://web.diatar.eu/downloads/Diatar/Diatar-linux.tar.gz`
- `https://web.diatar.eu/downloads/Diatar/Diatar-linux-arm64.tar.gz` (64-bit Raspberry Pi OS; built on Ubuntu 22.04 ARM runner for broader libstdc++ compatibility)
- `https://web.diatar.eu/downloads/Diatar/Diatar-windows.zip`
- `https://web.diatar.eu/downloads/DiaVetito/DiaVetito.apk`
- `https://web.diatar.eu/downloads/DiaVetito/DiaVetito-linux.tar.gz`
- `https://web.diatar.eu/downloads/DiaVetito/DiaVetito-linux-arm64.tar.gz` (64-bit Raspberry Pi OS; built on Ubuntu 22.04 ARM runner for broader libstdc++ compatibility)
- `https://web.diatar.eu/downloads/DiaVetito/DiaVetito-windows.zip`

These artifacts are built in `deploy.yml` from the same checked-out (already bumped) revision as the web apps, so they always match the deployed web version.

### Windows: combined offline installer

After both Windows matrix builds succeed, `build-windows-installer` downloads
their ZIP artifacts and runs `tools/build-windows-installer.ps1` with Inno Setup 6.
The ZIP downloads remain unchanged. The additional `Diatar-windows-installer`
artifact contains `Diatar-Setup-<version>-windows-x64.exe`, also published to
`https://web.diatar.eu/downloads/Windows/Diatar-Setup-<version>-windows-x64.exe`
on Pages deploys and attached to published GitHub Releases.

Pages also copies the installer beside `Diatar-windows.zip` under a stable name:
`https://web.diatar.eu/downloads/Diatar/Diatar-Setup.exe`.
Link to this URL from `www.diatar.eu` to always download the latest deployed
installer without changing the link for each version. The `www.diatar.eu`
website is separate from this repository's Pages site (`web.diatar.eu`).
Pages publication runs only for the `web` and `release` deploy channels;
ordinary branch pushes build downloadable Actions artifacts but do not update Pages.

The installer supports Windows 10 version 1809 or later (x64), requires
administrator approval, and offers sender-only, receiver-only, or both apps.
Each app keeps its complete release bundle in a separate subdirectory to avoid
DLL collisions. The latest Microsoft VC++ x64 redistributable is downloaded
at packaging time, its Microsoft Authenticode signature is verified, and it is
embedded in the EXE for offline installation. Setup installs it before copying
the apps when the installed runtime is missing or older; runtime failures abort
setup, and restart requests are preserved. No .NET, Dart, or Flutter installation
is needed on the target machine.

Installer-specific text comes from the sender's `app_hu.arb` / `app_en.arb`;
the packaging script generates temporary Inno language files from these keys.
Built-in wizard text uses Inno's Hungarian and English language packs.

To package existing, extracted release bundles locally (PowerShell 7):

```powershell
.\tools\build-windows-installer.ps1 `
  -SenderBundle 'build\windows-installer\bundles\Diatar' `
  -ReceiverBundle 'build\windows-installer\bundles\DiaVetito'
```

Inno Setup 6 must already be installed locally; CI installs it if missing.
The default output directory is `build\windows-installer` (gitignored).
Versions are read from the bundled executables, not from a possibly newer
checkout's pubspecs. CI smoke-tests component selection, adding a component on
upgrade, installed file hashes, and uninstall on its disposable Windows runner.
Before release, also test on a clean Windows 10 machine without developer tools:
the CI runner already has runtime libraries. Windows N editions may need the
Windows Media Feature Pack for camera/audio features. The installer is not
code-signed; SmartScreen may show a warning until release signing is configured.

### Automatic build number bump

The `deploy.yml` workflow automatically increments the build number (the `+N` suffix in the app's `pubspec.yaml`, i.e. `version: X.Y.Z+N`) **before** any store upload, and commits the change back to the repository with a `ci: bump build number to N [skip ci]` message. This guarantees that every store upload uses a strictly increasing `versionCode` (Android) / `CFBundleVersion` (iOS), so re-running a deploy (e.g. after a transient failure) never collides with an already-published build.

- A dedicated `bump` job runs once per app at the very start of the workflow. It bumps the app's `pubspec.yaml`, commits and pushes the change to the branch that triggered the run (`main` for tag pushes, the dispatched branch otherwise). The Android and iOS deploy jobs wait for this job (`needs: bump`) and check out the bumped branch, so both platforms build with the same, already-incremented number.
- Because `Diatar` and `DiaVetito` have separate `pubspec.yaml` files, their bumps never conflict with each other. The `bump` job also has a retry loop: if a push is rejected (e.g. due to a concurrent push), it re-syncs, re-reads the number, increments again and retries.
- The `[skip ci]` tag in the commit message prevents the push from re-triggering the artifact build workflow.
- You no longer need to manually edit the build number in `pubspec.yaml` before releasing — the CI handles it.

## Required GitHub Secrets

You must configure the following repository secrets in **Settings → Secrets and variables → Actions** for the deployment to succeed:

| Secret Name | Description |
| --- | --- |
| `PLAY_STORE_JSON_KEY` | The full JSON content of a Google Play Service Account key (from Google Cloud Console) with access to the Play Console. Used to authenticate the Android upload. |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded content of the Android release keystore file (`.jks`). Used to sign the Android App Bundle. |
| `ANDROID_KEYSTORE_PASSWORD` | Password for the Android release keystore. |
| `ANDROID_KEY_ALIAS` | Key alias name in the Android release keystore (e.g., `my-key-alias`). |
| `ANDROID_KEY_PASSWORD` | Password for the key alias in the Android release keystore. |
| `APPLE_ID` | Your Apple ID email address (e.g., `you@example.com`). |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID (10-character alphanumeric, e.g., `ABCDE12345`). |
| `APPLE_API_KEY_ID` | The App Store Connect API Key ID (e.g., `ABCDE12345`). Found in App Store Connect → Users and Access → Keys. Used by Fastlane to authenticate without an Apple ID password (avoids 2FA failures in CI). |
| `APPLE_API_ISSUER_ID` | The App Store Connect API Key Issuer ID (UUID). Shown on the same Keys page as above. |
| `APPLE_API_KEY_BASE64` | Base64-encoded content of the downloaded `.p8` API key file (`AuthKey_<KEY_ID>.p8`). Generate it with `base64 -i AuthKey_<KEY_ID>.p8`. |

### How to obtain these secrets

#### 1. `PLAY_STORE_JSON_KEY`
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a service account with the **Play Console API** access, or link an existing one from the Play Console → **Setup → API access**.
3. Generate a JSON key for the service account.
4. Copy the entire JSON file content and paste it as the `PLAY_STORE_JSON_KEY` secret.

#### 2. Android signing keystore
1. `ANDROID_KEYSTORE_BASE64`: Encode your release keystore file with `base64 -i keystore.jks` and paste the output as the secret.
2. `ANDROID_KEYSTORE_PASSWORD`: The password you set when creating the keystore.
3. `ANDROID_KEY_ALIAS`: The key alias (e.g., `my-key-alias`) used when generating the key.
4. `ANDROID_KEY_PASSWORD`: The password for the key alias (often same as keystore password).

   To create a new keystore:
   ```bash
   keytool -genkey -v -keystore ~/release-keystore.jks -alias my-key-alias -keyalg RSA -keysize 2048 -validity 10000
   ```

   To get the SHA1 fingerprint of an existing keystore (for Play Console key registration):
   ```bash
   keytool -list -v -keystore keystore.jks -alias my-key-alias -keystore password
   ```

#### 3. `APPLE_ID`, `APPLE_TEAM_ID`, App Store Connect API key
1. `APPLE_ID`: Your Apple ID email.
2. `APPLE_TEAM_ID`: Found in the [Apple Developer Membership](https://developer.apple.com/account) page under "Team ID".
3. `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`, `APPLE_API_KEY_BASE64`: Create an API key in **App Store Connect → Users and Access → Keys** (requires Admin role). Click "Generate API Key", give it a name and the "App Manager" access, then note the **Key ID** and **Issuer ID**. Download the `.p8` file (`AuthKey_<KEY_ID>.p8`) — it can only be downloaded once. Encode it with `base64 -i AuthKey_<KEY_ID>.p8` and store the output as `APPLE_API_KEY_BASE64`.

   Using an API key is the recommended way to authenticate Fastlane in CI because it does not depend on the Apple ID password or two-factor authentication, which is what caused the previous `get_certificates` login failure.

## Local testing (optional)

You can run the Fastlane lanes locally from each platform directory:

```bash
# Android (from Diatar/android or DiaVetito/android)
bundle install
bundle exec fastlane deploy

# iOS (from Diatar/ios or DiaVetito/ios)
bundle install
bundle exec fastlane deploy
```

Make sure the required environment variables (`PLAY_STORE_JSON_KEY_FILE`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`, `APPLE_API_KEY_FILEPATH`) are set in your local shell. `APPLE_API_KEY_FILEPATH` should point to the downloaded `AuthKey_<KEY_ID>.p8` file.
