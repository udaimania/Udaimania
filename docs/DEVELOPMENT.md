# Udaimania development

The local **Udaimania Apps** project points to
`/Users/diem/Documents/ChatGPT/UdaimaniaApps`. This is the application repository.
The neighboring `/Users/diem/Documents/ChatGPT/Udaimania` folder is a separate
web/research project and must not be used for app changes.

The fork is `https://github.com/udaimania/Udaimania`; the working branch is
`codex/product-development`. `origin` is the fork; `upstream` is
`https://github.com/JerryZLiu/Dayflow.git`.

## Build, run, and test the Mac app

1. Install Xcode in `/Applications/Xcode.app` and complete its first launch.
2. Open `macos/Udaimania.xcodeproj`.
3. Select the **Udaimania** scheme and **My Mac**, then press **Command-R**.
4. Edit the source and press **Command-R** again to rebuild and relaunch.

The scheme uses the Development configuration with ad hoc signing. No upstream
signing team or paid Apple Developer membership is needed for this local Mac build.

From the repository root:

```sh
./scripts/build-dev.sh
./scripts/build-dev.sh test
```

The schemes run tests serially because inherited provider tests save and restore
shared preferences; running those classes concurrently causes interference.

The script produces
`build/DerivedData/Udaimania/Build/Products/Development/Udaimania.app`.
On this Mac, `~/Applications/Udaimania.app` is a shortcut to that app. Rebuild with
the script to update the shortcut's target. Xcode may use its own Derived Data
location; Command-R launches the app it just built. Do not assume that an Xcode
build updates the shortcut unless its Derived Data setting matches this path.

## Identity and compatibility

| Resource | Development build | Future release configuration |
| --- | --- | --- |
| Display name / module | `Udaimania` | `Udaimania` |
| Bundle / preferences domain | `com.udaimania.Dayflow.dev` | `com.udaimania.app` |
| Application Support directory | `Dayflow Dev/` | `Udaimania/` |
| Keychain API-key prefix | `com.udaimania.Dayflow.dev.apikeys` | `com.udaimania.app.apikeys` |
| Keychain session | `com.udaimania.Dayflow.dev.auth` | `com.udaimania.app.auth` |
| URL scheme | `dayflow-dev://` | `udaimania://` |
| MCP server name | `dayflow-dev` | `udaimania` |
| Optional terminal command | `udaimania` | `udaimania` |

The shared `tools/udaimania-cli/Sources/udaimania/AppIdentity.swift` defines these
values for the app and helper. `UDAIMANIA_DEVELOPMENT` selects the development
identity. Databases, recordings, prompts, sockets, and telemetry queues use the
selected app's data directory. Development identifiers containing Dayflow are
intentional compatibility values: changing them would lose access to existing
settings, credentials, permissions, and recordings. They do not select the
original Dayflow app's separate data directory.

Existing development helper registrations can recognize the prior `dayflow`
binary name inside a known development app. New helpers are named `udaimania`.
The official Dayflow app's registration must never be claimed by this build.
See [NAMING.md](NAMING.md) before changing persisted identifiers.

Development has no upstream backend or analytics configuration, and it does not
auto-update external AI CLIs. Configure the chosen ChatGPT, Claude, Gemini, or
local-model provider in the app. Existing onboarding and permissions are retained
through the stable development identity; a fresh install needs its own onboarding.

## Release boundaries

**Udaimania Release** uses the Release configuration and the fork's distinct
identity. It is not a ready-to-distribute release. All configurations have updates
disabled by default; the upstream Sparkle feed and public key have been removed.
Do not enable `UDAIMANIA_ENABLE_UPDATES` without configuring and validating our own
feed, signing key, signing identity, notarization, and release workflow.

The inherited appcast is preserved only as `docs/upstream/dayflow-appcast.xml`.
It is not used by the app. Hosted Flow and support chat need separately configured
Udaimania services; the local app uses a Flow unavailable state and GitHub support.

## Design and phone work

Read [DESIGN.md](DESIGN.md) for the shared Figma file and source maps. Implement
specific requested frames in the Mac code, rebuild, and inspect the result.
Do not overwrite the user's in-progress Figma redesign during repository cleanup.

The `mobile/` prototype is **paused**. Preserve it and its validation record, but
do not build, install, launch, test, or extend it until the user explicitly resumes
phone work. Its real-work-account exclusion remains in force.
