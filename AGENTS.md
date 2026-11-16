# Udaimania Apps

This is the Udaimania native-app repository, forked from JerryZLiu/Dayflow. The
local project root is `/Users/diem/Documents/ChatGPT/UdaimaniaApps`. The neighboring
`/Users/diem/Documents/ChatGPT/Udaimania` is a separate web/research repository.
Do not make app changes there.

## Start here

Read `docs/STATUS.md` at the start of work. Read `docs/DEVELOPMENT.md` for builds,
`docs/NAMING.md` before identity changes, and `docs/DESIGN.md` for visual work.
Verify current Git status and preserve existing uncommitted work.

## Structure and naming

- `macos/Udaimania.xcodeproj`, `macos/Udaimania`, and `macos/UdaimaniaTests` contain
  the active desktop app, resources, and tests.
- `tools/udaimania-cli` contains the shared identity and bundled command/MCP helper.
- `plugins/udaimania` contains agent integration guidance.
- `mobile` contains the paused phone feasibility prototype and validation record.
- `docs/design` maps the Figma baseline to source files and preserved node IDs.

Use Udaimania for product text and Swift types/modules; use udaimania for commands
and package paths. Retain upstream MIT attribution. Do not blindly rename
persisted identifiers: legacy development bundle, storage, keychain, URL, MCP,
and preference values preserve existing local data. Privacy grants also depend
on stable code signing; verify actual permissions and fresh capture after rebuilds.

## Desktop workflow

Open `macos/Udaimania.xcodeproj`, select Udaimania / My Mac, and run. For a repeatable
build or test from the repository root:

```sh
./scripts/build-dev.sh
./scripts/build-dev.sh test
```

The script's app is under
`build/DerivedData/Udaimania/Build/Products/Development/Udaimania.app`.
The `~/Applications/Udaimania.app` shortcut on this Mac points there.
This Mac uses an Apple Development certificate via ignored
`macos/Config/LocalSigning.xcconfig`. Keep personal team details out of Git.
After signing changes, verify both permissions and fresh saved frames; an intact
timeline only proves access to historical data. After tests, verify the selected
AI provider and its connection as well.
Use focused verification appropriate to each change. Identity, storage, helper,
and cross-cutting renames warrant the desktop suite. Keep upstream analytics,
hosted services, release signing, and automatic updates disabled in local builds.

## Paused phone work

The phone app is paused at the user's request. Do not build, install, launch, test,
or extend it, and do not pursue service integrations, until the user explicitly
resumes that work. Preserve the existing prototype and `mobile/VALIDATION.md`.
The user's real work accounts are excluded from testing. Synthetic fixture results
must not be presented as real Slack/mail behavior or proven 24-hour coverage.

## Design collaboration

The user is redesigning the shared Figma file. It is organized as Design System,
Assets, then States & Layouts. Use the file and source maps in `docs/DESIGN.md`.
Implement requested frames in code and verify locally. Do not overwrite ongoing
Figma edits during housekeeping. Design changes are not automatically synchronized.

## Repository hygiene and handoff

`origin` is `https://github.com/udaimania/Udaimania.git`; `upstream` is the original
Dayflow repository. Use `codex/` branch names. Reuse the current suitable checkout;
keep simultaneous changes from overlapping. Commit coherent groups when requested.
Do not publish releases, send messages, or post team updates without authorization.

Never commit credentials, local signing configuration, raw recordings, private
trial captures, or personal logs. Build artifacts and machine-specific settings
stay ignored. Update `docs/STATUS.md` after meaningful outcomes with actual test
results, remaining blockers, and a concrete next step. State uncertainty directly;
do not claim a build, push, installation, or integration succeeded without evidence.
