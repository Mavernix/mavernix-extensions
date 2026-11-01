# mavernix-extensions

official extensions for [mavernix](https://github.com/Mavernix/mavernix).

- `airpods` - airpods in the menu bar. battery, noise control, conversation awareness (wip)
- `now-playing` - what's playing, in the menu bar: a small player with the art, the track, a seek bar, its buttons and its volume, and a choice of player when there are several. itunes' lcd and buttons under sea lion
- `inputsource` - display and switch current keyboard layouts (wip)

get them from the app store, or drop a folder into `~/.config/mavernix/extensions/`, and turn them on in settings.

the store reads the latest release of this repository. pushing a tag like `v0.2.0` makes one (`packaging/make-release`): `extensions.toml`, and a `NAME.tar.gz` and icon for each extension. an extension's title, description, version and icon come from its `extension.toml`, so raise its `version` for the store to offer an update.
