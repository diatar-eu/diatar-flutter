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

## Required GitHub Secrets

You must configure the following repository secrets in **Settings → Secrets and variables → Actions** for the deployment to succeed:

| Secret Name | Description |
| --- | --- |
| `PLAY_STORE_JSON_KEY` | The full JSON content of a Google Play Service Account key (from Google Cloud Console) with access to the Play Console. Used to authenticate the Android upload. |
| `APPLE_ID` | Your Apple ID email address (e.g., `you@example.com`). |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID (10-character alphanumeric, e.g., `ABCDE12345`). |
| `APPLE_APP_SPECIFIC_PASSWORD` | An app-specific password generated at [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords. Used by Fastlane to download certificates and sign the iOS build. |

### How to obtain these secrets

#### 1. `PLAY_STORE_JSON_KEY`
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a service account with the **Play Console API** access, or link an existing one from the Play Console → **Setup → API access**.
3. Generate a JSON key for the service account.
4. Copy the entire JSON file content and paste it as the `PLAY_STORE_JSON_KEY` secret.

#### 2. `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_SPECIFIC_PASSWORD`
1. `APPLE_ID`: Your Apple ID email.
2. `APPLE_TEAM_ID`: Found in the [Apple Developer Membership](https://developer.apple.com/account) page under "Team ID".
3. `APPLE_APP_SPECIFIC_PASSWORD`: Generate it at [appleid.apple.com](https://appleid.apple.com) → Security → App-Specific Passwords.

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

Make sure the required environment variables (`PLAY_STORE_JSON_KEY_FILE`, `APPLE_ID`, `APPLE_TEAM_ID`, `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD`) are set in your local shell.