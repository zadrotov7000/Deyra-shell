# Deyra Shell

An experimental modular Wayland desktop shell written in QML and JavaScript with Quickshell. The first visual direction is the dark, rounded island design of [TQQ Niri Rice](https://github.com/zadrotov7000/TQQ-Niri-rice).

**1.0.0-dev — original shell manager, development build. Not a stable 1.0 release.** Targets Niri and Hyprland.

## Install and test

Requirements: a running Wayland compositor with layer-shell and foreign-toplevel-management support, Quickshell 0.2.1 or newer built with Wayland, PipeWire and notifications modules, Qt Quick Controls/Layouts and Qt.labs.folderlistmodel, curl and optionally brightnessctl. On Debian, check your installed Quickshell version and QML modules. Uses the system sans-serif font; no dedicated icon font required.

```sh
git clone https://github.com/zadrotov7000/Deyra-shell.git
cd Deyra-shell
sh install.sh
qs -c deyra
```

Run in a terminal for the first smoke test; Ctrl+C stops the shell. The installer copies only the shell configuration to the user's XDG configuration directory and backs up any previous Deyra shell file. It does not install/remove packages or modify Niri, Hyprland, TQQ, or your existing desktop configuration. It creates the settings directory before startup.

Before testing, temporarily stop other panels, wallpaper renderers and notification daemons using their own documented controls if you want to avoid conflicts. In particular, only one notification daemon may own the desktop notification D-Bus name. Do not remove the existing desktop or lock screen.

## 1.0.0-dev — managed installation of original shells

Settings → Themes → Original themes now distinguishes source downloads from real runtime installations. The manager does not redraw upstream interfaces. Select **Install**, review the confirmation, then authenticate if APT needs missing dependencies. The operation log remains inside Settings. Select **Apply** after the runtime is installed. Deyra yields desktop surfaces and its notification server to the upstream runtime; open the manager using `qs -c deyra ipc call deyra settings`.

### Installation coverage (Debian / Ubuntu x86-64)

| Project | Managed installation path |
| --- | --- |
| Serpantinum | Original repository and its full QML tree, original daemon and version-pinned upstream core/audio/gamma binaries. SHA-256 checked against release manifests. Needs compatible Quickshell. Two automatic migration scripts are disabled to avoid modifying the user's existing Niri and EasyEffects settings. Optional external programs, PAM service and compositor-specific keybind integration remain untested or incomplete. |
| Noctalia | Original C++ source via Meson, official Debian build dependencies, one compile job. Needs at least 5 GiB free before package installation; may need more to finish. |
| DankMaterialShell / Dux | Actual `dms` APT package if the upstream repository is already configured. No automatic repository trust or key changes. Dux packages installed outside Deyra remain externally managed. |
| Caelestia, Illogical Impulse, iNiR, Ambxst | Source download/update and launch of separately installed runtime where compatible. No managed install recipe yet. |
| DarkShadow, TQQ Rice, HyDE, ML4W, DotFriedRice | Source download/update only; full session integration remains unimplemented. |

Local installations live under `$XDG_DATA_HOME/deyra-shell/managed` (default `~/.local/share/deyra-shell/managed`). Update installs to a fresh versioned directory before changing the active manifest; Rollback selects the previous completed local version. Remove deletes only manager-owned versions; for Dux, removal is simulated first and rejected if it would remove other packages. Shared dependencies and personal settings are retained. APT dependency installation uses a simulation and `--no-remove`, and requires authentication through polkit/pkexec when missing packages must be installed. There is no automatic package removal or compositor configuration deployment. Upstream shells can manage their own configuration while running.

The source checkout location remains `~/.config/deyra-shell/upstream` (or XDG equivalent). A downloaded source is not an installed shell. Source updates are fast-forward-only.

### Validation and release gate

`python3 -m unittest discover -s tests -p 'test_*.py' -v` runs offline tests using temporary directories and mocked downloads/builds. GitHub Actions checks the Python and installer syntax and runs these tests. Real graphical installation, service startup, screen locking, compositor shortcuts, package availability and switching must be verified on supported distributions before declaring 1.0 stable. This development build does **not** claim that all twelve original shells can be installed or used with every feature.

## Version 0.3.0 — original shell runtime manager

Themes → Original themes → Launch original now invokes the **installed original project**, not Deyra's former layout preset. The original project's services, configuration, UI and dependencies are responsible for its features. Deyra releases its bar, background, notifications registration and panel surfaces while the selected runtime is active. Reopen the manager at any time with `qs -c deyra ipc call deyra settings` and choose Return to Deyra. The original foreground process is tracked; a startup failure or process exit restores Deyra. A process staying alive does not prove all of its features work.

Install the upstream runtime and its dependencies according to its own documentation before using this option. Download configs only retrieves the original repository, not an installation. No upstream installer, package manager, or compositor configuration replacement is run by Deyra. Start Deyra with no other shell already active, and disable conflicting upstream autostart manually before switching.

| Project | Native entrypoint | Compositor in this manager |
| --- | --- | --- |
| Serpantinum | `serpantinumd start` | Niri, Hyprland |
| Noctalia | `noctalia` | Niri, Hyprland |
| DankMaterialShell / Dux | `dms run` | Niri, Hyprland |
| iNiR | `inir run --foreground` | Niri |
| Ambxst | `ambxst` | Niri, Hyprland |
| Caelestia | `qs -c caelestia` | Hyprland |
| Illogical Impulse | `qs -c ii` | Hyprland |

TQQ Rice, DarkShadow, HyDE, ML4W and DotFriedRice remain catalog entries only for full-shell switching: they require multi-process/session integration, and switching those safely has not been implemented. Older Deyra component variants remain available in Edit Mode as legacy Deyra layouts. They are not advertised as original runtimes. The Deyra Matugen palette applies only to Deyra and its partial ports, not to full independent original shells.

This version does not install all twelve shells, share compositor keybinds or guarantee upstream dependencies on Debian. Serpantinum's full runtime, for example, needs its original installed daemon and backend; downloading QML alone is insufficient. Foreground process lifecycle and session compatibility require testing. The manager never uses a generic pkill on Quickshell. See upstream docs: [Serpantinum](https://serpantinum.dev/installation), [Noctalia](https://docs.noctalia.dev/noctalia/), [Dux](https://duxlabs.dev/docs/dms/cli-process-management), [iNiR](https://inir.space/docs/commands/), [Illogical Impulse](https://ii.clsty.link/en/ii-qs/01setup/).

## Version 0.2.6 — Matugen and no dock

The bottom application dock has been removed, including the Dock settings category. Existing saved dock preferences are ignored. The top bar and launcher remain.

Install Matugen separately if it is missing. Deyra uses its own installed `matugen/config.toml`, disables template writes with `--dry-run`, and reads the JSON color scheme. It generates a dark Material palette when the wallpaper changes, at startup, or on demand via **Themes → Colors & appearance → Regenerate**. It does not modify other rice configurations, terminals, or the compositor. Manual colors are retained and selecting a manual accent/background disables automatic colors. The imported TQQ launcher, switcher and Wi-Fi panel receive the Deyra palette at launch through their environment. This release does not recolor every upstream component or control outside Deyra. Graphical testing is pending.

## Version 0.2.5 — actual upstream code

The first source ports are included in `ports/` and installed alongside Deyra. These are distinct from the older native layout approximations.

| Original source | Included file | Integration |
| --- | --- | --- |
| [TQQ launcher](https://github.com/zadrotov7000/TQQ-Niri-rice/blob/main/quickshell/tqq-launcher/shell.qml) | `ports/tqq/launcher/shell.qml` | Original, unmodified launcher when the TQQ Launcher preset is selected |
| [TQQ switcher](https://github.com/zadrotov7000/TQQ-Niri-rice/blob/main/quickshell/tqq-switcher/shell.qml) | `ports/tqq/switcher/shell.qml` | Original Niri radial switcher; Hyprland retains Deyra fallback |
| [TQQ Wi-Fi](https://github.com/zadrotov7000/TQQ-Niri-rice/blob/main/quickshell/tqq-wifi/shell.qml) | `ports/tqq/wifi/shell.qml` | Original NetworkManager panel, opened from TQQ bar network button |
| [Dux DesktopClock](https://github.com/duxlabs-dev/dux-shell/blob/master/quickshell/PLUGINS/ExampleDesktopClock/DesktopClock.qml) | `ports/dux/DesktopClock.qml` | Original analog/digital clock geometry, adapted plugin/theme properties |
| [DarkShadow WavyLine](https://github.com/shadowww-dev/DarkShadowShell/blob/main/quickshell/rice-desktop/WavyLine.qml) | `ports/darkshadow/WavyLine.qml` | Original wave drawing and seeking behavior in DarkShadow Control Center volume slider |

Original licenses are included next to each port (TQQ GPLv3, Dux MIT, DarkShadow MIT). The two MIT files record their original blob hashes and modifications. TQQ panels execute as separate Quickshell processes so their original Qt.quit() does not stop the main Deyra shell. They can read existing TQQ palette data, but Deyra does not install or edit TQQ. Wi-Fi requires NetworkManager. All settings remain in one Deyra Settings window. **System → Use imported original components** switches between these ports and Deyra's native approximations. Desktop Widgets allows explicit selection of the Dux clock.

Only these five components are actual source ports in this release. The remaining nine project profiles and other parts of these three projects are still partial/native adaptations, not full upstream components. In particular, Dynamic Island and full Dux shell have additional service dependencies; original configs cannot be substituted blindly. Runtime tests remain pending.

## Version 0.2.4 — one settings window

All settings tabs remain inside a single centered panel. Color editing and wallpaper/avatar selection open embedded editors, not native dialog windows. Escape dismisses the embedded editor first and then closes Settings. The settings IPC action opens the existing window instead of toggling it closed. Explicit GitHub/showcase and file-manager links may still open their external applications. The embedded image browser requires the Qt folder list model. Runtime testing remains pending.

## Version 0.2.3 — original project library

Open Settings → Themes → Original themes. All twelve projects are represented. Screenshots link to their original project README or official showcase; the original authors retain their rights. No generated substitute screenshot is shown. TQQ Rice has no verified screenshot in its README, and Caelestia has a linked original video instead of an inline still. Image loading requires internet; a failed image offers the original showcase link.

Download configs clones the selected original repository, including its configuration and source files, at the current default branch into `~/.config/deyra-shell/upstream/<project>` (or the equivalent XDG directory). Downloads are individual and optional to avoid consuming disk space. Git is required. No upstream installation scripts are executed, no dependencies are installed, and no compositor configuration is overwritten. Open originals opens that folder in your file manager. Existing downloads are retained unchanged.

Apply Deyra port is deliberately separate: it applies the existing partial Deyra implementation, **not** the original shell or all its configuration files. Original configs are not interchangeable across these projects; native plugins, compositor integrations and services require further porting. Do not mistake official screenshots for the current Deyra rendering. Colors & appearance preserves the existing color editor.

## Version 0.2.1 — source-derived configurations

Open **Settings → Edit Mode → Bar** to select a source layout, adjust size and spacing, choose a workspace indicator style, or add, reorder and remove modules in any of the three bar sections. These are native Deyra implementations based on inspected upstream settings, not bundled copies of upstream shell code. Source links and repository-level license information are displayed in the editor; Serpantinum's license was not verified.

| Source | Inspected configuration | Deyra adaptation |
| --- | --- | --- |
| TQQ Rice | `config/waybar/config` | Island module order, storage status |
| Noctalia | `example.toml` | Three sections, insets, module spacing |
| DankMaterialShell / Dux | `quickshell/Common/BarWidgetCatalog.qml`, `quickshell/Common/settings/BarWidgetDefaults.js` | Widget sections and pill indicators |
| Caelestia | `plugin/src/Caelestia/Config/barconfig.hpp` | Active-window and status placement; horizontal adaptation |
| Illogical Impulse | `dots/.config/quickshell/ii/modules/ii/bar/BarContent.qml` | Center resources, media and workspaces |
| HyDE | `Configs/.config/waybar/config.jsonc` | Grouped sections and system indicators |
| ML4W | `dotfiles/.config/waybar/themes/ml4w/config` | Center workspaces, right-side clock |
| iNiR | `defaults/config.json` | Switcher alignment, duration and animation options |
| DotFriedRice | `.config/waybar/config.jsonc` | Compact bar and supported module order |
| Ambxst | `config/defaults/bar.js` | Optional frame and 12/24-hour clock |
| DarkShadow | `quickshell/rice-desktop/Bar.qml` | Clock island and supported section order |
| Serpantinum | `src/quickshell/bar/BarModuleRegistry.qml` | Selectable workspace faces (native approximations) |

The module catalog includes application launcher, workspaces, active title, clock, now playing, volume, network, notifications, battery, disk usage, CPU load, memory, brightness, wallpapers, control center and settings. Media and brightness need optional `playerctl` and `brightnessctl`; unavailable battery/media/brightness modules are hidden. Imported arrangements omit unsupported upstream modules such as system tray, clipboard, Bluetooth, full taskbar and power menu. No upstream installers or arbitrary upstream commands are executed. Existing shell configs are not modified.

In **Edit Mode → Window Switcher**, compact mode, alignment and transition duration can be configured independently. Source selection can change these options. These ports require graphical verification on Niri and Hyprland; exact visual parity is not claimed.

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

The embedded local image browser uses Qt.labs.folderlistmodel (Debian: `qml6-module-qt-labs-folderlistmodel`). Color editing is built into Deyra Settings and no longer uses QtQuick.Dialogs. Appearance settings persist in settings.json. The editor has not yet been runtime-tested on Niri or Hyprland.

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
