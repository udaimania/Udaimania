# Udaimania naming and compatibility

Use **Udaimania** for the product, Swift module, Xcode targets, and app display name.
Use **udaimania** for the bundled command, plugin, and filesystem package names.
The local project is **Udaimania Apps**, rooted at `UdaimaniaApps`.

The code and assets now live under `macos/Udaimania`, the CLI under
`tools/udaimania-cli`, and the agent plugin under `plugins/udaimania`.
The fork is `udaimania/Udaimania`. Product links must point to real fork resources,
not fabricated domains or renamed upstream email addresses.

Some Dayflow references intentionally remain:

- Development bundle IDs, keychain services, the `Dayflow Dev` data directory,
  `dayflow-dev` URL scheme and MCP server name preserve the already-installed app.
  Their definitions are centralized in `AppIdentity.swift`.
- Persisted preference keys, encoded provider cases such as `dayflow`, and
  historical analytics identifiers remain compatible with existing data. A future
  migration must read old values before writing replacements.
- Registration repair recognizes an old development helper, while tests retain
  official Dayflow paths as negative controls against claiming another app.
- The upstream remote, MIT copyright, original source attribution, and archived
  update feed describe actual provenance and must stay truthful.
- Original bitmap artwork may still contain upstream branding. Renaming an asset
  file does not redraw its pixels. The active launch and onboarding screens now render Udaimania as text;
  replacement artwork belongs to the Figma redesign.

The source-map paths were updated to this layout. Existing Figma node IDs, image
bytes, and digests remain unchanged. The maps describe the exported baseline,
not a live synchronization of the user's subsequent design edits.
