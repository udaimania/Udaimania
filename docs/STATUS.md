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

The work is committed in logical groups: Mac development isolation, Figma
handoff, the paused phone prototype, Udaimania naming/layout cleanup, and
repository instructions/status. GitHub CLI is authenticated as `udaimania`, with
its credential in the Mac keychain; Git uses that connection for `origin`.
Commits use the account's GitHub noreply address. Check `git status -sb` for
the current branch synchronization state. The branch was pushed to GitHub and
its remote commit was verified against the local checkout.

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
the final Udaimania GitHub support screen after a full restart. Older background
Mac app instances were closed; phone development remained paused. The final
launch/onboarding screens use
native Udaimania text instead of upstream branded video.

Begin the next Mac design change from a specific Figma frame. Read
[DEVELOPMENT.md](DEVELOPMENT.md) for commands and stable identities. Keep the phone
paused.

## Capture-permission follow-up

The chat is now in Udaimania Apps (verified in the project tools). After the rename,
the app opened its existing timeline but both Screen Recording and Accessibility
showed Grant. Capture was stopped by the screen-recording preflight check. The old
and new binaries were ad hoc signed; keeping the bundle ID alone did not retain
privacy authorization. The user authorized restoring both permissions and Mac
capture. Stable Apple Development signing now uses this Mac's existing certificate,
with personal settings kept in ignored `LocalSigning.xcconfig` and a portable
example committed to the repository. App/helper signature verification passed;
the signed desktop suite passed **241 tests, zero failures**.

The stale macOS entries were replaced with the current signed build. After a full
restart, both permissions showed **Granted** and capture resumed. Read-only database
checks confirmed fresh saved frames advancing from ID 1935 at 22:37:32 to ID 1949
at 22:39:52 on 15 November (local time); sampled new files existed and were nonempty.
The pre-fix last capture was at 21:34:31. Historical recordings were retained.

Provider settings also showed an unconfigured Gemini primary. The prior ChatGPT /
Codex provider was restored and its in-app connection test passed. The reason the
provider changed was not established; verify the active provider after future test
runs as well as checking permissions and saved frames. Connection success does not
by itself verify a newly generated timeline card. Phone work remains paused.

## Original Dayflow removed

At the user's request, the original `/Applications/Dayflow.app` was quit and moved
to Trash after disabling its launch-at-login setting. The obsolete
`~/Applications/Dayflow Dev.app` shortcut was also moved to Trash; it pointed to
Udaimania and was not a separate app. Original Dayflow recordings and preferences
were retained. Udaimania's app, development identity, and data were left intact.

Verification found no original Dayflow process, while Udaimania remained running
and saved a new frame at 22:45:52 on 15 November (local time). The repository's
`LICENSE` matches `upstream/main:LICENSE` byte for byte, including the full MIT
notice and `Copyright (c) 2025 Jerry Liu`; README source attribution is retained.
No application code or signed bundle changed, so no rebuild was needed. Continue
development using `~/Applications/Udaimania.app`; phone work remains paused.
