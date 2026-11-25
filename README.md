# Deyra Shell

An experimental modular Wayland desktop shell written in QML and JavaScript with Quickshell. The first visual direction is the dark, rounded island design of [TQQ Niri Rice](https://github.com/zadrotov7000/TQQ-Niri-rice).

**0.2.0 alpha — interface redesign, native bar modules and motion system. Not yet runtime-tested.** Targets Niri and Hyprland. No Waybar, Dunst or Fuzzel dependency.

## Install and test

Requirements: a running Wayland compositor with layer-shell and foreign-toplevel-management support, Quickshell 0.2.1 or newer built with Wayland, PipeWire and notifications modules, Qt Quick Controls/Layouts/Dialogs, curl and optionally brightnessctl. On Debian, check your installed Quickshell version and QML modules. Uses the system sans-serif font; no dedicated icon font required.

```sh
git clone https://github.com/zadrotov7000/Deyra-shell.git
cd Deyra-shell
sh install.sh
qs -c deyra
```

Run in a terminal for the first smoke test; Ctrl+C stops the shell. The installer copies only the shell configuration to the user's XDG configuration directory and backs up any previous Deyra shell file. It does not install/remove packages or modify Niri, Hyprland, TQQ, or your existing desktop configuration. It creates the settings directory before startup.

Before testing, temporarily stop other panels, wallpaper renderers and notification daemons using their own documented controls if you want to avoid conflicts. In particular, only one notification daemon may own the desktop notification D-Bus name. Do not remove the existing desktop or lock screen.

## Version 0.2.0 — visual overhaul

- Centered layer-shell settings window instead of a tiled application window, with grouped navigation, dark input controls, smaller default palette and expandable access to all 80 colors.
- Event-driven opening/closing transitions for settings, launcher, control center, notifications and the window switcher. Hover, press, switch and workspace indicators animate without a continuously running shader. Disable motion in Settings → Performance → Reduce motion.
- Native vector status icons, Niri workspace event stream, Hyprland workspace polling, NetworkManager connectivity status, and a dock with active-window indicators and fallback icons.
- The new design retains existing saved settings and twelve selectable layout profiles. Native dialogs, layer-shell focus and compositor IPC need graphical testing.

## Implemented features

- TQQ-inspired island bar, desktop wallpaper surface, desktop clock option.
- Running-window dock and radial window switcher (up to 12 windows, compositor protocol required).
- Application launcher using desktop entries, with search and icons.
- Control center with PipeWire volume and brightness buttons.
- Notification popups, history and do-not-disturb.
- Settings window with seven top-level tabs: Themes, Edit Mode, Community, Profile, System, Performance, Updates.
- Theme accent, opacity, corner radius, bar position/height, module toggles, dock/clock toggles and local avatar.
- Twelve original Deyra style presets with source credits and a miniature palette preview. Open **Edit Mode → Presets**, select All or an individual component, then Apply. All changes the global style and resets component overrides; individual styles can be mixed across Bar, Dock, Launcher, Control Center, Notifications and Window Switcher. Use global clears an individual override. Presets now change actual component layouts as well as colors, transparency and rounding. They are native Deyra implementations inspired by the source projects, not full upstream ports.
- Static local wallpapers and on-demand online wallpaper search in fixed nature/space categories, with safe-only filter and local download. Click a result to download and apply; no API key needed. Internet results are user-uploaded content and subject to provider availability.
- Settings persistence in `$XDG_CONFIG_HOME/deyra-shell/settings.json` (normally `~/.config/deyra-shell/settings.json`).

## Appearance editor

Open Settings → Themes. Choose All or an individual component (Bar, Dock, Launcher, Control Center, Notifications or Window Switcher). Select Accent or Background, expand All 80 colors if desired, then choose from the swatches, enter a six-digit HEX value, or open the Qt color picker. The preview updates immediately. Opacity and corner radius are also configurable per scope. Inherit removes an individual component override; Reset appearance to preset restores its original colors and geometry without changing the chosen layout. Global edits do not overwrite existing component overrides.

QtQuick.Dialogs is required for color and file pickers (Debian: `qml6-module-qtquick-dialogs`). Appearance settings persist in settings.json. The editor has not yet been runtime-tested on Niri or Hyprland.

## Native component layout variants

Open Settings → Edit Mode → Presets. Select the target component, then apply a profile. Mix component layouts independently; selecting All resets overrides.

| Profile | Bar | Launcher | Dock | Control center | Switcher |
| --- | --- | --- | --- | --- | --- |
| TQQ Rice | Islands | Left list | Icons | Dashboard | Radial |
| Noctalia | Full | Center grid | Icons | Dashboard | Row |
| DankMaterialShell | Full | Center grid | Labeled | Tiles | Row |
| Caelestia | Notch | Center grid | Icons | Tiles | Radial |
| Illogical Impulse | Full | Wide grid | Labeled | Tiles | Row |
| HyDE | Groups | Center list | Icons | Compact | Row |
| ML4W | Groups | Center grid | Labeled | Dashboard | Row |
| iNiR | Full | Wide grid | Icons | Tiles | Radial |
| DotFriedRice | Minimal | Center list | Labeled | Compact | Row |
| Ambxst | Groups | Wide grid | Icons | Tiles | Radial |
| DarkShadow | Dynamic center island | Center grid | Labeled | Dashboard | Radial |
| Serpantinum | Notch | Center list | Icons | Compact | Row |

Layouts share Deyra services and are intentionally not pixel-identical copies of upstream. Notification presets still change appearance only; native lock screen, upstream widgets, full feature parity and compositor-specific behavior remain incomplete. This version has not been launched or validated in a graphical session.

## Compositor shortcuts

Test IPC from a terminal while the shell is running:

```sh
qs -c deyra ipc call deyra settings
qs -c deyra ipc call deyra launcher
qs -c deyra ipc call deyra wallpapers
qs -c deyra ipc call deyra control
qs -c deyra ipc call deyra switcher
```

Merge the following into your existing Niri `binds` block, replacing only conflicting bindings after reviewing them. Validate your config before enabling autostart.

```kdl
Mod+I { spawn "qs" "-c" "deyra" "ipc" "call" "deyra" "settings"; }
Mod+D { spawn "qs" "-c" "deyra" "ipc" "call" "deyra" "launcher"; }
Mod+B { spawn "qs" "-c" "deyra" "ipc" "call" "deyra" "wallpapers"; }
Mod+Shift+Space { spawn "qs" "-c" "deyra" "ipc" "call" "deyra" "control"; }
Alt+Tab { spawn "qs" "-c" "deyra" "ipc" "call" "deyra" "switcher"; }
```

Optional Niri autostart: `spawn-at-startup "qs" "-c" "deyra"`.

Hyprland equivalents (merge carefully, do not duplicate existing bindings):

```ini
bind = SUPER, I, exec, qs -c deyra ipc call deyra settings
bind = SUPER, D, exec, qs -c deyra ipc call deyra launcher
bind = SUPER, B, exec, qs -c deyra ipc call deyra wallpapers
bind = SUPER SHIFT, SPACE, exec, qs -c deyra ipc call deyra control
bind = ALT, TAB, exec, qs -c deyra ipc call deyra switcher
```

Optional Hyprland autostart: `exec-once = qs -c deyra`.

The switcher can also be confirmed with Enter/click and cancelled with Escape; Alt release and global bind interaction need compositor-specific testing.

## Roadmap

- Secure native session lock with PAM; use your existing tested lock screen until implemented.
- Tray, Wi-Fi connection management, Bluetooth, media, weather, calendar, OSD, power controls. Workspace and network status integration is present but needs testing.
- Full Edit Mode with component configuration, live previews, draggable modules, additional layout variants and per-component animations.
- Animated local wallpapers with pause-on-fullscreen and reduced-quality mode; daily, favorites, collections, transitions and image-derived palette.
- Profile usage-time tracking, language and keybind editor, performance profiles, update UI.
- Community widgets and deeper upstream component ports: opt-in, author attribution and license review before redistribution. No third-party shell code or assets imported in this alpha.

### Preset inspiration / credits

| Project | Source |
| --- | --- |
| TQQ Rice | [zadrotov7000/TQQ-Niri-rice](https://github.com/zadrotov7000/TQQ-Niri-rice) |
| Noctalia | [noctalia-dev/noctalia](https://github.com/noctalia-dev/noctalia) |
| DankMaterialShell | [duxlabs-dev/dux-shell](https://github.com/duxlabs-dev/dux-shell) (formerly AvengeMedia/DankMaterialShell) |
| Caelestia | [caelestia-dots/shell](https://github.com/caelestia-dots/shell) |
| Illogical Impulse | [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) |
| HyDE | [HyDE-Project/HyDE](https://github.com/HyDE-Project/HyDE) |
| ML4W | [mylinuxforwork/dotfiles](https://github.com/mylinuxforwork/dotfiles) |
| iNiR | [snowarch/iNiR](https://github.com/snowarch/iNiR) |
| DotFriedRice | [nickjj/dotfriedrice](https://github.com/nickjj/dotfriedrice) |
| Ambxst | [Axenide/Ambxst](https://github.com/Axenide/Ambxst) |
| DarkShadow | [shadowww-dev/DarkShadowShell](https://github.com/shadowww-dev/DarkShadowShell) |
| Serpantinum | [ilyamiro/serpantinum](https://github.com/ilyamiro/serpantinum) |

The above are sources of inspiration for selectable Deyra-made style presets, not bundled upstream configurations, exact replicas or endorsements. No upstream license is claimed for original Deyra presets. Project license not yet selected by owner. Runtime behavior, memory consumption and compositor compatibility have not been tested in a graphical session.
