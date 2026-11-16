# Udaimania

Udaimania is a macOS work journal under active development, built from the
[Dayflow open-source project](https://github.com/JerryZLiu/Dayflow). This repository
contains the desktop app, its command-line helper, design handoff, and a paused
phone companion experiment. It is not a published Udaimania release.

Start with [project status](docs/STATUS.md), [development setup](docs/DEVELOPMENT.md),
and [the visual redesign](docs/DESIGN.md). Repository instructions live in
[AGENTS.md](AGENTS.md).

## Local development

Use Xcode on macOS. Clone the fork into a folder named `UdaimaniaApps`:

```sh
git clone https://github.com/udaimania/Udaimania.git UdaimaniaApps
cd UdaimaniaApps
git switch codex/product-development
./scripts/build-dev.sh
```

Open `macos/Udaimania.xcodeproj`, select **Udaimania** and **My Mac**, and run.
Rebuild after editing to see changes locally. The Development configuration uses
ad hoc signing and preserves the existing local development app's settings.
Run the desktop test suite with `./scripts/build-dev.sh test`.

## Repository layout

| Folder | Purpose |
| --- | --- |
| `macos/` | Udaimania app, Xcode project, resources, and desktop tests |
| `tools/udaimania-cli/` | Bundled `udaimania` command and MCP helper |
| `plugins/udaimania/` | Agent integration and timeline-query guidance |
| `mobile/` | Paused iPhone capture feasibility prototype and recorded findings |
| `docs/` | Status, setup, naming compatibility, and Figma source maps |
| `scripts/` | Local build and release tooling |

The desktop and Figma redesign are active. Phone development is paused until
explicitly resumed. Figma changes require implementation and a local rebuild;
they do not automatically modify the app.

## Privacy and development

Recordings and the activity database are stored locally. Analysis may send data
to the AI provider selected in the app; local storage does not mean every provider
processes data locally. Configure recording permissions and the provider in
Udaimania's onboarding and settings.

The local Development build disables inherited analytics, hosted backend
configuration, and automatic updates. Upstream support and update services are
not Udaimania services. The support screen links to this repository and copies
diagnostic logs only when requested. The phone prototype uses synthetic test
scenes; the user's real work accounts are excluded from testing.

## Attribution and license

Derived from Jerry Liu's Dayflow, licensed under the [MIT License](LICENSE).
The upstream copyright and license remain intact. Original artwork and historical
source references remain attributable to upstream; the visual redesign is in
progress. See [naming and compatibility](docs/NAMING.md) for retained identifiers.
