# Project status

Updated 15 November 2026. This file is the starting point for a new development chat.

## Active work

Udaimania is a macOS work-journal product developed from the Dayflow fork. The user
is overhauling the visual design in the shared Figma file. Desktop development is
active; phone development is paused.

- Local project: **Udaimania Apps**; its folder was verified in the app's project list.
- Repository: `/Users/diem/Documents/ChatGPT/UdaimaniaApps`.
- Fork: `https://github.com/udaimania/Udaimania`.
- Working branch: `codex/product-development`.
- Upstream: `https://github.com/JerryZLiu/Dayflow`.
- Local app shortcut: `/Users/diem/Applications/Udaimania.app`.
- Xcode project: `macos/Udaimania.xcodeproj`; scheme **Udaimania**.

The neighboring `Udaimania` folder is the separate web/research project.

## Repository organization and naming

The desktop app lives in `macos/`, the command in `tools/udaimania-cli/`, and the
agent plugin in `plugins/udaimania/`. Product text, types, targets, paths, and command
names use Udaimania. Compatibility IDs preserve existing development data and
credentials; see [NAMING.md](NAMING.md). Upstream license attribution is retained.
The original updater feed and signing team are not used by this fork.

The work is organized into five commits: Mac development isolation, Figma
handoff, the paused phone prototype, Udaimania naming/layout cleanup, and
repository instructions/status. GitHub CLI is authenticated as `udaimania`, with
its credential in the Mac keychain; Git uses that connection for `origin`.
Commits use the account's GitHub noreply address. Check `git status -sb` for
the current branch synchronization state.

## Design handoff

[DESIGN.md](DESIGN.md) links the shared Figma file and records its baseline:
Design System → Assets → States & Layouts, including 230 source assets, 40 states,
37 component masters, and 11 component sets. Source maps retain the original node
IDs and asset hashes. The user may have edited Figma since that baseline.

Next product step: choose a specific edited Figma frame, implement it in the Mac
app, rebuild, and inspect locally. Figma edits do not directly update the app.

## Phone companion: paused

The existing prototype and findings are preserved under `mobile/`. Do not resume
builds, device testing, or integrations until requested. Real work accounts are
excluded from testing. The first synthetic physical-device trial demonstrated
capture but substantially undercounted static reading; it does not establish actual
Slack, Gmail, or iCloud coverage. Personal Team signing blocked the optional Family
Controls variant. Read [mobile/VALIDATION.md](../mobile/VALIDATION.md) before resuming.

## Verification and next session

The final desktop build passed, with **241 tests passing and zero failures**.
The inherited provider-preference tests conflicted when run concurrently; the
shared schemes now run tests serially. All 230 source asset hashes match the
Figma baseline; shell syntax, JSON/localization files, and Git whitespace checks
passed. The bundled `udaimania --help` command works, and the built app has no
upstream update feed. The running app retained the existing timeline and displayed
the new Udaimania GitHub support screen. The final launch/onboarding screens use
native Udaimania text instead of upstream branded video.

Begin the next Mac design change from a specific Figma frame. Read
[DEVELOPMENT.md](DEVELOPMENT.md) for commands and stable identities. Keep the phone
paused.
