# Loop Daddy Radio

Omarchy bar plugin that plays a random [Marc Rebillet](https://www.youtube.com/@MarcRebillet) session, audio only.

## Install

```sh
omarchy plugin add https://github.com/joonsp/loopdaddyradio.git --enable
```

Move it with `omarchy bar move joonas.loopdaddyradio --section right`.

From a local checkout:

```sh
ln -sfn "$(pwd)" ~/.config/omarchy/plugins/joonas.loopdaddyradio
omarchy-shell shell rescanPlugins
omarchy plugin enable joonas.loopdaddyradio
```

## Use

| Action | Binding |
|---|---|
| Toggle radio on/off | Left click the radio on the bar |
| Open now playing | Right click |
| Open the session on YouTube | Open in YouTube in the panel |
| Skip to another random session | Middle click, or Skip in the panel |
| Play/pause | Keyboard media play/pause keys |

Turning it on (or skipping) lands at a random point in a random session, like tuning a radio mid-song. When a session ends, the next one starts from the beginning. Shorts and clips under 90 seconds are skipped so you mostly get live sessions.

While the radio is on, Omarchy media keys play and pause it through MPRIS, the same way they control other players. Toggle on the bar still starts or stops the station.

```sh
omarchy-shell joonas.loopdaddyradio toggle
omarchy-shell joonas.loopdaddyradio enable
omarchy-shell joonas.loopdaddyradio disable
omarchy-shell joonas.loopdaddyradio skip
omarchy-shell joonas.loopdaddyradio open
omarchy-shell joonas.loopdaddyradio status
```

## Remove

```sh
omarchy plugin remove joonas.loopdaddyradio
```

## Dependencies

`yt-dlp`, `mpv`, and `mpv-mpris` on `PATH` (all ship with Omarchy). Play/pause keys need `mpv-mpris`.

## License

MIT
