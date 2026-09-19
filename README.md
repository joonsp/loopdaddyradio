# Loop Daddy Radio

Omarchy bar plugin that plays a random [Marc Rebillet](https://www.youtube.com/@MarcRebillet) session, audio only.

See [CHANGELOG.md](CHANGELOG.md) for what’s new.

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
| Pause / resume | Pause in the panel, or keyboard media keys |
| Skip to another random session | Middle click, or Skip in the panel |
| Previous session | Back in the panel |
| Play this session from the start | From the start in the panel |
| Open the session on YouTube | Open in YouTube in the panel |
| Join a live Loop Daddy | Join live in the panel, when one is on |

The bar icon uses theme colors: accent while on air, muted while paused or tuning in, urgent only for errors.

Turning it on (or skipping) lands at a random point in a random session, like tuning a radio mid-song. When a session ends, the next one starts from the beginning. Shorts and clips under 90 seconds are skipped so you mostly get live sessions.

If the radio was on before login, it waits for a click instead of blasting audio. A shell restart on the same boot resumes playback.

```sh
omarchy-shell joonas.loopdaddyradio toggle
omarchy-shell joonas.loopdaddyradio enable
omarchy-shell joonas.loopdaddyradio disable
omarchy-shell joonas.loopdaddyradio skip
omarchy-shell joonas.loopdaddyradio back
omarchy-shell joonas.loopdaddyradio playPause
omarchy-shell joonas.loopdaddyradio replay
omarchy-shell joonas.loopdaddyradio live
omarchy-shell joonas.loopdaddyradio open
omarchy-shell joonas.loopdaddyradio status
```

## Remove

```sh
omarchy plugin remove joonas.loopdaddyradio
```

## Dependencies

`yt-dlp`, `mpv`, `mpv-mpris`, and `nc` (OpenBSD netcat) under `/usr/bin` (all ship with Omarchy). Play/pause keys need `mpv-mpris`. Panel pause uses the mpv IPC socket.

## License

MIT
