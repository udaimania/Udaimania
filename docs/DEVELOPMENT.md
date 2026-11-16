# Udaimania development

The fork lives at `https://github.com/udaimania/Udaimania`. Work on
`codex/product-development`; `origin` is our fork and `upstream` is JerryZLiu/Dayflow.

## Build and run

1. Install Xcode in `/Applications/Xcode.app` and complete its first launch.
2. Open `Dayflow/Udaimania.xcodeproj`.
3. Select the **Udaimania** scheme and **My Mac**, then press **Command-R**.
4. Edit the source and press **Command-R** again to rebuild and relaunch.

No paid Apple Developer membership or upstream signing team is needed for this
local build. The Development configuration uses ad hoc signing.

From the repository root, `./scripts/build-dev.sh` builds the same configuration.
The app is written to `build/DerivedData/Udaimania/Build/Products/Development/Udaimania.app`. To run the unit tests:

```sh
./scripts/build-dev.sh test
```

On this Mac, Xcode's **File → Project Settings → Derived Data** is set to
**Project-relative Location**, `../build/DerivedData`, so Xcode and the script
update the same app. `~/Applications/Udaimania.app` points to that built app;
rebuild it after cleaning the build directory. On a new checkout, set the same
project-relative location to use this shortcut workflow.

The app must complete its own onboarding. Grant screen-recording access to
**Udaimania** when you choose to start recording, and configure its AI provider.
It can use the existing signed-in Codex CLI. It does not import the released
app's recordings, API keys, provider choices, or onboarding state.

## Separation from the released app

| Resource | Development | Official release |
| --- | --- | --- |
| App | Udaimania | Dayflow |
| Bundle / preferences domain | `com.udaimania.Dayflow.dev` | `teleportlabs.com.Dayflow` |
| Data under `~/Library/Application Support/` | `Dayflow Dev/` | `Dayflow/` |
| Keychain API-key prefix | `com.udaimania.Dayflow.dev.apikeys` | `com.teleportlabs.dayflow.apikeys` |
| Keychain session | `com.udaimania.Dayflow.dev.auth` | `com.teleportlabs.dayflow.auth` |
| URL scheme | `dayflow-dev://` | `dayflow://` |
| MCP connection / optional terminal command | `dayflow-dev` | `dayflow` |

The application and bundled helper compile the same `AppIdentity.swift`, with
`DAYFLOW_DEVELOPMENT` enabled only for Development builds. The helper has a
separate SwiftPM build directory. Chat prompts, databases, recordings, summaries,
agent sockets, and telemetry queues use the selected app's data directory.

Development builds keep Sparkle updates off and do not auto-update external AI
CLIs. They have no upstream backend or PostHog configuration. Use your own
ChatGPT, Claude, Gemini, or local-model provider; upstream hosted Pro services
are not part of this local setup.

Use **Udaimania** for iteration. The original **Dayflow** scheme retains the
upstream app identity and is not the separate development app.

The Udaimania rename retains the development bundle identifier, data directory,
keychain services, URL scheme, and MCP connection name so existing settings and
recordings continue to work. Internal Swift module and source-folder names remain
Dayflow to keep upstream merges straightforward.

The checkout stays at `~/Documents/ChatGPT/Dayflow`;
`~/Documents/ChatGPT/Udaimania` is a separate existing web project.
