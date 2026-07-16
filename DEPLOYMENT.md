# Deployment to Play Store, App Store and Flathub

This project uses **Fastlane** and **GitHub Actions** to automatically deploy the `Diatar` and `DiaVetito` apps to the Google Play Store and Apple App Store when a version tag (e.g., `v1.0.0`) is pushed.

## Flatpak (Linux)

When you push a tag starting with `v` (e.g., `git tag v9.1.0 && git push origin v9.1.0`), the workflow in `.github/workflows/flatpak.yml` builds a Flatpak bundle for both `Diatar` and `DiaVetito` and publishes them to a `flathub` branch in this repository.

- The Flatpak manifests live in `flatpak/` (`eu.diatar.diatar.yaml`, `eu.diatar.diavetito.yaml`) together with the `.desktop` and `.metainfo.xml` files.
- The published `flathub` branch acts as a self-hosted Flatpak repository. Users can install the apps with:

  ```bash
  flatpak remote-add --if-not-exists diatar-flutter \
    https://github.com/vlacko0930/diatar-flutter.git
  flatpak install diatar-flutter eu.diatar.diatar
  flatpak install diatar-flutter eu.diatar.diavetito
  ```

- The version and release date are injected into the metainfo from the git tag automatically during the build.
- To submit the apps to the official Flathub repository, move the manifests and metadata into a separate `flathub` fork and open a PR there (the manifests are already Flathub-compatible).

## How it works

When you push a tag starting with `v` (e.g., `git tag v1.2.3 && git push origin v1.2.3`), the workflow in `.github/workflows/deploy.yml` runs:

- **Android**: Builds the app bundle and uploads it to the Play Store **production** track via Fastlane (`upload_to_play_store`).
- **iOS**: Builds the IPA, signs it, and uploads it to App Store Connect, submitting it for review and automatic release via Fastlane (`upload_to_app_store`).

No new screenshots or metadata are uploaded; only the application binary is pushed to production.

### Automatic build number bump

Each `deploy` lane automatically increments the build number (the `+N` suffix in the app's `pubspec.yaml`, i.e. `version: X.Y.Z+N`) **before** building, and commits the change back to the repository with a `ci: bump build number to N [skip ci]` message. This guarantees that every store upload uses a strictly increasing `versionCode` (Android) / `CFBundleVersion` (iOS), so re-running a deploy (e.g. after a transient failure) never collides with an already-published build.

- The bump is committed and pushed to the branch that triggered the run (`main` for tag pushes, the dispatched branch otherwise). The `[skip ci]` tag prevents the push from re-triggering the artifact build workflow.
- Because the Android and iOS jobs of the same app run in parallel and share the same `pubspec.yaml`, the lane uses a retry loop: if the push is rejected because the other platform already bumped and pushed, it re-syncs, re-reads the new number, increments again and retries. This way both platforms always end up with distinct, increasing build numbers.
- You no longer need to manually edit the build number in `pubspec.yaml` before releasing — Fastlane handles it on CI.

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
