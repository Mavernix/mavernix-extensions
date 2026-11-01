# Now Playing

What's playing, in the menu bar, as macOS shows it. A play symbol stands in the panel while a media player is around (any program that speaks MPRIS: Firefox, Bandstand, mpv, Spotify…). Pressing it opens a small player: the album art, the title and "artist – album", the time so far and the length either side of a bar you can drag, and back, play or pause, and forward, with the player's own loudness beside them.

Which player it shows: the one picked by hand, else the one playing, else the one that played last. With more than one player, a line above the track names the one shown ("Firefox ▾"); it opens a menu of all of them, each with what it plays. A pick holds until that player quits or another is picked.

The volume slider sets the player's own volume (MPRIS `Volume`), between a quiet and a loud speaker; dragging it and the wheel over it both work. A player that has no volume, or can't be controlled, shows no slider: the system's loudness is the panel's volume item's.

On a desktop that can hold an item's own panel (a StatusItem's `popover`), the player opens in the menu bar's menu box and behaves like a menu: with a menu open, hovering onto the play symbol switches to the player, and back. Older desktops get it in a window of its own.

Some players leave out parts of MPRIS. Firefox has no CanPlay or CanPause, which Quickshell needs before it plays or pauses; for a player like that, the play button sends PlayPause over D-Bus itself (`gdbus`). Back and forward follow CanGoPrevious and CanGoNext, and stay greyed when a player doesn't offer them.

## Settings

`ignored` (in `extension.toml`, or `[extensions.now-playing]` in the desktop config): players whose bus name holds one of these are left out. `playerctld` is, as it only repeats another player.

## How it looks

Sizes and timings are in `looks/default.toml`. Everything else comes from the theme:

| Theme key | Used for |
|---|---|
| `[menu]`: `background`, `corner_radius`, `shadow`, `rim` | the box (the shell's `BoxFrame`, as menus have) |
| `[menu]`: `text_color` | the title, the drawn buttons |
| `[menu]`: `disabled_text_color` | "artist – album", the times, the player's name, the speakers, the drawn bars' filled parts |
| `[menu]`: `separator_color` | the drawn bars' grooves, the box behind missing art |
| `[menu]`: `text_inset` | where the menu of players starts, so its names line up |
| `[fonts]`: `menu` | all text |
| `[animation.menu_close]` | how it goes away |
| `[panel.status.icons]`: `media-playback-start` | the symbol in the panel, else the icon theme's, else `images/play.svg` |
| `[music.display]`: `fill` | the LCD behind the track (only with this key is the LCD used) |
| `[music.display]`: `title_color`, `artist_color`, `time_color` | the text on the LCD |
| `[music.display]`: `line_fill`, `line_played_fill`, `line_height`, `knob` | the scrubber on the LCD; without `line_fill` the bar is drawn |
| `[music.top_bar.pictures]`: `previous`, `play`, `pause`, `next` (each `normal`, `pressed`, `disabled`) | the buttons; only if all four are there, else they're drawn from `images/` |
| `[music.top_bar]`: `transport_spacing` | the gap between those buttons |
| `[music.top_bar]`: `volume_slider` (`track`, `track_slice`, `fill`, `fill_slice`, `thumb`, `thumb_pressed`) | the volume slider; without `track` and `thumb` it's drawn, its knob in the menu's `background` |

The `[music]` tables are the ones Sea Lion's Theme Installer cuts from iTunes 11 for Bandstand, so under Sea Lion the player gets iTunes' LCD, scrubber and buttons. The plain theme has none, and the player is drawn flat in the menu's colours.

A theme can give the extension its own looks in `looks/THEME.toml`, with the keys of `default.toml` and these colours: `text_color`, `secondary_text_color`, `seek_track_color`, `seek_fill_color`, `placeholder_color`.
