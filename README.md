# Loop Daddy Radio

Omarchy bar plugin that plays a random [Marc Rebillet](https://www.youtube.com/@MarcRebillet) session, audio only.

Source lives in this repo (plugin root = `manifest.json`). On an Omarchy box it is usually cloned or symlinked to `~/.config/omarchy/plugins/joonas.loopdaddyradio`.

## Use

| Action | Binding |
|---|---|
| Toggle radio on/off | Left click the radio on the bar |
| Open now playing | Right click |
| Open the session on YouTube | Open in YouTube in the panel |
| Skip to another random session | Middle click, or Skip in the panel |

Turning it on (or skipping) lands at a random point in a random session, like tuning a radio mid-song. When a session ends, the next one starts from the beginning. Shorts and clips under 90 seconds are skipped so you mostly get live sessions.

```bash
omarchy-shell joonas.loopdaddyradio toggle
omarchy-shell joonas.loopdaddyradio enable
omarchy-shell joonas.loopdaddyradio disable
omarchy-shell joonas.loopdaddyradio skip
omarchy-shell joonas.loopdaddyradio open
omarchy-shell joonas.loopdaddyradio status
```

Needs `yt-dlp` and `mpv` on `PATH` (both ship with Omarchy).

## Install

From a checkout:

```bash
ln -sfn "$(pwd)" ~/.config/omarchy/plugins/joonas.loopdaddyradio
omarchy-shell shell rescanPlugins
omarchy plugin enable joonas.loopdaddyradio
```

Or add the git remote and run `omarchy plugin add <git-url> --enable`.

Move it with `omarchy bar move joonas.loopdaddyradio --section right`.
