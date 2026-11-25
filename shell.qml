import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import "ports/dux" as Dux
import "ports/darkshadow" as Shadow
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications

ShellRoot {
    id: root
    property string page: ""
    readonly property bool useDuxDesktopClock: prefs.useOriginalPorts && (prefs.desktopClockStyle === "dux" || (prefs.desktopClockStyle === "source" && prefs.activePreset === "DankMaterialShell"))
    property string settingsTab: "Themes"
    property string editTab: "Bar"
    property string wallpaperTab: "Local"
    property string status: ""
    property var onlineResults: []
    property bool searching: false
    property int selectedWindow: 0
    property var windows: Array.from(ToplevelManager.toplevels.values).slice(0, 12)
    property var now: new Date()
    readonly property bool isNiri: !!Quickshell.env("NIRI_SOCKET")
    readonly property bool isHyprland: !isNiri && !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    property var workspaces: []
    property string networkLabel: ""
    property string networkKind: "offline"
    function workspacesFor(output) {
        const rows = workspaces.filter(function(w) { return !output || w.output === output })
        return rows.sort(function(a,b) { return a.idx-b.idx }).slice(0, 9)
    }
    function niriEvent(line) {
        try {
            const event = JSON.parse(line)
            if (event.WorkspacesChanged) workspaces = event.WorkspacesChanged.workspaces || []
            else if (event.WorkspaceActivated) {
                const e = event.WorkspaceActivated
                const target = workspaces.find(function(w) { return w.id === e.id })
                if (!target) return
                workspaces = workspaces.map(function(w) {
                    const copy = Object.assign({},w)
                    if (w.output === target.output) copy.is_active = w.id === e.id
                    if (e.focused) copy.is_focused = w.id === e.id
                    return copy
                })
            }
        } catch(e) { /* Ignore non-JSON diagnostics. */ }
    }
    function activateWorkspace(ws) {
        if (!ws || !Number.isInteger(ws.id)) return
        if (isNiri) Quickshell.execDetached(["sh","-c","printf '%s\\n' \"$1\" | niri msg raw-request","deyra",JSON.stringify({Action:{FocusWorkspace:{reference:{Id:ws.id}}}})])
        else if (isHyprland && ws.id > 0) Quickshell.execDetached(["hyprctl","dispatch","workspace",String(ws.id)])
    }
    // The manual theme stays stored independently of the generated Material palette.
    readonly property bool dynamicColors: prefs.matugenEnabled && !!prefs.matugenPalette.primary
    function paletteColor(key, fallback) {
        const value = prefs.matugenPalette[key]
        return dynamicColors && typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value) ? value : fallback
    }
    property color accent: paletteColor("primary", prefs.accent)
    property color surface: Qt.alpha(paletteColor("background", prefs.background), prefs.opacity)
    property color foreground: paletteColor("on_surface","#e9eaf0")
    property color uiBase: paletteColor("background","#17181d")
    property color uiPanel: paletteColor("surface_container","#202127")
    property color uiRaised: paletteColor("surface_container_high","#292b33")
    readonly property color uiMuted: paletteColor("on_surface_variant","#999da9")
    readonly property color uiLine: paletteColor("outline_variant","#34363e")
    Behavior on accent { ColorAnimation { duration: root.motion } }
    Behavior on surface { ColorAnimation { duration: root.motion } }
    Behavior on foreground { ColorAnimation { duration: root.motion } }
    Behavior on uiBase { ColorAnimation { duration: root.motion } }
    Behavior on uiPanel { ColorAnimation { duration: root.motion } }
    Behavior on uiRaised { ColorAnimation { duration: root.motion } }
    readonly property int motion: prefs.reduceMotion ? 0 : 200
    function tint(bg, amount) { return Qt.tint(bg, Qt.rgba(1,1,1,amount)) }
    function pageDescription(tab) {
        return ({ "Themes":"Make the desktop feel like your own.", "Edit Mode":"Arrange and customize each part of your desktop.", "Community":"Discover community designs and their creators.", "Profile":"Your account and machine.", "System":"Shell behavior and keyboard shortcuts.", "Performance":"Balance motion, appearance and resource usage.", "Updates":"Version and release information." })[tab] || ""
    }
    property string configPath: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    property string statePath: configPath + "/deyra-shell"
    property var currentToast: null
    property string toastTitle: ""
    property string toastBody: ""
    property bool dnd: false
    property string systemInfo: ""
    property string profileName: Quickshell.env("USER") || "User"
    // Original Deyra style presets. No upstream code or artwork is bundled.
    readonly property var presets: [
        {
            "name": "TQQ Rice",
            "author": "zadrotov7000",
            "url": "https://github.com/zadrotov7000/TQQ-Niri-rice",
            "accent": "#a38ff7",
            "bg": "#0f111e",
            "opacity": 0.91,
            "radius": 17,
            "height": 42,
            "bottom": false,
            "clock": true,
            "description": "Dark floating islands"
        },
        {
            "name": "Noctalia",
            "author": "noctalia-dev",
            "url": "https://github.com/noctalia-dev/noctalia",
            "accent": "#c6a0f6",
            "bg": "#24273a",
            "opacity": 0.96,
            "radius": 14,
            "height": 40,
            "bottom": false,
            "clock": true,
            "description": "Muted rounded panels"
        },
        {
            "name": "DankMaterialShell",
            "author": "duxlabs-dev / AvengeMedia",
            "url": "https://github.com/duxlabs-dev/dux-shell",
            "accent": "#a9c7ff",
            "bg": "#1a202c",
            "opacity": 0.98,
            "radius": 24,
            "height": 48,
            "bottom": false,
            "clock": true,
            "description": "Material-inspired blue"
        },
        {
            "name": "Caelestia",
            "author": "caelestia-dots",
            "url": "https://github.com/caelestia-dots/shell",
            "accent": "#f5c2e7",
            "bg": "#1e1e2e",
            "opacity": 0.94,
            "radius": 28,
            "height": 48,
            "bottom": false,
            "clock": true,
            "description": "Soft rounded pastel"
        },
        {
            "name": "Illogical Impulse",
            "author": "end-4",
            "url": "https://github.com/end-4/dots-hyprland",
            "accent": "#b8d1a0",
            "bg": "#20271f",
            "opacity": 0.97,
            "radius": 24,
            "height": 46,
            "bottom": true,
            "clock": true,
            "description": "Material-inspired sage"
        },
        {
            "name": "HyDE",
            "author": "HyDE-Project",
            "url": "https://github.com/HyDE-Project/HyDE",
            "accent": "#89dceb",
            "bg": "#161b26",
            "opacity": 0.72,
            "radius": 10,
            "height": 38,
            "bottom": false,
            "clock": true,
            "description": "Cool transparent islands"
        },
        {
            "name": "ML4W",
            "author": "mylinuxforwork",
            "url": "https://github.com/mylinuxforwork/dotfiles",
            "accent": "#82aaff",
            "bg": "#222832",
            "opacity": 0.96,
            "radius": 8,
            "height": 44,
            "bottom": false,
            "clock": true,
            "description": "Compact blue panels"
        },
        {
            "name": "iNiR",
            "author": "snowarch",
            "url": "https://github.com/snowarch/iNiR",
            "accent": "#f0b8c8",
            "bg": "#30212b",
            "opacity": 0.94,
            "radius": 22,
            "height": 44,
            "bottom": false,
            "clock": true,
            "description": "Rounded rose deyraStyle"
        },
        {
            "name": "DotFriedRice",
            "author": "nickjj",
            "url": "https://github.com/nickjj/dotfriedrice",
            "accent": "#8ec07c",
            "bg": "#202423",
            "opacity": 0.99,
            "radius": 4,
            "height": 38,
            "bottom": false,
            "clock": false,
            "description": "Minimal compact green"
        },
        {
            "name": "Ambxst",
            "author": "Axenide",
            "url": "https://github.com/Axenide/Ambxst",
            "accent": "#ffc78e",
            "bg": "#29211f",
            "opacity": 0.88,
            "radius": 20,
            "height": 46,
            "bottom": true,
            "clock": true,
            "description": "Warm floating controls"
        },
        {
            "name": "DarkShadow",
            "author": "shadowww-dev",
            "url": "https://github.com/shadowww-dev/DarkShadowShell",
            "accent": "#9aa9ff",
            "bg": "#10121a",
            "opacity": 0.82,
            "radius": 20,
            "height": 44,
            "bottom": false,
            "clock": true,
            "description": "Dark translucent material"
        },
        {
            "name": "Serpantinum",
            "author": "ilyamiro",
            "url": "https://github.com/ilyamiro/serpantinum",
            "accent": "#8bd5ca",
            "bg": "#18252b",
            "opacity": 0.85,
            "radius": 16,
            "height": 42,
            "bottom": false,
            "clock": true,
            "description": "Teal glass-inspired panels"
        }
    ]
    readonly property var supportedScopes: ["Bar", "Launcher", "Control Center", "Notifications", "Window Switcher"]
    // Native component layouts, independent of colors; inspired by upstream UI concepts.
    readonly property var layoutProfiles: ({
        "TQQ Rice":          ["islands", "list-left", "icons", "dashboard", "radial"],
        "Noctalia":          ["full", "grid-center", "icons", "dashboard", "row"],
        "DankMaterialShell": ["full", "grid-center", "labeled", "tiles", "row"],
        "Caelestia":         ["notch", "grid-center", "icons", "tiles", "radial"],
        "Illogical Impulse": ["full", "grid-wide", "labeled", "tiles", "row"],
        "HyDE":              ["groups", "list-center", "icons", "compact", "row"],
        "ML4W":              ["groups", "grid-center", "labeled", "dashboard", "row"],
        "iNiR":              ["full", "grid-wide", "icons", "tiles", "radial"],
        "DotFriedRice":      ["minimal", "list-center", "labeled", "compact", "row"],
        "Ambxst":           ["groups", "grid-wide", "icons", "tiles", "radial"],
        "DarkShadow":       ["dynamic", "grid-center", "labeled", "dashboard", "radial"],
        "Serpantinum":      ["notch", "list-center", "icons", "compact", "row"]
    })
    function layoutFor(scope) {
        const idx = ["Bar","Launcher","Dock","Control Center","Window Switcher"].indexOf(scope)
        const layouts = layoutProfiles[styleFor(scope).name] || layoutProfiles["TQQ Rice"]
        return idx >= 0 ? layouts[idx] : "default"
    }
    // Data-only translations of inspected upstream settings. No upstream code is executed.
    readonly property var sourceProfiles: [
        {
            "name": "TQQ Rice",
            "repo": "zadrotov7000/TQQ-Niri-rice",
            "path": "config/waybar/config",
            "license": "GPL-3.0",
            "left": [
                "launcher",
                "workspaces"
            ],
            "center": [
                "clock"
            ],
            "right": [
                "disk",
                "notifications",
                "network",
                "volume",
                "settings"
            ],
            "height": 40,
            "spacing": 7,
            "margin": 12,
            "face": "pills",
            "description": "Clock and storage; native equivalents of the original island bar."
        },
        {
            "name": "Noctalia",
            "repo": "noctalia-dev/noctalia",
            "path": "example.toml",
            "license": "MIT",
            "left": [
                "launcher",
                "wallpaper",
                "workspaces"
            ],
            "center": [
                "clock"
            ],
            "right": [
                "media",
                "notifications",
                "network",
                "volume",
                "brightness",
                "battery",
                "control",
                "settings"
            ],
            "height": 34,
            "spacing": 6,
            "margin": 180,
            "face": "pills",
            "description": "Example TOML start/center/end ordering; floating launcher and inset bar."
        },
        {
            "name": "DankMaterialShell",
            "repo": "duxlabs-dev/dux-shell",
            "path": "quickshell/Common/BarWidgetCatalog.qml",
            "license": "MIT",
            "left": [
                "launcher",
                "workspaces",
                "title"
            ],
            "center": [
                "clock",
                "media"
            ],
            "right": [
                "cpu",
                "memory",
                "network",
                "volume",
                "battery",
                "notifications",
                "control"
            ],
            "height": 40,
            "spacing": 6,
            "margin": 4,
            "face": "pills",
            "description": "Widget catalog sections and pill workspace defaults; supported subset."
        },
        {
            "name": "Caelestia",
            "repo": "caelestia-dots/shell",
            "path": "plugin/src/Caelestia/Config/barconfig.hpp",
            "license": "GPL-3.0",
            "left": [
                "launcher",
                "workspaces"
            ],
            "center": [
                "title"
            ],
            "right": [
                "clock",
                "network",
                "battery",
                "settings"
            ],
            "height": 38,
            "spacing": 6,
            "margin": 8,
            "face": "morph",
            "description": "Logo/workspaces/active window/clock/status order, horizontally adapted."
        },
        {
            "name": "Illogical Impulse",
            "repo": "end-4/dots-hyprland",
            "path": "dots/.config/quickshell/ii/modules/ii/bar/BarContent.qml",
            "license": "GPL-3.0",
            "left": [
                "launcher",
                "title"
            ],
            "center": [
                "memory",
                "media",
                "workspaces",
                "clock",
                "battery"
            ],
            "right": [
                "volume",
                "network",
                "control"
            ],
            "height": 42,
            "spacing": 6,
            "margin": 8,
            "face": "pills",
            "description": "Central resources, media, workspaces and clock; left active title."
        },
        {
            "name": "HyDE",
            "repo": "HyDE-Project/HyDE",
            "path": "Configs/.config/waybar/config.jsonc",
            "license": "GPL-3.0",
            "left": [
                "launcher",
                "workspaces",
                "title"
            ],
            "center": [
                "clock"
            ],
            "right": [
                "brightness",
                "network",
                "volume",
                "battery",
                "cpu",
                "notifications",
                "settings"
            ],
            "height": 38,
            "spacing": 5,
            "margin": 8,
            "face": "dots",
            "description": "Leaf/pill group configuration; original taskbar represented by title."
        },
        {
            "name": "ML4W",
            "repo": "mylinuxforwork/dotfiles",
            "path": "dotfiles/.config/waybar/themes/ml4w/config",
            "license": "GPL-3.0",
            "left": [
                "launcher",
                "title"
            ],
            "center": [
                "workspaces"
            ],
            "right": [
                "volume",
                "network",
                "battery",
                "cpu",
                "notifications",
                "settings",
                "clock"
            ],
            "height": 40,
            "spacing": 0,
            "margin": 0,
            "face": "numbers",
            "description": "App menu and active window left; workspaces center; clock at far right."
        },
        {
            "name": "iNiR",
            "repo": "snowarch/iNiR",
            "path": "defaults/config.json",
            "license": "GPL-3.0",
            "left": [
                "launcher",
                "title",
                "workspaces"
            ],
            "center": [
                "clock"
            ],
            "right": [
                "media",
                "network",
                "volume",
                "battery",
                "control"
            ],
            "height": 40,
            "spacing": 6,
            "margin": 8,
            "face": "pills",
            "description": "Native Niri layout adaptation; source Alt+Tab default timing and compact option available."
        },
        {
            "name": "DotFriedRice",
            "repo": "nickjj/dotfriedrice",
            "path": ".config/waybar/config.jsonc",
            "license": "MIT",
            "left": [
                "launcher",
                "workspaces"
            ],
            "center": [
                "clock"
            ],
            "right": [
                "media",
                "volume",
                "network",
                "cpu",
                "battery"
            ],
            "height": 24,
            "spacing": 0,
            "margin": 0,
            "face": "numbers",
            "description": "Compact 24px bar and supported subset of its actual module order."
        },
        {
            "name": "Ambxst",
            "repo": "Axenide/Ambxst",
            "path": "config/defaults/bar.js",
            "license": "AGPL-3.0",
            "left": [
                "launcher",
                "workspaces"
            ],
            "center": [
                "clock"
            ],
            "right": [
                "media",
                "network",
                "volume",
                "control"
            ],
            "height": 42,
            "spacing": 4,
            "margin": 8,
            "face": "pills",
            "description": "Top-edge default, optional six-pixel frame and 24-hour clock."
        },
        {
            "name": "DarkShadow",
            "repo": "shadowww-dev/DarkShadowShell",
            "path": "quickshell/rice-desktop/Bar.qml",
            "license": "MIT",
            "left": [
                "launcher",
                "workspaces",
                "title"
            ],
            "center": [
                "clock"
            ],
            "right": [
                "media",
                "volume",
                "network",
                "battery",
                "notifications",
                "settings"
            ],
            "height": 38,
            "spacing": 6,
            "margin": 8,
            "face": "pills",
            "description": "Original left/center/right fallback structure, dynamic clock island."
        },
        {
            "name": "Serpantinum",
            "repo": "ilyamiro/serpantinum",
            "path": "src/quickshell/bar/BarModuleRegistry.qml",
            "license": "Unverified",
            "left": [
                "launcher",
                "workspaces"
            ],
            "center": [
                "clock",
                "media"
            ],
            "right": [
                "network",
                "volume",
                "battery",
                "settings"
            ],
            "height": 40,
            "spacing": 6,
            "margin": 8,
            "face": "morph",
            "description": "Registry-derived pills, numbers, morph and trace workspace faces; Deyra ordering."
        }
    ]
    readonly property var barCatalog: [
        {key:"launcher",title:"Applications"},{key:"workspaces",title:"Workspaces"},
        {key:"title",title:"Active window"},{key:"clock",title:"Clock / calendar"},
        {key:"media",title:"Now playing"},{key:"volume",title:"Volume"},
        {key:"network",title:"Network"},{key:"notifications",title:"Notifications"},
        {key:"battery",title:"Battery"},{key:"disk",title:"Disk usage"},
        {key:"cpu",title:"CPU load"},{key:"memory",title:"Memory"},
        {key:"brightness",title:"Brightness"},{key:"wallpaper",title:"Wallpapers"},
        {key:"control",title:"Control center"},{key:"settings",title:"Settings"}
    ]
    readonly property var selectedBarSource: sourceProfiles.find(function(p) {return p.name === styleFor("Bar").name}) || sourceProfiles[0]
    readonly property var effectiveBarLayout: prefs.customBarLayout && Array.isArray(prefs.customBarLayout.left) && Array.isArray(prefs.customBarLayout.center) && Array.isArray(prefs.customBarLayout.right) ? prefs.customBarLayout : selectedBarSource
    readonly property string workspaceFace: prefs.workspaceFace === "source" ? selectedBarSource.face : prefs.workspaceFace
    readonly property var sourceForBar: selectedBarSource
    function sourceLink(p) {
        const branch = ["HyDE","DotFriedRice","Serpantinum","DankMaterialShell"].indexOf(p.name) >= 0 ? "master" : "main"
        return "https://github.com/" + p.repo + "/blob/" + branch + "/" + p.path
    }
    function moduleTitle(key) { const item = barCatalog.find(function(m){return m.key === key}); return item ? item.title : key }
    function barLayoutCopy() {
        const v = effectiveBarLayout
        return {left:v.left.slice(), center:v.center.slice(), right:v.right.slice()}
    }
    function addBarModule(section,key) {
        if (["left","center","right"].indexOf(section)<0 || !barCatalog.some(function(m){return m.key===key})) return
        const next = barLayoutCopy()
        for (const k of ["left","center","right"]) next[k] = next[k].filter(function(m){return m!==key})
        next[section].push(key)
        prefs.customBarLayout = next
    }
    function moveBarModule(section,index,delta) {
        const next = barLayoutCopy(), list = next[section]
        if (!list || index<0 || index>=list.length || index+delta<0 || index+delta>=list.length) return
        const temp = list[index]; list[index] = list[index+delta]; list[index+delta] = temp
        prefs.customBarLayout = next
    }
    function removeBarModule(section,index) {
        const next = barLayoutCopy()
        if (!next[section] || index<0 || index>=next[section].length) return
        next[section].splice(index,1)
        prefs.customBarLayout = next
    }
    function applySourceBar(name) {
        const p = sourceProfiles.find(function(item){return item.name===name})
        if (!p) return
        prefs.customBarLayout = ({})
        prefs.workspaceFace = "source"
        prefs.barSpacing = p.spacing
        prefs.barInset = p.margin
        prefs.barHeight = p.height
        prefs.barBottom = false
    }
    property string batteryText: ""
    property string diskText: ""
    property string memoryText: ""
    property string loadText: ""
    property string mediaText: ""
    property string brightnessText: ""
    function applySwitcherSource(name) {
        // iNiR defaults/config.json: right alignment, 200 ms duration, animation disabled.
        // Other profiles retain Deyra defaults unless explicitly customized.
        prefs.switcherCompact = false
        prefs.switcherAlign = name === "iNiR" ? "right" : "center"
        prefs.switcherDuration = 200
        prefs.switcherAnimated = name !== "iNiR"
    }
    function activeTitle() {
        const focused = windows.find(function(w){return w.activated})
        return focused ? focused.title : ""
    }
    function styleFor(scope) {
        const p = (prefs.componentStyles || {})[scope]
        const base = p || {name: prefs.activePreset, accent: prefs.accent, bg: prefs.background, opacity: prefs.opacity, radius: prefs.radius}
        return dynamicColors ? Object.assign({}, base, {accent:paletteColor("primary",base.accent), bg:paletteColor("background",base.bg)}) : base
    }
    function applyPreset(preset, scope) {
        if (scope === "All") {
            prefs.accent = preset.accent
            prefs.background = preset.bg
            prefs.opacity = preset.opacity
            prefs.radius = preset.radius
            prefs.barHeight = preset.height
            prefs.barBottom = preset.bottom
            prefs.desktopClock = preset.clock
            prefs.activePreset = preset.name
            prefs.componentStyles = ({})
            applySourceBar(preset.name)
            applySwitcherSource(preset.name)
        } else if (supportedScopes.indexOf(scope) >= 0) {
            const next = Object.assign({}, prefs.componentStyles)
            next[scope] = {name: preset.name, accent: preset.accent, bg: preset.bg, opacity: preset.opacity, radius: preset.radius}
            prefs.componentStyles = next
            if (scope === "Bar") applySourceBar(preset.name)
            if (scope === "Window Switcher") applySwitcherSource(preset.name)
        } else return
        status = preset.name + " applied to " + scope
    }
    function resetComponent(scope) {
        const next = Object.assign({}, prefs.componentStyles)
        delete next[scope]
        prefs.componentStyles = next
        if (scope === "Bar") applySourceBar(prefs.activePreset)
        if (scope === "Window Switcher") applySwitcherSource(prefs.activePreset)
        status = scope + " now follows global appearance"
    }
    function componentPreview(scope) { return scope === "All" ? prefs.activePreset : styleFor(scope).name }
    readonly property var upstreamMedia: {
        "TQQ Rice": {
            "image": "",
            "gallery": "https://github.com/zadrotov7000/TQQ-Niri-rice",
            "credit": "zadrotov7000"
        },
        "Noctalia": {
            "image": "https://noctalia.dev/_app/immutable/assets/dreadwarrior2k.q9cLEQ2j.webp",
            "gallery": "https://noctalia.dev/shell",
            "credit": "dreadwarrior2k · Noctalia gallery"
        },
        "DankMaterialShell": {
            "image": "https://github.com/user-attachments/assets/203a9678-c3b7-4720-bb97-853a511ac5c8",
            "gallery": "https://github.com/duxlabs-dev/dux-shell#readme",
            "credit": "Dux project README"
        },
        "Caelestia": {
            "image": "",
            "gallery": "https://github.com/user-attachments/assets/0840f496-575c-4ca6-83a8-87bb01a85c5f",
            "credit": "Caelestia official video"
        },
        "Illogical Impulse": {
            "image": "https://ii.clsty.link/screenshots/ii-qs.1.jpg",
            "gallery": "https://ii.clsty.link/en/",
            "credit": "illogical-impulse official documentation"
        },
        "HyDE": {
            "image": "https://raw.githubusercontent.com/prasanthrangan/hyprdots/main/Source/assets/theme_select_1.png",
            "gallery": "https://github.com/HyDE-Project/HyDE#readme",
            "credit": "HyDE README · theme selector"
        },
        "ML4W": {
            "image": "https://ml4w.com/os/screen-217.jpg",
            "gallery": "https://ml4w.com/os/",
            "credit": "ML4W official README"
        },
        "iNiR": {
            "image": "https://raw.githubusercontent.com/snowarch/iNiR/main/docs/shots/readme-hero.webp",
            "gallery": "https://github.com/snowarch/iNiR#readme",
            "credit": "iNiR README"
        },
        "DotFriedRice": {
            "image": "https://raw.githubusercontent.com/nickjj/dotfriedrice/master/_themes/tokyonight-moon/_preview.jpg",
            "gallery": "https://github.com/nickjj/dotfriedrice#readme",
            "credit": "Nick Janetakis · Tokyonight Moon"
        },
        "Ambxst": {
            "image": "https://raw.githubusercontent.com/Axenide/Ambxst/main/assets/screenshots/1.png",
            "gallery": "https://github.com/Axenide/Ambxst#readme",
            "credit": "Axenide · README"
        },
        "DarkShadow": {
            "image": "https://raw.githubusercontent.com/shadowww-dev/DarkShadowShell/main/assets/showcase.webp",
            "gallery": "https://github.com/shadowww-dev/DarkShadowShell#readme",
            "credit": "shadoww.dev · README showcase"
        },
        "Serpantinum": {
            "image": "https://raw.githubusercontent.com/ilyamiro/serpantinum/master/docs/assets/previews/preview_1.png",
            "gallery": "https://github.com/ilyamiro/serpantinum#readme",
            "credit": "Serpantinum README"
        }
    }
    property string themesView: "Originals"
    property string originalTask: ""
    function sourceDirectory(p) {
        return statePath + "/upstream/" + p.name.toLowerCase().replace(/[^a-z0-9]+/g,"-")
    }
    function fetchOriginal(p) {
        if (upstreamFetch.running) return
        const path = sourceDirectory(p)
        originalTask = p.name
        status = "Downloading original sources for " + p.name + "..."
        upstreamFetch.command = ["sh", "-c",
            "set -eu; if [ -d \"$2/.git\" ]; then printf '%s\\n' 'Already downloaded'; exit 0; fi; exec git -c core.hooksPath=/dev/null -c protocol.file.allow=never clone --depth 1 --no-tags -- \"$1\" \"$2\"",
            "deyra-source", p.url + ".git", path]
        upstreamFetch.running = true
    }
    Process {
        id: upstreamFetch
        onExited: function(code) {
            root.status = code === 0 ? root.originalTask + " sources available in the original-config folder." : "Source download failed (" + code + "). Check network and disk space."
            root.originalTask = ""
        }
    }
    property string presetScope: "All"
    property string colorScope: "All"
    property string colorRole: "accent"
    readonly property var editorStyle: styleFor(colorScope === "All" ? "" : colorScope)
    readonly property string editorColor: colorRole === "accent" ? editorStyle.accent : editorStyle.bg
    function setAppearance(scope, key, value) {
        if (key === "accent" || key === "bg") {
            value = String(value).trim().toLowerCase()
            if (!/^#[0-9a-f]{6}$/.test(value)) { status = "Enter a valid #RRGGBB color"; return }
            if (prefs.matugenEnabled) prefs.matugenEnabled = false
        } else if (key === "opacity") value = Math.max(.45, Math.min(1, Number(value)))
        else if (key === "radius") value = Math.max(0, Math.min(40, Math.round(Number(value))))
        else return
        if (scope === "All") {
            if (key === "accent") prefs.accent = value
            else if (key === "bg") prefs.background = value
            else if (key === "opacity") prefs.opacity = value
            else prefs.radius = value
        } else if (supportedScopes.indexOf(scope) >= 0) {
            const next = Object.assign({}, prefs.componentStyles || {})
            const style = Object.assign({}, styleFor(scope))
            style[key] = value
            next[scope] = style
            prefs.componentStyles = next
        } else return
        status = scope + " appearance updated"
    }
    function resetAppearance() {
        const p = presets.find(function(item) { return item.name === editorStyle.name }) || presets[0]
        setAppearance(colorScope, "accent", p.accent)
        setAppearance(colorScope, "bg", p.bg)
        setAppearance(colorScope, "opacity", p.opacity)
        setAppearance(colorScope, "radius", p.radius)
    }
    function contrastingText(bg) {
        const h = String(bg).replace("#", "")
        if (!/^[0-9a-fA-F]{6}$/.test(h)) return foreground
        const l = (0.2126 * parseInt(h.slice(0,2),16) + 0.7152 * parseInt(h.slice(2,4),16) + 0.0722 * parseInt(h.slice(4,6),16))/255
        return l > .58 ? "#131722" : "#eef2ff"
    }
    readonly property var colorSwatches: [
        "#ef4444","#dc2626","#991b1b","#fca5a5","#fb7185","#e11d48","#be185d","#f9a8d4","#f472b6","#f0abfc",
        "#f97316","#ea580c","#c2410c","#fdba74","#f59e0b","#d97706","#facc15","#fde047","#fef08a","#d9c3a5",
        "#84cc16","#65a30d","#bef264","#a3e635","#22c55e","#16a34a","#15803d","#86efac","#34d399","#10b981",
        "#14b8a6","#0d9488","#5eead4","#8bd5ca","#06b6d4","#0891b2","#67e8f9","#22d3ee","#38bdf8","#0ea5e9",
        "#3b82f6","#2563eb","#1d4ed8","#93c5fd","#8aadf4","#6366f1","#818cf8","#a5b4fc","#8b5cf6","#7c3aed",
        "#a38ff7","#c4b5fd","#a855f7","#d8b4fe","#e879f9","#c084fc","#ffb4a2","#f5c2e7","#f0b8c8","#c6a0f6",
        "#000000","#0f111e","#111827","#18181b","#1e1e2e","#24273a","#334155","#475569","#64748b","#94a3b8",
        "#a1a1aa","#cbd5e1","#d4d4d8","#e2e8f0","#f4f4f5","#ffffff","#292524","#3f3f46","#1e3a5f","#143d35"
    ]

    function originalTqq(scope) { return prefs.useOriginalPorts && styleFor(scope).name === "TQQ Rice" }
    function portPath(name) { return Quickshell.shellPath("ports/tqq/" + name + "/shell.qml") }
    property bool stoppingOriginalLauncher: false
    property bool stoppingOriginalSwitcher: false
    property bool stoppingOriginalWifi: false
    function openOriginalWifi() {
        if (originalWifi.running) { stoppingOriginalWifi = true; originalWifi.running = false; return }
        page = ""
        originalWifi.running = true
    }
    Process {
        id: originalLauncher
        command: ["env","DEYRA_PALETTE_JSON="+root.originalPanelPalette("Launcher"),"qs","-p",root.portPath("launcher")]
        onExited: function(code) { const stopped = root.stoppingOriginalLauncher; root.stoppingOriginalLauncher = false; if(!stopped && code !== 0 && prefs.useOriginalPorts) { root.status = "Original TQQ launcher failed ("+code+"); using native fallback."; root.page = "launcher" } }
    }
    Process {
        id: originalSwitcher
        command: ["env","DEYRA_PALETTE_JSON="+root.originalPanelPalette("Window Switcher"),"qs","-p",root.portPath("switcher")]
        onExited: function(code) { const stopped = root.stoppingOriginalSwitcher; root.stoppingOriginalSwitcher = false; if(!stopped && code !== 0 && prefs.useOriginalPorts) { root.status = "Original TQQ switcher failed ("+code+"); using native fallback."; root.page = "switcher" } }
    }
    Process {
        id: originalWifi
        command: ["env","DEYRA_PALETTE_JSON="+root.originalPanelPalette("Bar"),"qs","-p",root.portPath("wifi")]
        onExited: function(code) { const stopped = root.stoppingOriginalWifi; root.stoppingOriginalWifi = false; if(!stopped && code !== 0 && prefs.useOriginalPorts) { root.status = "Original TQQ Wi-Fi failed ("+code+"). Check NetworkManager."; root.page = "control" } }
    }
    function toggle(name) {
        if (name === "launcher" && originalTqq("Launcher")) {
            if (originalLauncher.running) { stoppingOriginalLauncher = true; originalLauncher.running = false; return }
            page = ""
            originalLauncher.running = true
            return
        }
        page = page === name ? "" : name
    }
    function openSettings() { if (page !== "settings") page = "settings" }
    function showSettings(section) { settingsTab = section; page = "settings" }
    function showWallpapers() { editTab = "Wallpapers"; showSettings("Edit Mode") }
    function cycleWindow() {
        if (isNiri && originalTqq("Window Switcher")) {
            if (originalSwitcher.running) Quickshell.execDetached(["qs","-p",portPath("switcher"),"ipc","call","tqq-switcher","next"])
            else { page = ""; originalSwitcher.running = true }
            return
        }
        if (windows.length === 0) return
        if (page !== "switcher") {
            selectedWindow = windows.length > 1 ? 1 : 0
            page = "switcher"
        } else selectedWindow = (selectedWindow + 1) % windows.length
    }
    function confirmWindow() {
        if (windows[selectedWindow]) windows[selectedWindow].activate()
        page = ""
    }
    function appIcon(w) {
        const app = DesktopEntries.heuristicLookup(w.appId)
        return root.safeIcon(app && app.icon ? app.icon : "application-x-executable")
    }
    function safeIcon(name) { return Quickshell.iconPath(name || "application-x-executable", true) || Quickshell.iconPath("application-x-executable", true) }
    function searchWallpapers(category) {
        if (searching) return
        const allowed = ["forest fog", "mountains", "space", "nebula", "ocean", "landscape"]
        if (allowed.indexOf(category) < 0) return
        searching = true
        onlineResults = []
        status = "Searching..."
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            searching = false
            try {
                if (xhr.status !== 200) throw Error("HTTP " + xhr.status)
                const rows = JSON.parse(xhr.responseText).data
                onlineResults = rows.filter(function(w) {
                    return w.purity === "sfw" && /^[a-z0-9]+$/.test(w.id) &&
                        /^https:\/\/w\.wallhaven\.cc\/full\//.test(w.path) &&
                        /^https:\/\/th\.wallhaven\.cc\//.test(w.thumbs.small)
                }).slice(0, 24)
                status = onlineResults.length + " results"
            } catch(e) { status = "Search unavailable: " + e.message }
        }
        xhr.open("GET", "https://wallhaven.cc/api/v1/search?categories=100&purity=100&atleast=1920x1080&sorting=toplist&q=" + encodeURIComponent(category))
        xhr.send()
    }
    function downloadWallpaper(w) {
        if (download.running || moveFile.running || !w || !/^https:\/\/w\.wallhaven\.cc\/full\//.test(w.path)) return
        const ext = /\.png$/i.test(w.path) ? ".png" : ".jpg"
        download.destination = statePath + "/wallhaven-" + w.id + ext
        download.command = ["curl", "--fail", "--silent", "--show-error", "--max-time", "60", "--max-filesize", "40000000", "--output", download.destination + ".part", w.path]
        status = "Downloading..."
        download.running = true
    }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: { const date = new Date(); if (date.getMinutes() !== root.now.getMinutes() || date.getHours() !== root.now.getHours()) root.now = date } }
    Process {
        id: niriEvents
        command: ["niri","msg","--json","event-stream"]
        running: root.isNiri
        stdout: SplitParser { onRead: function(line) { root.niriEvent(line) } }
        onExited: if (root.isNiri) niriRetry.restart()
    }
    Timer { id: niriRetry; interval: 3000; onTriggered: if (root.isNiri && !niriEvents.running) niriEvents.running = true }
    Process {
        id: hyprSnapshot
        command: ["sh","-c","hyprctl -j monitors; printf '\\n--DEYRA--\\n'; hyprctl -j workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.split("--DEYRA--")
                    const monitors = JSON.parse(parts[0]), rows = JSON.parse(parts[1])
                    root.workspaces = rows.filter(function(w) {return w.id > 0}).map(function(w) {
                        const monitor = monitors.find(function(m) {return m.name === w.monitor})
                        return {id:w.id, idx:w.id, output:w.monitor, is_active:!!monitor && monitor.activeWorkspace.id === w.id}
                    })
                } catch(e) {}
            }
        }
    }
    Timer { interval: 2000; running: root.isHyprland; repeat: true; triggeredOnStart: true; onTriggered: if (!hyprSnapshot.running) hyprSnapshot.running = true }
    Process {
        id: networkStatus
        command: ["sh","-c","if command -v nmcli >/dev/null 2>&1; then nmcli -t -f TYPE,STATE,CONNECTION device status; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                const wifi = lines.find(function(l) {return l.indexOf("wifi:connected:") === 0})
                const eth = lines.find(function(l) {return l.indexOf("ethernet:connected:") === 0})
                root.networkKind = wifi ? "wifi" : eth ? "wired" : "offline"
                root.networkLabel = wifi ? wifi.slice("wifi:connected:".length) : eth ? eth.slice("ethernet:connected:".length) : "Not connected"
            }
        }
    }
    Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!networkStatus.running) networkStatus.running = true }
    // Linux status information via fixed commands; never run commands from imported configs.
    Process {
        id: machineStats
        command: ["sh","-c","df -P / | awk 'NR==2{print $5}'; awk '/^MemTotal:/{t=$2}/^MemAvailable:/{a=$2}END{if(t>0)printf \"%d%%\\n\",100*(t-a)/t}' /proc/meminfo; cut -d' ' -f1 /proc/loadavg; for b in /sys/class/power_supply/BAT*/capacity; do if [ -r \"$b\" ]; then cat \"$b\"; break; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.trim().split("\n")
                root.diskText = rows[0] || ""
                root.memoryText = rows[1] || ""
                root.loadText = rows[2] || ""
                root.batteryText = /^\d+$/.test(rows[3] || "") ? rows[3] + "%" : ""
            }
        }
    }
    Timer { interval: 12000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if(!machineStats.running) machineStats.running = true }
    Process {
        id: mediaInfo
        command: ["sh","-c","if command -v playerctl >/dev/null 2>&1; then playerctl metadata --format '{{title}}' 2>/dev/null; fi"]
        stdout: StdioCollector { onStreamFinished: root.mediaText = text.trim().slice(0,80) }
    }
    Timer { interval: 3500; running: root.effectiveBarLayout.left.concat(root.effectiveBarLayout.center,root.effectiveBarLayout.right).indexOf("media") >= 0; repeat: true; triggeredOnStart: true; onTriggered: if(!mediaInfo.running) mediaInfo.running = true }
    Process {
        id: brightnessInfo
        command: ["sh","-c","if command -v brightnessctl >/dev/null 2>&1; then brightnessctl -m 2>/dev/null | cut -d, -f4 | head -n1; fi"]
        stdout: StdioCollector { onStreamFinished: root.brightnessText = text.trim() }
    }
    Timer { interval: 8000; running: root.effectiveBarLayout.left.concat(root.effectiveBarLayout.center,root.effectiveBarLayout.right).indexOf("brightness") >= 0; repeat: true; triggeredOnStart: true; onTriggered: if(!brightnessInfo.running) brightnessInfo.running = true }
    property string matugenStatus: "Choose a wallpaper to generate a palette."
    property string requestedWallpaper: ""
    function queueMatugen() {
        if (!prefs.matugenEnabled) { matugenStatus = "Manual colors active"; return }
        if (!prefs.wallpaper) { matugenStatus = "Choose a wallpaper first"; return }
        matugenDebounce.restart()
    }
    function generateMatugen() {
        if (!prefs.matugenEnabled || !prefs.wallpaper || matugenProcess.running) return
        const url = prefs.wallpaper
        let path = url
        try { if (url.indexOf("file://") === 0) path = decodeURIComponent(url.slice(7)) } catch(e) { matugenStatus = "Invalid wallpaper path"; return }
        if (!path.startsWith("/")) { matugenStatus = "Matugen requires a local wallpaper"; return }
        requestedWallpaper = url
        matugenStatus = "Generating wallpaper colors…"
        matugenProcess.command = ["matugen","-c",Quickshell.shellPath("matugen/config.toml"),"image",path,"-m","dark","--dry-run","--json","hex"]
        matugenProcess.running = true
    }
    // Supports both mode-first JSON and role-first Matugen output.
    function parseMatugen(raw) {
        const json = JSON.parse(raw)
        const colors = json.colors || json
        const roles = ["primary","secondary","tertiary","background","surface","surface_container","surface_container_high","surface_variant","on_surface","on_surface_variant","on_primary","outline","outline_variant"]
        const result = {}
        function hex(value) {
            if (value && typeof value === "object") value = value.color || value.hex
            return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value) ? value : ""
        }
        for (const role of roles) {
            const old = colors.dark && colors.dark[role]
            const current = colors[role]
            const value = hex(old) || hex(current && (current.dark || current.default)) || hex(current)
            if (value) result[role] = value
        }
        if (!result.primary || !result.background || !result.on_surface) throw Error("Missing required palette roles")
        return result
    }
    Connections {
        target: prefs
        function onWallpaperChanged() { root.queueMatugen() }
        function onMatugenEnabledChanged() { root.queueMatugen() }
    }
    Timer { id: matugenDebounce; interval: 350; onTriggered: root.generateMatugen() }
    Timer { interval: 1000; running: true; repeat: false; onTriggered: root.queueMatugen() }
    Process {
        id: matugenProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (!prefs.matugenEnabled || root.requestedWallpaper !== prefs.wallpaper) return
                if (!text.trim()) return
                try {
                    prefs.matugenPalette = root.parseMatugen(text)
                    root.matugenStatus = "Wallpaper palette applied"
                } catch(e) { root.matugenStatus = "Matugen returned an unsupported palette; previous colors retained." }
            }
        }
        onExited: function(code) {
            if (prefs.matugenEnabled && root.requestedWallpaper !== prefs.wallpaper) root.queueMatugen()
            else if (code !== 0 && prefs.matugenEnabled) root.matugenStatus = "Matugen failed. Check that matugen is installed and the wallpaper exists."
        }
    }
    function originalPanelPalette(scope) {
        const style = styleFor(scope)
        const background = style.bg
        return JSON.stringify({
            background:background, surface:paletteColor("surface_container",String(Qt.tint(background,Qt.rgba(1,1,1,.08)))),
            surface_variant:paletteColor("surface_container_high",String(Qt.tint(background,Qt.rgba(1,1,1,.16)))),
            foreground:paletteColor("on_surface",contrastingText(background)), muted:paletteColor("on_surface_variant","#aaa0ad"),
            primary:style.accent, on_primary:paletteColor("on_primary",contrastingText(style.accent))
        })
    }
    FileView {
        id: configFile
        path: root.statePath + "/settings.json"
        printErrors: false
        watchChanges: false
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: prefs
            property string accent: "#a38ff7"
            property string background: "#0f111e"
            property string activePreset: "TQQ Rice"
            property var componentStyles: ({})
            property real opacity: 0.91
            property int radius: 17
            property int barHeight: 42
            property int barSpacing: 6
            property int barInset: 12
            property var customBarLayout: ({})
            property string workspaceFace: "source"
            property bool clock12h: false
            property bool barFrame: false
            property bool switcherCompact: false
            property int switcherDuration: 200
            property bool switcherAnimated: true
            property string switcherAlign: "center"
            property bool barBottom: false
            property bool desktopClock: false
            property string desktopClockStyle: "source"
            property bool useOriginalPorts: true
            property bool reduceMotion: false
            property bool showAudio: true
            property bool showNotifications: true
            property string wallpaper: ""
            property bool matugenEnabled: true
            property var matugenPalette: ({})
            property string avatar: ""
        }
    }
    Process {
        id: download
        property string destination: ""
        onExited: function(code) {
            if (code === 0) {
                moveFile.command = ["mv", "--", destination + ".part", destination]
                moveFile.running = true
            } else {
                root.status = "Download failed (" + code + ")"
                Quickshell.execDetached(["rm", "-f", "--", destination + ".part"])
            }
        }
    }
    Process {
        id: moveFile
        onExited: function(code) {
            if (code === 0) { prefs.wallpaper = "file://" + download.destination; root.status = "Wallpaper applied" }
            else root.status = "Could not save wallpaper"
        }
    }
    Process {
        running: true
        command: ["sh", "-c", "uname -srmo; uptime -p; grep -m1 'model name' /proc/cpuinfo; grep MemTotal /proc/meminfo"]
        stdout: StdioCollector { onStreamFinished: root.systemInfo = text }
    }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    NotificationServer {
        id: notifications
        bodySupported: true
        bodyMarkupSupported: false
        onNotification: function(notification) {
            notification.tracked = true
            if (!root.dnd) { root.toastTitle = notification.summary; root.toastBody = notification.body; root.currentToast = notification; toastTimer.restart() }
        }
    }
    Timer { id: toastTimer; interval: 4500; onTriggered: root.currentToast = null }

    IpcHandler {
        target: "deyra"
        function launcher(): void { root.toggle("launcher") }
        function control(): void { root.toggle("control") }
        function settings(): void { root.openSettings() }
        function wallpapers(): void { if(root.page === "settings" && root.editTab === "Wallpapers") root.page = ""; else root.showWallpapers() }
        function notifications(): void { root.toggle("notifications") }
        function switcher(): void { root.cycleWindow() }
        function confirm(): void { root.confirmWindow() }
        function close(): void { root.page = ""; if(originalLauncher.running) { root.stoppingOriginalLauncher = true; originalLauncher.running = false } if(originalSwitcher.running) { root.stoppingOriginalSwitcher = true; originalSwitcher.running = false } if(originalWifi.running) { root.stoppingOriginalWifi = true; originalWifi.running = false } }
    }

    // Shared visual primitives. Only event-driven animations, no continuous shaders.
    // Preview renderer uses the same layout table and source module ordering as the shell.
    // Sample content is intentional: previews do not expose the user's windows or notifications.
    function previewLayout(name, scope) {
        const index = ["Bar","Launcher","Dock","Control Center","Window Switcher"].indexOf(scope)
        const variants = layoutProfiles[name] || layoutProfiles["TQQ Rice"]
        return scope === "All" ? "Desktop" : scope === "Notifications" ? "Notification style" : index >= 0 ? variants[index] : "Style"
    }
    // Original screenshots are remote references, never invented renderings.
    component PresetPreview: Item {
        id: upstreamPreview
        property var profile
        property string previewScope: "All"
        readonly property var media: profile ? root.upstreamMedia[profile.name] : null
        Image {
            id: shot
            anchors.fill: parent
            source: upstreamPreview.media ? upstreamPreview.media.image : ""
            asynchronous: true
            cache: true
            sourceSize.width: 700
            fillMode: Image.PreserveAspectFit
        }
        Column {
            anchors.centerIn: parent
            width: parent.width-20; spacing: 7
            visible: shot.status !== Image.Ready
            Caption {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: shot.status === Image.Loading ? "Loading original preview…" : "Original screenshot unavailable"
            }
            Pill {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !!upstreamPreview.media && shot.status !== Image.Loading
                text: "Open official showcase"
                onClicked: Qt.openUrlExternally(upstreamPreview.media.gallery)
            }
        }
    }
    component Caption: Text {
        property string deyraTextScope: ""
        color: deyraTextScope === "" ? root.foreground : root.contrastingText(root.styleFor(deyraTextScope).bg)
        font.family: "sans-serif"
        font.pixelSize: 13
        textFormat: Text.PlainText
    }
    component Muted: Caption { color: root.uiMuted; font.pixelSize: 12 }
    component Pill: Button {
        id: button
        property bool deyraSelected: false
        property string styleScope: ""
        property bool deyraFlat: false
        readonly property var deyraStyle: root.styleFor(styleScope)
        readonly property color baseTone: styleScope === "" ? root.uiRaised : Qt.alpha(deyraStyle.bg, deyraStyle.opacity)
        implicitHeight: 36
        implicitWidth: Math.max(38, contentItem.implicitWidth + 24)
        padding: 10
        opacity: enabled ? 1 : 0.45
        scale: down && !prefs.reduceMotion ? .96 : 1
        Behavior on scale { NumberAnimation { duration: root.motion / 2; easing.type: Easing.OutCubic } }
        contentItem: Caption {
            text: button.text
            font.weight: Font.Medium
            color: button.deyraSelected ? root.contrastingText(button.deyraStyle.accent) : button.styleScope === "" ? root.foreground : root.contrastingText(button.deyraStyle.bg)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: button.styleScope === "" ? 10 : Math.min(button.deyraStyle.radius, 18)
            color: button.deyraSelected ? button.deyraStyle.accent : button.hovered || button.down ? root.tint(button.baseTone, .12) : button.deyraFlat ? "transparent" : button.baseTone
            border.color: button.activeFocus ? root.accent : "transparent"
            border.width: button.activeFocus ? 1 : 0
            Behavior on color { ColorAnimation { duration: root.motion / 2 } }
        }
    }
    component NavButton: Button {
        id: nav
        property string glyph: ""
        property bool navSelected: false
        implicitHeight: 42
        padding: 12
        contentItem: RowLayout {
            spacing: 12
            Caption { text: nav.glyph; font.pixelSize: 17; color: nav.navSelected ? root.accent : root.uiMuted; Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter }
            Caption { text: nav.text; font.weight: nav.navSelected ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; color: nav.navSelected ? root.foreground : "#b5b7c2" }
        }
        background: Rectangle {
            radius: 9
            color: nav.navSelected ? Qt.tint(root.uiRaised, Qt.alpha(root.accent,.10)) : nav.hovered ? root.uiRaised : "transparent"
            Behavior on color { ColorAnimation { duration: root.motion / 2 } }
            Rectangle { width: 3; height: 20; radius: 2; anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                color: root.accent; opacity: nav.navSelected ? 1 : 0; Behavior on opacity { NumberAnimation { duration: root.motion } } }
        }
    }
    component DeyraInput: TextField {
        id: field
        implicitHeight: 38
        padding: 10
        color: root.foreground
        placeholderTextColor: root.uiMuted
        selectionColor: root.accent
        selectedTextColor: root.contrastingText(root.accent)
        font.family: "sans-serif"
        font.pixelSize: 13
        background: Rectangle {
            radius: 9; color: root.uiBase
            border.color: field.activeFocus ? root.accent : root.uiLine; border.width: 1
            Behavior on border.color { ColorAnimation { duration: root.motion / 2 } }
        }
    }
    component DeyraCombo: ComboBox {
        id: chooser
        implicitHeight: 38
        leftPadding: 12; rightPadding: 30
        contentItem: Caption { text: chooser.displayText; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        indicator: Caption { text: "⌄"; font.pixelSize: 16; color: root.uiMuted; x: chooser.width - width - 12; y: (chooser.height-height)/2 }
        background: Rectangle { radius: 9; color: chooser.hovered ? root.uiRaised : root.uiPanel; border.color: chooser.activeFocus ? root.accent : root.uiLine }
        delegate: ItemDelegate {
            required property var modelData
            required property int index
            width: chooser.width
            height: 36
            highlighted: chooser.highlightedIndex === index
            contentItem: Caption { text: String(modelData); verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.highlighted || parent.hovered ? root.uiRaised : "transparent"; radius: 7 }
        }
        popup: Popup {
            popupType: Popup.Item
            y: chooser.height + 4; width: chooser.width
            implicitHeight: Math.min(contentItem.implicitHeight+12, 300)
            padding: 6
            contentItem: ListView { clip: true; implicitHeight: contentHeight; model: chooser.popup.visible ? chooser.delegateModel : null; currentIndex: chooser.highlightedIndex }
            background: Rectangle { color: root.uiPanel; radius: 10; border.color: root.uiLine }
        }
    }
    component DeyraSlider: Slider {
        id: range
        implicitHeight: 30
        background: Rectangle {
            x: range.leftPadding; y: range.topPadding + (range.availableHeight-height)/2
            width: range.availableWidth; height: 5; radius: 3; color: root.uiLine
            Rectangle { width: range.visualPosition * parent.width; height: parent.height; radius: 3; color: root.accent }
        }
        handle: Rectangle {
            x: range.leftPadding + range.visualPosition * (range.availableWidth-width)
            y: range.topPadding + (range.availableHeight-height)/2
            width: 16; height: 16; radius: 8; color: root.accent
            scale: range.pressed ? 1.2 : 1
            Behavior on scale { NumberAnimation { duration: root.motion / 2 } }
        }
    }
    component DeyraCheck: CheckBox {
        id: toggleControl
        implicitHeight: 36
        implicitWidth: Math.max(220, contentItem.implicitWidth + 54)
        spacing: 12
        leftPadding: 0
        rightPadding: 0
        indicator: Rectangle {
            x: toggleControl.width-width; y: (toggleControl.height-height)/2
            width: 40; height: 22; radius: 11
            color: toggleControl.checked ? root.accent : root.uiLine
            Behavior on color { ColorAnimation { duration: root.motion } }
            Rectangle {
                width: 16; height: 16; radius: 8; y: 3
                x: toggleControl.checked ? 21 : 3
                color: toggleControl.checked ? root.contrastingText(root.accent) : root.uiMuted
                Behavior on x { NumberAnimation { duration: root.motion; easing.type: Easing.OutCubic } }
            }
        }
        contentItem: Caption { text: toggleControl.text; rightPadding: 52; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
    }
    component Section: ColumnLayout { spacing: 14 }
    // Vector icons painted only on icon/color changes; no extra icon font dependency.
    component ShellIcon: Canvas {
        id: symbol
        property string glyph: "search"
        property color ink: root.foreground
        implicitWidth: 18; implicitHeight: 18
        onGlyphChanged: requestPaint()
        onInkChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset(); c.clearRect(0,0,width,height); c.save(); c.scale(width/24,height/24)
            c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = 1.8; c.lineCap = "round"; c.lineJoin = "round"
            function path(points) { c.beginPath(); c.moveTo(points[0],points[1]); for(let i=2;i<points.length;i+=2)c.lineTo(points[i],points[i+1]); c.stroke() }
            function circle(x,y,r) { c.beginPath(); c.arc(x,y,r,0,2*Math.PI); c.stroke() }
            switch(glyph) {
            case "search": circle(10,10,5.5); path([14,14,20,20]); break
            case "settings":
                circle(12,12,3.4); circle(12,12,7.2)
                for(let i=0;i<8;i++) {const a=i*Math.PI/4; path([12+7.5*Math.cos(a),12+7.5*Math.sin(a),12+10*Math.cos(a),12+10*Math.sin(a)])} break
            case "bell": path([5,17,7,14,7,9,9,5,15,5,17,9,17,14,19,17,5,17]); path([10,20,14,20]); break
            case "audio": path([4,9,8,9,13,5,13,19,8,15,4,15,4,9]); c.beginPath();c.arc(12,12,5,-.8,.8);c.stroke();c.beginPath();c.arc(12,12,8,-.8,.8);c.stroke();break
            case "wifi": for(let r=5;r<=11;r+=3){c.beginPath();c.arc(12,17,r,-2.38,-.76);c.stroke()} c.beginPath();c.arc(12,18,1.2,0,2*Math.PI);c.fill();break
            case "wired": c.strokeRect(5,5,14,10);path([12,15,12,20,7,20]);break
            case "offline": circle(12,12,8);path([6,6,18,18]);break
            case "battery": c.strokeRect(3,7,16,10);path([21,10,21,14]);c.fillRect(5,9,10,6);break
            case "disk": c.strokeRect(4,5,16,14);path([4,14,20,14]);circle(16,17,0.7);break
            case "cpu": c.strokeRect(7,7,10,10);for(let i=8;i<=16;i+=4){path([i,3,i,7]);path([i,17,i,21]);path([3,i,7,i]);path([17,i,21,i])}break
            case "memory": c.strokeRect(3,7,18,10);for(let i=6;i<=18;i+=4){path([i,10,i,14]);path([i,17,i,20])}break
            case "media": path([9,17,9,5,19,3,19,15]);circle(6,17,3);circle(16,15,3);break
            case "brightness": circle(12,12,4);for(let i=0;i<8;i++){const a=i*Math.PI/4;path([12+7*Math.cos(a),12+7*Math.sin(a),12+10*Math.cos(a),12+10*Math.sin(a)])}break
            case "wallpaper": c.strokeRect(3,4,18,16);path([4,17,10,10,14,14,17,11,20,14]);circle(16,8,1);break
            case "control": path([4,6,20,6]);path([4,12,20,12]);path([4,18,20,18]);circle(9,6,2);circle(15,12,2);circle(10,18,2);break
            case "clock": circle(12,12,9);path([12,6,12,12,16,14]);break
            default: c.strokeRect(5,5,14,14);break
            }
            c.restore()
        }
    }
    component BarIconButton: Button {
        id: iconButton
        property string glyph: "search"
        property string label: ""
        property string detail: ""
        implicitWidth: iconRow.implicitWidth + (prefs.barHeight < 32 ? 12 : 20)
        implicitHeight: Math.min(32, Math.max(20,prefs.barHeight-4))
        padding: prefs.barHeight < 32 ? 4 : 10
        contentItem: Row {
            id: iconRow
            spacing: 6
            ShellIcon { glyph: iconButton.glyph; width: 17; height: 17; anchors.verticalCenter: parent.verticalCenter; ink: root.contrastingText(root.styleFor("Bar").bg) }
            Caption { visible: iconButton.label !== ""; text: iconButton.label; deyraTextScope: "Bar"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; font.weight: Font.Medium }
        }
        background: Rectangle {
            color: iconButton.hovered ? root.tint(root.styleFor("Bar").bg,.14) : root.layoutFor("Bar") === "islands" ? Qt.alpha(root.styleFor("Bar").bg,root.styleFor("Bar").opacity) : "transparent"
            radius: Math.min(root.styleFor("Bar").radius,16)
            Behavior on color { ColorAnimation { duration: root.motion/2 } }
        }
        ToolTip.visible: hovered && detail !== ""
        ToolTip.text: detail
    }
    component AppGlyph: Item {
        id: appGlyph
        property url imageSource: ""
        property string fallbackText: "?"
        implicitWidth: 32; implicitHeight: 32
        Rectangle {
            anchors.fill: parent
            visible: image.status !== Image.Ready
            radius: 8; color: root.uiRaised
            Caption { anchors.centerIn: parent; text: appGlyph.fallbackText.trim().slice(0,1).toUpperCase() || "?"; font.pixelSize: 17; font.weight: Font.DemiBold; color: root.accent }
        }
        Image { id: image; anchors.fill: parent; source: appGlyph.imageSource; fillMode: Image.PreserveAspectFit; asynchronous: true; sourceSize.width: Math.max(1,width); sourceSize.height: Math.max(1,height) }
    }
    component BarPill: Pill {
        styleScope: "Bar"; deyraFlat: root.layoutFor("Bar") !== "islands"
        implicitHeight: 32
    }
    component Card: Rectangle {
        property string styleScope: ""
        readonly property var deyraStyle: root.styleFor(styleScope)
        color: styleScope === "" ? root.uiPanel : Qt.alpha(deyraStyle.bg, deyraStyle.opacity)
        radius: styleScope === "" ? 14 : deyraStyle.radius
        border.color: styleScope === "" ? root.uiLine : Qt.tint(deyraStyle.bg, Qt.alpha(deyraStyle.accent,.19))
        border.width: 1
        Behavior on color { ColorAnimation { duration: root.motion } }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore
            color: "#141727"
            Image { anchors.fill: parent; source: prefs.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; sourceSize.width: parent.width }
            Column {
                visible: prefs.desktopClock && !root.useDuxDesktopClock
                anchors { left: parent.left; top: parent.top; margins: 70 }
                Caption { text: Qt.formatTime(root.now, "hh:mm"); font.pixelSize: 68 }
                Caption { text: Qt.formatDate(root.now, "dddd, MMMM d"); font.pixelSize: 22 }
            }
            Loader {
                anchors { left: parent.left; top: parent.top; margins: 70 }
                width: 240; height: 240
                active: prefs.desktopClock && root.useDuxDesktopClock
                sourceComponent: Component {
                    Dux.DesktopClock {
                        pluginData: ({showSeconds:false, showDate:true, clockStyle:"analog", backgroundOpacity:80})
                        accent: root.accent
                        surface: root.paletteColor("background",prefs.background)
                        foreground: root.contrastingText(root.paletteColor("background",prefs.background))
                        corner: prefs.radius
                    }
                }
            }
        }
    }
    // Registry-driven native widgets. Upstream data determines placement, not a hardcoded row.
    component BarModule: Item {
        id: module
        property string moduleKey: ""
        property string outputName: ""
        readonly property bool available: moduleKey === "volume" ? prefs.showAudio : moduleKey === "notifications" ? prefs.showNotifications : moduleKey === "battery" ? root.batteryText !== "" : moduleKey === "media" ? root.mediaText !== "" : moduleKey === "brightness" ? root.brightnessText !== "" : moduleKey === "title" ? root.activeTitle() !== "" : true
        implicitWidth: available && moduleLoader.item ? (moduleKey === "title" ? Math.min(146,titleMetrics.advanceWidth(root.activeTitle())) : moduleLoader.item.implicitWidth) : 0
        FontMetrics { id: titleMetrics; font.family: "sans-serif"; font.pixelSize: 13 }
        implicitHeight: Math.min(32, Math.max(20,prefs.barHeight-4))
        width: implicitWidth; height: implicitHeight
        visible: available && width > 0
        Loader {
            id: moduleLoader
            anchors.fill: parent
            active: module.available
            sourceComponent: module.moduleKey === "workspaces" ? workspaceModule : module.moduleKey === "title" ? titleModule : module.moduleKey === "clock" ? clockModule : statusModule
        }
        Component {
            id: titleModule
            Caption {
                deyraTextScope: "Bar"
                text: root.activeTitle()
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
        Component {
            id: clockModule
            BarPill {
                implicitHeight: module.implicitHeight
                text: Qt.formatDateTime(root.now, prefs.clock12h ? "h:mm AP  ·  d MMM" : "hh:mm  ·  d MMM")
                onClicked: root.toggle("control")
            }
        }
        Component {
            id: workspaceModule
            Item {
                implicitWidth: workRow.implicitWidth > 0 ? workRow.implicitWidth+12 : 0
                implicitHeight: module.implicitHeight
                Rectangle {
                    anchors.fill: parent
                    color: root.layoutFor("Bar")==="islands" ? Qt.alpha(root.styleFor("Bar").bg,root.styleFor("Bar").opacity) : "transparent"
                    radius: Math.min(16,root.styleFor("Bar").radius)
                }
                Row {
                    id: workRow
                    anchors.centerIn: parent; spacing: root.workspaceFace === "trace" ? 2 : 5
                    Repeater {
                        model: root.workspacesFor(module.outputName)
                        delegate: Rectangle {
                            id: wsDot
                            required property var modelData
                            readonly property bool active: modelData.is_active
                            readonly property string face: root.workspaceFace
                            width: face === "numbers" ? 19 : face === "dots" ? 9 : face === "trace" ? 13 : active ? 26 : 9
                            height: face === "numbers" ? 19 : face === "morph" ? (active ? 15 : 9) : 9
                            anchors.verticalCenter: parent.verticalCenter
                            radius: face === "morph" && active ? 4 : height/2
                            color: active ? root.styleFor("Bar").accent : root.tint(root.styleFor("Bar").bg,.28)
                            Behavior on width { NumberAnimation { duration: root.motion; easing.type: Easing.OutCubic } }
                            Behavior on height { NumberAnimation { duration: root.motion; easing.type: Easing.OutCubic } }
                            Behavior on radius { NumberAnimation { duration: root.motion } }
                            Behavior on color { ColorAnimation { duration: root.motion } }
                            Caption { anchors.centerIn: parent; visible: wsDot.face === "numbers"; text: String(wsDot.modelData.idx); font.pixelSize: 10; color: wsDot.active ? root.contrastingText(root.styleFor("Bar").accent) : root.contrastingText(root.styleFor("Bar").bg) }
                            MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: root.activateWorkspace(wsDot.modelData) }
                        }
                    }
                }
            }
        }
        Component {
            id: statusModule
            BarIconButton {
                implicitHeight: module.implicitHeight
                glyph: ({launcher:"search",volume:"audio",network:root.networkKind,notifications:"bell",settings:"settings",control:"control",wallpaper:"wallpaper",battery:"battery",disk:"disk",cpu:"cpu",memory:"memory",media:"media",brightness:"brightness"})[module.moduleKey] || "settings"
                detail: module.moduleKey === "network" ? root.networkLabel : module.moduleKey === "media" ? root.mediaText : root.moduleTitle(module.moduleKey)
                label: {
                    switch(module.moduleKey) {
                        case "volume": return Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume*100)+"%" : ""
                        case "notifications": return notifications.trackedNotifications.values.length ? String(notifications.trackedNotifications.values.length) : ""
                        case "battery": return root.batteryText
                        case "disk": return root.diskText
                        case "memory": return root.memoryText
                        case "cpu": return root.loadText
                        case "media": return root.mediaText.length>17 ? root.mediaText.slice(0,16)+"…" : root.mediaText
                        case "brightness": return root.brightnessText
                        default: return ""
                    }
                }
                onClicked: {
                    switch(module.moduleKey) {
                        case "launcher": root.toggle("launcher"); break
                        case "settings": root.toggle("settings"); break
                        case "wallpaper": root.showWallpapers(); break
                        case "notifications": root.toggle("notifications"); break
                        case "network": if(root.originalTqq("Bar")) root.openOriginalWifi(); else root.toggle("control"); break
                        case "media": Quickshell.execDetached(["playerctl","play-pause"]); break
                        case "disk": case "memory": case "cpu": case "battery": root.showSettings("Profile"); break
                        default: root.toggle("control")
                    }
                }
            }
        }
    }
    component BarSection: Row {
        id: section
        property var modules: []
        property string outputName: ""
        spacing: prefs.barSpacing
        Repeater {
            model: section.modules
            delegate: BarModule {
                required property string modelData
                moduleKey: modelData
                outputName: section.outputName
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: barWindow
            required property var modelData
            readonly property string mode: root.layoutFor("Bar")
            screen: modelData
            anchors { top: !prefs.barBottom; bottom: prefs.barBottom; left: true; right: true }
            implicitHeight: prefs.barHeight
            color: "transparent"
            Item {
                id: barArea
                anchors.fill: parent
                anchors.leftMargin: Math.min(prefs.barInset,Math.max(0,(barWindow.width-950)/2+12))
                anchors.rightMargin: anchors.leftMargin
                readonly property string output: barWindow.screen ? barWindow.screen.name : ""
                Card {
                    styleScope: "Bar"
                    visible: barWindow.mode === "full" || barWindow.mode === "minimal" || prefs.barFrame
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    radius: barWindow.mode==="minimal" ? 3 : root.styleFor("Bar").radius
                    border.width: prefs.barFrame ? Math.min(6,prefs.barHeight/5) : 1
                }
                Card {
                    styleScope: "Bar"
                    visible: barWindow.mode === "groups"
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: leftBar.implicitWidth+10; height: Math.min(36,prefs.barHeight)
                }
                Card {
                    styleScope: "Bar"
                    visible: barWindow.mode === "groups"
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: rightBar.implicitWidth+10; height: Math.min(36,prefs.barHeight)
                }
                Card {
                    styleScope: "Bar"
                    visible: ["notch","dynamic","groups"].indexOf(barWindow.mode)>=0
                    anchors.centerIn: parent
                    width: centerBar.implicitWidth + (barWindow.mode==="dynamic" && centerHover.hovered ? 36 : 14)
                    height: Math.min(36,prefs.barHeight)
                    radius: barWindow.mode==="notch" ? 10 : 20
                    Behavior on width { NumberAnimation { duration: root.motion; easing.type: Easing.OutCubic } }
                }
                Item {
                    anchors { left: parent.left; right: centerBar.left; verticalCenter: parent.verticalCenter; rightMargin: 5 }
                    height: prefs.barHeight
                    clip: true
                    BarSection { id: leftBar; anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter } modules: root.effectiveBarLayout.left; outputName: barArea.output }
                }
                BarSection {
                    id: centerBar
                    anchors.centerIn: parent
                    modules: root.effectiveBarLayout.center
                    outputName: barArea.output
                    HoverHandler { id: centerHover }
                }
                Item {
                    anchors { left: centerBar.right; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 5 }
                    height: prefs.barHeight
                    clip: true
                    BarSection { id: rightBar; anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter } modules: root.effectiveBarLayout.right; outputName: barArea.output }
                }
            }
        }
    }
    PanelWindow {
        id: launcher
        readonly property string mode: root.layoutFor("Launcher")
        readonly property bool grid: mode.indexOf("grid") === 0
        readonly property var matches: Array.from(DesktopEntries.applications.values).filter(function(a) {
            return !a.noDisplay && (a.name + " " + (a.genericName || "")).toLowerCase().indexOf(query.text.toLowerCase()) >= 0
        }).sort(function(a,b) { return a.name.localeCompare(b.name) })
        readonly property bool expanded: root.page === "launcher"
        property real reveal: expanded ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: root.motion; easing.type: Easing.OutCubic } }
        visible: expanded || reveal > .001
        anchors { top: mode === "list-left" && !prefs.barBottom; bottom: mode === "list-left" && prefs.barBottom; left: mode === "list-left" }
        margins { top: prefs.barHeight + 8; bottom: prefs.barHeight + 8; left: 12 }
        implicitWidth: Math.min(mode === "grid-wide" ? 760 : grid ? 600 : 440, screen ? screen.width - 24 : 760)
        implicitHeight: grid ? 510 : 460
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) { query.text = ""; query.forceActiveFocus() }
        function launch(app) { if (app) { app.execute(); root.page = "" } }
        Card {
            styleScope: "Launcher"
            anchors.fill: parent
            opacity: launcher.reveal
            scale: .95 + .05 * launcher.reveal
            enabled: launcher.expanded
            transformOrigin: Item.TopLeft
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16
                RowLayout {
                    Caption { deyraTextScope: "Launcher"; text: launcher.grid ? "Applications" : "Launcher"; font.pixelSize: 20; Layout.fillWidth: true }
                    Pill { styleScope: "Launcher"; text: "×"; onClicked: root.page = "" }
                }
                DeyraInput { id: query; Layout.fillWidth: true; placeholderText: "Search applications"; Keys.onEscapePressed: root.page = ""; onAccepted: launcher.launch(launcher.matches[0]) }
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    sourceComponent: launcher.grid ? gridApps : listApps
                }
                Caption { deyraTextScope: "Launcher"; text: launcher.matches.length + " apps"; opacity: .7 }
            }
        }
        Component {
            id: listApps
            ListView {
                clip: true; spacing: 5; model: launcher.matches
                delegate: Button {
                    required property var modelData
                    width: ListView.view.width; height: 44
                    onClicked: launcher.launch(modelData)
                    background: Rectangle { radius: root.styleFor("Launcher").radius; color: parent.hovered ? Qt.lighter(root.styleFor("Launcher").bg,1.5) : "transparent" }
                    contentItem: RowLayout {
                        AppGlyph { imageSource: root.safeIcon(modelData.icon); fallbackText: modelData.name; Layout.preferredWidth: 28; Layout.preferredHeight: 28 }
                        Caption { deyraTextScope: "Launcher"; text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                }
            }
        }
        Component {
            id: gridApps
            GridView {
                id: appGrid
                clip: true; model: launcher.matches
                cellWidth: width / Math.max(1, Math.floor(width/110)); cellHeight: 102
                delegate: Button {
                    required property var modelData
                    width: appGrid.cellWidth - 6; height: 96
                    onClicked: launcher.launch(modelData)
                    background: Rectangle { radius: root.styleFor("Launcher").radius; color: parent.hovered ? Qt.lighter(root.styleFor("Launcher").bg,1.6) : Qt.lighter(root.styleFor("Launcher").bg,1.2) }
                    contentItem: ColumnLayout {
                        AppGlyph { imageSource: root.safeIcon(modelData.icon); fallbackText: modelData.name; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 40; Layout.preferredHeight: 40 }
                        Caption { deyraTextScope: "Launcher"; text: modelData.name; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.pixelSize: 11 }
                    }
                }
            }
        }
    }
    PanelWindow {
        id: controlWindow
        readonly property string mode: root.layoutFor("Control Center")
        readonly property bool expanded: root.page === "control"
        property real reveal: expanded ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: root.motion; easing.type: Easing.OutCubic } }
        visible: expanded || reveal > .001
        anchors { top: !prefs.barBottom; bottom: prefs.barBottom }
        margins { top: prefs.barHeight + 8; bottom: prefs.barHeight + 8 }
        implicitWidth: Math.min(controlWindow.mode === "compact" ? 420 : 620, screen ? screen.width - 24 : 620)
        implicitHeight: controlWindow.mode === "tiles" ? 400 : controlWindow.mode === "compact" ? 285 : 320
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        Card {
            styleScope: "Control Center"
            anchors.fill: parent
            opacity: controlWindow.reveal
            scale: .95 + .05 * controlWindow.reveal
            enabled: controlWindow.expanded
            transformOrigin: Item.Top
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                RowLayout {
                    Caption { deyraTextScope: "Control Center"; text: Qt.formatTime(root.now, "hh:mm"); font.pixelSize: 42; Layout.fillWidth: true }
                    Pill { styleScope: "Control Center"; text: "Settings"; onClicked: root.showSettings("System") }
                    Pill { styleScope: "Control Center"; text: "×"; onClicked: root.page = "" }
                }
                Caption { deyraTextScope: "Control Center"; text: Qt.formatDate(root.now, "dddd, d MMMM yyyy") }
                RowLayout { Layout.fillWidth: true; Caption { deyraTextScope: "Control Center"; text: "Volume"; Layout.fillWidth: true } Caption { deyraTextScope: "Control Center"; text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume*100) + "%" : "Unavailable" } }
                Loader {
                    Layout.fillWidth: true; Layout.preferredHeight: 30
                    sourceComponent: prefs.useOriginalPorts && root.styleFor("Control Center").name === "DarkShadow" ? shadowVolume : standardVolume
                }
                Component {
                    id: shadowVolume
                    Shadow.WavyLine {
                        color: root.styleFor("Control Center").accent
                        value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0
                        seekable: !!Pipewire.defaultAudioSink && !!Pipewire.defaultAudioSink.audio
                        moving: false
                        reducedMotion: prefs.reduceMotion
                        onMoved: function(v) { if(seekable) Pipewire.defaultAudioSink.audio.volume = v }
                    }
                }
                Component {
                    id: standardVolume
                    DeyraSlider {
                        from: 0; to: 1
                        enabled: !!Pipewire.defaultAudioSink && !!Pipewire.defaultAudioSink.audio
                        value: enabled ? Pipewire.defaultAudioSink.audio.volume : 0
                        onMoved: if (enabled) Pipewire.defaultAudioSink.audio.volume = value
                    }
                }
                GridLayout {
                    columns: controlWindow.mode === "tiles" ? 2 : 3
                    Layout.fillWidth: true
                    Pill { styleScope: "Control Center"; text: root.dnd ? "DND on" : "DND off"; onClicked: root.dnd = !root.dnd }
                    Pill { styleScope: "Control Center"; text: "Brightness −"; onClicked: Quickshell.execDetached(["brightnessctl", "set", "5%-"]) }
                    Pill { styleScope: "Control Center"; text: "Brightness +"; onClicked: Quickshell.execDetached(["brightnessctl", "set", "+5%"]) }
                }
                GridLayout {
                    columns: controlWindow.mode === "tiles" ? 2 : 3
                    Layout.fillWidth: true
                    Pill { styleScope: "Control Center"; text: "Wallpapers"; onClicked: root.showWallpapers() }
                    Pill { styleScope: "Control Center"; text: "Notifications"; onClicked: root.toggle("notifications") }
                    Pill { styleScope: "Control Center"; text: root.networkKind === "offline" ? "Network offline" : "Network connected"; onClicked: { root.page = ""; Quickshell.execDetached(["nm-connection-editor"]) } }
                }
            }
        }
    }
    PanelWindow {
        id: alertsWindow
        readonly property bool expanded: root.page === "notifications"
        property real reveal: expanded ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: root.motion; easing.type: Easing.OutCubic } }
        visible: expanded || reveal > .001
        anchors { top: !prefs.barBottom; bottom: prefs.barBottom; right: true }
        margins { top: prefs.barHeight + 8; bottom: prefs.barHeight + 8; right: 12 }
        implicitWidth: 360; implicitHeight: 380
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        Card {
            styleScope: "Notifications"
            anchors.fill: parent
            opacity: alertsWindow.reveal
            scale: .96 + .04 * alertsWindow.reveal
            enabled: alertsWindow.expanded
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14
                RowLayout { Caption { deyraTextScope: "Notifications"; text: "Notifications"; Layout.fillWidth: true; font.pixelSize: 18 } Pill { styleScope: "Notifications"; text: "×"; onClicked: root.page = "" } }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    model: notifications.trackedNotifications
                    delegate: ItemDelegate {
                        required property var modelData
                        width: ListView.view.width
                        onClicked: modelData.dismiss()
                        contentItem: Column {
                            Caption { deyraTextScope: "Notifications"; text: modelData.appName + " · " + modelData.summary; width: parent.width; elide: Text.ElideRight }
                            Caption { deyraTextScope: "Notifications"; text: modelData.body; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }
    }
    PanelWindow {
        id: toastWindow
        readonly property bool expanded: root.currentToast !== null && !root.dnd
        property real reveal: expanded ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: root.motion; easing.type: Easing.OutCubic } }
        visible: expanded || reveal > .001
        anchors { top: true; right: true }
        margins { top: prefs.barHeight + 8; right: 12 }
        implicitWidth: 330; implicitHeight: 85
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        Card {
            styleScope: "Notifications"
            anchors.fill: parent
            opacity: toastWindow.reveal
            transform: Translate { x: 18 * (1-toastWindow.reveal) }
            Column {
                anchors.fill: parent; anchors.margins: 12
                Caption { deyraTextScope: "Notifications"; width: parent.width; elide: Text.ElideRight; text: root.toastTitle }
                Caption { deyraTextScope: "Notifications"; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; text: root.toastBody }
            }
        }
    }
    PanelWindow {
        id: switcher
        readonly property bool radial: root.layoutFor("Window Switcher") === "radial"
        readonly property bool expanded: root.page === "switcher"
        property real reveal: expanded ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: prefs.reduceMotion || !prefs.switcherAnimated ? 0 : prefs.switcherDuration; easing.type: Easing.OutCubic } }
        visible: expanded || reveal > .001
        anchors { right: prefs.switcherAlign === "right"; left: prefs.switcherAlign === "left" }
        margins { right: 24; left: 24 }
        implicitWidth: switcher.radial ? (prefs.switcherCompact ? 300 : 390) : Math.min(screen ? screen.width - 24 : 740, Math.max(260, root.windows.length*54 + 32))
        implicitHeight: switcher.radial ? implicitWidth : prefs.switcherCompact ? 110 : 160
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) ring.forceActiveFocus()
        Card {
            styleScope: "Window Switcher"
            id: ring
            opacity: switcher.reveal
            scale: .86 + .14 * switcher.reveal
            enabled: switcher.expanded
            anchors.fill: parent; radius: switcher.radial ? width/2 : root.styleFor("Window Switcher").radius; focus: true
            Keys.onEscapePressed: root.page = ""
            Keys.onTabPressed: function(event) { if(root.windows.length) root.selectedWindow = (root.selectedWindow + ((event.modifiers & Qt.ShiftModifier) ? root.windows.length - 1 : 1)) % root.windows.length; event.accepted = true }
            Keys.onBacktabPressed: if(root.windows.length) root.selectedWindow = (root.selectedWindow + root.windows.length - 1) % root.windows.length
            Keys.onReturnPressed: root.confirmWindow()
            Keys.onReleased: function(event) { if(event.key === Qt.Key_Alt) root.confirmWindow() }
            Caption { deyraTextScope: "Window Switcher"; anchors.horizontalCenter: parent.horizontalCenter; y: switcher.radial ? (parent.height-height)/2 : parent.height-height-10; width: switcher.radial ? 130 : parent.width-32; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight; text: root.windows[root.selectedWindow] ? root.windows[root.selectedWindow].title : "No windows" }
            Repeater {
                model: root.windows.slice(0, 12)
                delegate: Button {
                    required property var modelData
                    required property int index
                    width: switcher.radial ? 48 : Math.min(48,(ring.width-20)/Math.max(1,root.windows.length)-4); height: 48
                    x: switcher.radial ? ring.width/2 - width/2 + (ring.width/2-56)*Math.cos(index*2*Math.PI/Math.min(root.windows.length,12)-Math.PI/2) : (ring.width - root.windows.length * Math.min(54,(ring.width-20)/Math.max(1,root.windows.length)))/2 + index * Math.min(54,(ring.width-20)/Math.max(1,root.windows.length))
                    y: switcher.radial ? ring.height/2 - height/2 + (ring.height/2-56)*Math.sin(index*2*Math.PI/Math.min(root.windows.length,12)-Math.PI/2) : (prefs.switcherCompact ? 10 : 24)
                    onClicked: { root.selectedWindow = index; root.confirmWindow() }
                    background: Rectangle { radius: 24; color: index === root.selectedWindow ? "#3d4263" : "#22263c"; border.width: 2; border.color: index === root.selectedWindow ? root.styleFor("Window Switcher").accent : "transparent" }
                    contentItem: AppGlyph { imageSource: root.appIcon(modelData); fallbackText: modelData.title || modelData.appId || "?" }
                }
            }
        }
    }

    PanelWindow {
        id: settings
        readonly property bool expanded: root.page === "settings"
        property real reveal: expanded ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: root.motion; easing.type: Easing.OutCubic } }
        visible: expanded || reveal > .001
        implicitWidth: Math.min(980, screen ? screen.width-40 : 980)
        implicitHeight: Math.min(660, screen ? screen.height-80 : 660)
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        property string editorMode: ""
        property string chosenImage: ""
        property string browseFolder: "file://" + Quickshell.env("HOME")
        property string draftHex: "#000000"
        function openColor() {
            draftHex = root.editorColor
            editorMode = "color"
        }
        function openImage(kind) {
            chosenImage = ""
            browseFolder = "file://" + Quickshell.env("HOME")
            editorMode = kind
        }
        function closeEditor() { editorMode = ""; chosenImage = "" }
        function setChannel(index, value) {
            const raw = draftHex.slice(1)
            const channel = Math.round(value).toString(16).padStart(2,"0")
            draftHex = "#" + raw.slice(0,index*2) + channel + raw.slice(index*2+2)
        }
        onExpandedChanged: if (!expanded) closeEditor()
        Shortcut {
            sequence: "Escape"
            enabled: settings.expanded
            onActivated: {
                if (settings.editorMode !== "") settings.closeEditor()
                else root.page = ""
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: root.uiBase
            border.color: root.uiLine
            opacity: settings.reveal
            scale: .97 + .03 * settings.reveal
            enabled: settings.expanded
            clip: true
            RowLayout {
                anchors.fill: parent; spacing: 0
                Rectangle {
                    Layout.preferredWidth: 208; Layout.fillHeight: true
                    color: root.uiPanel
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 18; spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                width: 34; height: 34; radius: 10; color: root.accent
                                Caption { anchors.centerIn: parent; text: "D"; color: root.contrastingText(root.accent); font.pixelSize: 20; font.weight: Font.Bold }
                            }
                            ColumnLayout {
                                spacing: 0
                                Caption { text: "Deyra"; font.pixelSize: 19; font.weight: Font.DemiBold }
                                Muted { text: "Shell settings" }
                            }
                        }
                        Item { Layout.preferredHeight: 18 }
                        Muted { text: "DESKTOP"; font.pixelSize: 10; font.letterSpacing: 1.2; Layout.leftMargin: 10 }
                        Repeater {
                            model: [{name:"Themes",glyph:"◉"},{name:"Edit Mode",glyph:"⊞"},{name:"Community",glyph:"◎"}]
                            delegate: NavButton { required property var modelData; Layout.fillWidth: true; text: modelData.name; glyph: modelData.glyph; navSelected: root.settingsTab === modelData.name; onClicked: root.settingsTab = modelData.name }
                        }
                        Item { Layout.preferredHeight: 15 }
                        Muted { text: "SYSTEM"; font.pixelSize: 10; font.letterSpacing: 1.2; Layout.leftMargin: 10 }
                        Repeater {
                            model: [{name:"Profile",glyph:"♙"},{name:"System",glyph:"⚙"},{name:"Performance",glyph:"↗"},{name:"Updates",glyph:"↻"}]
                            delegate: NavButton { required property var modelData; Layout.fillWidth: true; text: modelData.name; glyph: modelData.glyph; navSelected: root.settingsTab === modelData.name; onClicked: root.settingsTab = modelData.name }
                        }
                        Item { Layout.fillHeight: true }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.uiLine }
                        RowLayout {
                            Layout.fillWidth: true
                            Muted { text: "v0.2.6 alpha"; Layout.fillWidth: true }
                            Pill { text: "×"; implicitWidth: 34; implicitHeight: 32; onClicked: root.page = "" }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.margins: 26; spacing: 16
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Caption { text: root.settingsTab; font.pixelSize: 30; font.weight: Font.DemiBold }
                            Muted { text: root.pageDescription(root.settingsTab); font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                        Pill { text: "×"; implicitWidth: 34; implicitHeight: 34; onClicked: root.page = "" }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: root.uiLine }
                    Loader {
                        id: settingsBody
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        sourceComponent: root.settingsTab === "Themes" ? themesPage : root.settingsTab === "Edit Mode" ? editPage : root.settingsTab === "Community" ? communityPage : root.settingsTab === "Profile" ? profilePage : root.settingsTab === "System" ? systemPage : root.settingsTab === "Performance" ? performancePage : updatesPage
                        onLoaded: { if (!prefs.reduceMotion) tabMotion.restart() }
                        NumberAnimation { id: tabMotion; target: settingsBody; property: "opacity"; from: 0; to: 1; duration: root.motion; easing.type: Easing.OutCubic }
                    }
                    Muted { visible: root.status !== ""; text: root.status; Layout.fillWidth: true; elide: Text.ElideRight }
                }
            }
        }
        // Embedded editors: no native dialog windows or extra shell instances.
        Item {
            id: inlineEditor
            anchors.fill: parent
            z: 20
            visible: settings.editorMode !== ""
            Rectangle { anchors.fill: parent; color: "#99000000"; radius: 20 }
            MouseArea { anchors.fill: parent; onClicked: {} }
            Rectangle {
                id: editorPanel
                anchors.centerIn: parent
                width: Math.min(parent.width-40,settings.editorMode==="color" ? 510 : 720)
                height: Math.min(parent.height-40,settings.editorMode==="color" ? 360 : 490)
                radius: 16
                color: root.uiPanel
                border.color: root.uiLine
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 20; spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        Caption {
                            text: settings.editorMode === "color" ? "Choose a color" : settings.editorMode === "avatar" ? "Choose avatar" : "Choose wallpaper"
                            font.pixelSize: 21; font.weight: Font.DemiBold; Layout.fillWidth: true
                        }
                        Pill { text: "×"; implicitWidth: 34; onClicked: settings.closeEditor() }
                    }
                    Loader {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        sourceComponent: !inlineEditor.visible ? null : settings.editorMode === "color" ? colorEditor : imageEditor
                    }
                }
            }
        }
        Component {
            id: colorEditor
            ColumnLayout {
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 65
                    radius: 10; color: settings.draftHex; border.color: root.uiLine
                    Caption { anchors.centerIn: parent; text: settings.draftHex.toUpperCase(); color: root.contrastingText(settings.draftHex); font.pixelSize: 16; font.weight: Font.DemiBold }
                }
                Repeater {
                    model: ["Red","Green","Blue"]
                    delegate: RowLayout {
                        id: channelRow
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        Caption { text: channelRow.modelData; Layout.preferredWidth: 48 }
                        DeyraSlider {
                            Layout.fillWidth: true; from: 0; to: 255; stepSize: 1
                            value: parseInt(settings.draftHex.slice(1+channelRow.index*2,3+channelRow.index*2),16)
                            onMoved: settings.setChannel(channelRow.index,value)
                        }
                        Muted { text: String(Math.round(parseInt(settings.draftHex.slice(1+channelRow.index*2,3+channelRow.index*2),16))); Layout.preferredWidth: 32 }
                    }
                }
                RowLayout {
                    DeyraInput {
                        id: colorEntry
                        Layout.fillWidth: true; text: settings.draftHex
                        maximumLength: 7
                        validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}/ }
                        onTextEdited: if (acceptableInput) settings.draftHex = text.toLowerCase()
                        Connections { target: settings; function onDraftHexChanged() { if (colorEntry.text !== settings.draftHex) colorEntry.text = settings.draftHex } }
                    }
                    Pill { text: "Cancel"; onClicked: settings.closeEditor() }
                    Pill { text: "Apply"; deyraSelected: true; enabled: colorEntry.acceptableInput; onClicked: { root.setAppearance(root.colorScope,root.colorRole,settings.draftHex); settings.closeEditor() } }
                }
                Item { Layout.fillHeight: true }
            }
        }
        Component {
            id: imageEditor
            ColumnLayout {
                spacing: 10
                FolderListModel {
                    id: imageFiles
                    folder: settings.browseFolder
                    nameFilters: ["*.png","*.jpg","*.jpeg","*.webp","*.PNG","*.JPG","*.JPEG","*.WEBP"]
                    showDirs: true
                    showFiles: true
                    showDotAndDotDot: false
                    showDirsFirst: true
                    sortField: FolderListModel.Name
                }
                RowLayout {
                    Layout.fillWidth: true
                    Pill { text: "Home"; onClicked: { settings.browseFolder = "file://" + Quickshell.env("HOME"); settings.chosenImage = "" } }
                    Pill { text: "↑"; onClicked: { settings.browseFolder = imageFiles.parentFolder.toString() || "file:///"; settings.chosenImage = "" } }
                    DeyraInput {
                        id: folderEntry
                        Layout.fillWidth: true
                        text: decodeURIComponent(settings.browseFolder.replace(/^file:\/\//,""))
                        onAccepted: {
                            const path = text.trim()
                            if (path.startsWith("/")) { settings.browseFolder = "file://" + encodeURI(path); settings.chosenImage = "" }
                        }
                        Connections { target: settings; function onBrowseFolderChanged() { folderEntry.text = decodeURIComponent(settings.browseFolder.replace(/^file:\/\//,"")) } }
                    }
                    Pill { text: "Go"; onClicked: folderEntry.accepted() }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 9; color: root.uiBase; clip: true
                        ListView {
                            anchors.fill: parent; anchors.margins: 5
                            model: imageFiles; clip: true; spacing: 3
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            delegate: Button {
                                id: fileRow
                                required property string fileName
                                required property url fileUrl
                                required property bool fileIsDir
                                width: ListView.view.width; height: 35
                                onClicked: {
                                    if (fileIsDir) { settings.browseFolder = fileUrl.toString(); settings.chosenImage = "" }
                                    else settings.chosenImage = fileUrl.toString()
                                }
                                background: Rectangle { radius: 6; color: settings.chosenImage === fileRow.fileUrl.toString() ? Qt.tint(root.uiRaised,Qt.alpha(root.accent,.18)) : fileRow.hovered ? root.uiRaised : "transparent" }
                                contentItem: Caption { text: (fileRow.fileIsDir ? "▸  " : "    ") + fileRow.fileName; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                            }
                            footer: Muted { visible: imageFiles.count===0; text: "No matching images or folders" }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: Math.min(230,editorPanel.width*.34); Layout.fillHeight: true
                        radius: 9; color: root.uiBase; clip: true
                        Image { id: selectedPicture; anchors.fill: parent; anchors.margins: 8; source: settings.chosenImage; asynchronous: true; sourceSize.width: 480; fillMode: Image.PreserveAspectFit }
                        Muted { anchors.centerIn: parent; visible: selectedPicture.status !== Image.Ready; text: selectedPicture.status === Image.Error ? "Unable to open image" : "Select an image" }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Muted { text: settings.chosenImage ? decodeURIComponent(settings.chosenImage.split("/").pop()) : "PNG, JPG, WEBP"; Layout.fillWidth: true; elide: Text.ElideRight }
                    Pill { text: "Cancel"; onClicked: settings.closeEditor() }
                    Pill {
                        text: "Select"; deyraSelected: true
                        enabled: selectedPicture.status === Image.Ready
                        onClicked: {
                            if(settings.editorMode==="avatar") prefs.avatar = settings.chosenImage
                            else prefs.wallpaper = settings.chosenImage
                            settings.closeEditor()
                        }
                    }
                }
            }
        }
        Component {
            id: themesPage
            Section {
                RowLayout {
                    Layout.fillWidth: true
                    Pill { text: "Original themes"; deyraSelected: root.themesView === "Originals"; onClicked: root.themesView = "Originals" }
                    Pill { text: "Colors & appearance"; deyraSelected: root.themesView === "Colors"; onClicked: root.themesView = "Colors" }
                    Item { Layout.fillWidth: true }
                }
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    sourceComponent: root.themesView === "Originals" ? originalsPage : appearancePage
                }
            }
        }
        Component {
            id: originalsPage
            Section {
                Caption { text: "Original project library"; font.pixelSize: 18; font.weight: Font.DemiBold }
                Muted { text: "Browse original screenshots and download the unmodified source repositories. Apply Deyra port uses only the features already integrated into this shell."; Layout.fillWidth: true; wrapMode: Text.Wrap }
                GridView {
                    id: originalGrid
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    cellWidth: width / Math.max(1,Math.floor(width/300))
                    cellHeight: 300
                    model: root.presets
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Rectangle {
                        id: originalCard
                        required property var modelData
                        width: originalGrid.cellWidth-10
                        height: originalGrid.cellHeight-10
                        color: root.uiPanel; radius: 14
                        border.color: root.uiLine
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 6
                            Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                radius: 8; color: root.uiBase; clip: true
                                PresetPreview { anchors.fill: parent; profile: originalCard.modelData }
                            }
                            Caption { text: originalCard.modelData.name; font.pixelSize: 17; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                            Muted { text: root.upstreamMedia[originalCard.modelData.name].credit; Layout.fillWidth: true; elide: Text.ElideRight }
                            RowLayout {
                                Layout.fillWidth: true
                                Pill { text: root.originalTask === originalCard.modelData.name ? "Downloading…" : "Download configs"; enabled: !upstreamFetch.running; Layout.fillWidth: true; onClicked: root.fetchOriginal(originalCard.modelData) }
                                Pill { text: "GitHub"; onClicked: Qt.openUrlExternally(originalCard.modelData.url) }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Pill { text: "Apply Deyra port"; Layout.fillWidth: true; onClicked: root.applyPreset(originalCard.modelData,"All") }
                                Pill { text: "Showcase"; onClicked: Qt.openUrlExternally(root.upstreamMedia[originalCard.modelData.name].gallery) }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Muted { text: "Originals are downloaded separately; no installers are run."; Layout.fillWidth: true; wrapMode: Text.Wrap }
                    Pill { text: "Open originals"; onClicked: Qt.openUrlExternally("file://" + root.statePath + "/upstream") }
                }
            }
        }
        Component {
            id: appearancePage
            ScrollView {
                id: themeScroll
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    id: themePalette
                    width: themeScroll.availableWidth
                    spacing: 12
                    property bool showFullPalette: false
                    Caption { text: "Theme & palette"; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: paletteControls.implicitHeight + 24
                        radius: 12; color: root.uiPanel; border.color: root.uiLine
                        ColumnLayout {
                            id: paletteControls
                            anchors.fill: parent; anchors.margins: 12; spacing: 8
                            DeyraCheck { Layout.fillWidth: true; text: "Matugen · colors from wallpaper"; checked: prefs.matugenEnabled; onToggled: prefs.matugenEnabled = checked }
                            RowLayout {
                                Layout.fillWidth: true
                                Muted { text: root.matugenStatus; Layout.fillWidth: true; wrapMode: Text.Wrap }
                                Pill { text: matugenProcess.running ? "Generating…" : "Regenerate"; enabled: prefs.matugenEnabled && !matugenProcess.running && prefs.wallpaper !== ""; onClicked: root.queueMatugen() }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Repeater {
                                    model: ["primary","secondary","tertiary","background","surface_container","on_surface"]
                                    delegate: Rectangle {
                                        required property string modelData
                                        Layout.fillWidth: true; Layout.preferredHeight: 26
                                        radius: 6; border.color: root.uiLine
                                        color: root.paletteColor(modelData,root.uiRaised)
                                        Behavior on color { ColorAnimation { duration: root.motion } }
                                    }
                                }
                            }
                            Muted { text: "Manual color selection disables automatic colors. Layouts and sizes are preserved."; Layout.fillWidth: true; wrapMode: Text.Wrap }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Caption { text: "Preset: " + prefs.activePreset; Layout.fillWidth: true; elide: Text.ElideRight }
                        Pill { text: "Browse 12 presets"; onClicked: { root.editTab = "Presets"; root.settingsTab = "Edit Mode" } }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Caption { text: "Customize" }
                        DeyraCombo {
                            Layout.fillWidth: true
                            model: ["All"].concat(root.supportedScopes)
                            currentIndex: Math.max(0, model.indexOf(root.colorScope))
                            onActivated: root.colorScope = currentText
                        }
                        Pill { text: "Inherit"; visible: root.colorScope !== "All"; onClicked: root.resetComponent(root.colorScope) }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 78
                        radius: 14
                        color: Qt.alpha(root.editorStyle.bg, root.editorStyle.opacity)
                        border.width: 1; border.color: root.uiLine
                        Behavior on color { ColorAnimation { duration: root.motion } }
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 14
                            ColumnLayout {
                                Layout.fillWidth: true
                                Caption { text: root.colorScope + " preview"; font.pixelSize: 17; color: root.contrastingText(root.editorStyle.bg) }
                                Caption { text: root.editorStyle.accent + " / " + root.editorStyle.bg; color: root.contrastingText(root.editorStyle.bg) }
                            }
                            Rectangle { width: 50; height: 34; radius: root.editorStyle.radius; color: root.editorStyle.accent }
                        }
                    }
                    RowLayout {
                        Pill { text: "Accent"; deyraSelected: root.colorRole === "accent"; onClicked: root.colorRole = "accent" }
                        Pill { text: "Background"; deyraSelected: root.colorRole === "bg"; onClicked: root.colorRole = "bg" }
                        Item { Layout.fillWidth: true }
                        Pill { text: "Color picker"; onClicked: settings.openColor() }
                    }
                    RowLayout {
                        Rectangle { width: 34; height: 34; radius: 8; color: root.editorColor; border.color: "#8b92aa" }
                        DeyraInput {
                            id: hexInput
                            Layout.fillWidth: true
                            text: root.editorColor
                            placeholderText: "#RRGGBB"
                            maximumLength: 7
                            validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}/ }
                            onAccepted: if (acceptableInput) root.setAppearance(root.colorScope, root.colorRole, text)
                            Connections { target: root; function onEditorColorChanged() { hexInput.text = root.editorColor } }
                        }
                        Pill { text: "Apply HEX"; enabled: hexInput.acceptableInput; onClicked: root.setAppearance(root.colorScope, root.colorRole, hexInput.text) }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Caption { text: "Color palette"; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Pill { text: themePalette.showFullPalette ? "Fewer colors" : "All 80 colors"; onClicked: themePalette.showFullPalette = !themePalette.showFullPalette }
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: 5
                        Repeater {
                            model: themePalette.showFullPalette ? root.colorSwatches : ["#a38ff7","#8aadf4","#8bd5ca","#ffb4a2","#f5c2e7","#d9c3a5","#facc15","#22c55e","#ef4444","#0f111e","#334155","#ffffff"]
                            delegate: Rectangle {
                                id: swatch
                                required property string modelData
                                width: 30; height: 30; radius: 15; color: modelData
                                scale: swatchMouse.containsMouse && !prefs.reduceMotion ? 1.12 : 1
                                Behavior on scale { NumberAnimation { duration: root.motion / 2; easing.type: Easing.OutCubic } }
                                border.width: root.editorColor.toLowerCase() === modelData ? 2 : 1
                                border.color: root.editorColor.toLowerCase() === modelData ? root.contrastingText(modelData) : root.uiLine
                                MouseArea { id: swatchMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.setAppearance(root.colorScope, root.colorRole, swatch.modelData) }
                                ToolTip.visible: swatchMouse.containsMouse
                                ToolTip.text: modelData
                            }
                        }
                    }
                    RowLayout {
                        Caption { text: "Panel opacity"; Layout.fillWidth: true }
                        Caption { text: Math.round(root.editorStyle.opacity * 100) + "%"; color: root.accent }
                    }
                    DeyraSlider { Layout.fillWidth: true; from: .45; to: 1; value: root.editorStyle.opacity; onMoved: root.setAppearance(root.colorScope, "opacity", value) }
                    RowLayout {
                        Caption { text: "Corner radius"; Layout.fillWidth: true }
                        Caption { text: root.editorStyle.radius + " px"; color: root.accent }
                    }
                    DeyraSlider { Layout.fillWidth: true; from: 0; to: 40; stepSize: 1; value: root.editorStyle.radius; onMoved: root.setAppearance(root.colorScope, "radius", value) }
                    Pill { text: "Reset appearance to preset"; onClicked: root.resetAppearance() }
                    Caption { text: "Global changes affect components without individual overrides."; Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: .7 }
                }
            }
        }
        Component {
            id: editPage
            Section {
                Flow {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: ["Presets","Bar","Desktop Widgets","Launcher","Control Center","Lock Screen","Notifications","Window Switcher","Wallpapers"]
                        delegate: Pill { required property string modelData; text: modelData; deyraSelected: root.editTab === modelData; onClicked: root.editTab = modelData }
                    }
                }
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    sourceComponent: root.editTab === "Presets" ? presetsPage : root.editTab === "Wallpapers" ? wallpapersPage : root.editTab === "Bar" ? barPage : root.editTab === "Desktop Widgets" ? widgetsPage : root.editTab === "Notifications" ? notificationsPage : root.editTab === "Window Switcher" ? switcherPage : pendingPage
                }
            }
        }
        Component {
            id: presetsPage
            Section {
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: ["All"].concat(root.supportedScopes)
                        delegate: Pill {
                            required property string modelData
                            text: modelData
                            deyraSelected: root.presetScope === modelData
                            onClicked: { root.presetScope = modelData; presetGrid.positionViewAtBeginning() }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Caption { text: root.presetScope === "All" ? "Complete desktop profiles" : root.presetScope + " presets"; font.pixelSize: 17; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Pill { text: "Use global"; visible: root.presetScope !== "All"; onClicked: root.resetComponent(root.presetScope) }
                }
                GridView {
                    id: presetGrid
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    cellWidth: width / Math.max(1, Math.floor(width / 235))
                    cellHeight: 230
                    model: root.presets
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Rectangle {
                        id: presetCard
                        required property var modelData
                        readonly property string scope: root.presetScope
                        readonly property bool chosen: root.componentPreview(scope) === modelData.name
                        width: presetGrid.cellWidth - 10
                        height: presetGrid.cellHeight - 10
                        radius: 14; color: root.uiPanel
                        border.width: 1; border.color: chosen ? root.accent : root.uiLine
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 9; spacing: 6
                            Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                radius: 9; color: "#11131a"; clip: true
                                PresetPreview {
                                    anchors.fill: parent
                                    profile: presetCard.modelData
                                    previewScope: presetCard.scope
                                }
                            }
                            Caption { text: presetCard.modelData.name; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                            Muted { text: presetCard.modelData.author + " · " + root.previewLayout(presetCard.modelData.name, presetCard.scope); Layout.fillWidth: true; elide: Text.ElideRight }
                            RowLayout {
                                Layout.fillWidth: true
                                Pill { text: presetCard.chosen ? "Selected" : "Apply"; deyraSelected: presetCard.chosen; Layout.fillWidth: true; onClicked: root.applyPreset(presetCard.modelData,presetCard.scope) }
                                Pill { text: "Source"; onClicked: Qt.openUrlExternally(presetCard.modelData.url) }
                            }
                        }
                    }
                }
                Muted { text: "Original project screenshots, not a preview of the partial Deyra ports."; Layout.fillWidth: true; wrapMode: Text.Wrap }
            }
        }
        Component {
            id: barPage
            ScrollView {
                id: barEditor
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: barEditor.availableWidth
                    spacing: 12
                    Caption { text: "Source layouts"; font.pixelSize: 18; font.weight: Font.DemiBold }
                    RowLayout {
                        Layout.fillWidth: true
                        DeyraCombo {
                            id: sourceSelect
                            Layout.fillWidth: true
                            model: root.sourceProfiles.map(function(p){return p.name})
                            currentIndex: Math.max(0,model.indexOf(root.styleFor("Bar").name))
                        }
                        Pill {
                            text: "Apply source layout"
                            onClicked: {
                                const p = root.presets.find(function(item){return item.name===sourceSelect.currentText})
                                if (p) root.applyPreset(p,"Bar")
                            }
                        }
                        Pill { text: "Source"; onClicked: Qt.openUrlExternally(root.sourceLink(root.selectedBarSource)) }
                    }
                    Muted { text: root.selectedBarSource.description + " · " + root.selectedBarSource.license; Layout.fillWidth: true; wrapMode: Text.Wrap }
                    RowLayout {
                        Caption { text: "Position"; Layout.fillWidth: true }
                        Pill { text: "Top"; deyraSelected: !prefs.barBottom; onClicked: prefs.barBottom = false }
                        Pill { text: "Bottom"; deyraSelected: prefs.barBottom; onClicked: prefs.barBottom = true }
                    }
                    RowLayout { Caption { text: "Height"; Layout.fillWidth: true } Muted { text: prefs.barHeight+" px" } }
                    DeyraSlider { Layout.fillWidth: true; from: 24; to: 64; stepSize: 1; value: prefs.barHeight; onMoved: prefs.barHeight = value }
                    RowLayout { Caption { text: "Module spacing"; Layout.fillWidth: true } Muted { text: prefs.barSpacing+" px" } }
                    DeyraSlider { Layout.fillWidth: true; from: 0; to: 16; stepSize: 1; value: prefs.barSpacing; onMoved: prefs.barSpacing = value }
                    RowLayout { Caption { text: "Screen-edge inset"; Layout.fillWidth: true } Muted { text: prefs.barInset+" px (maximum)" } }
                    DeyraSlider { Layout.fillWidth: true; from: 0; to: 180; stepSize: 2; value: prefs.barInset; onMoved: prefs.barInset = value }
                    RowLayout {
                        Caption { text: "Workspace face"; Layout.fillWidth: true }
                        DeyraCombo {
                            model: ["source","pills","numbers","dots","morph","trace"]
                            currentIndex: Math.max(0,model.indexOf(prefs.workspaceFace))
                            onActivated: prefs.workspaceFace = currentText
                            Layout.preferredWidth: 150
                        }
                    }
                    DeyraCheck { Layout.fillWidth: true; text: "12-hour clock"; checked: prefs.clock12h; onToggled: prefs.clock12h = checked }
                    DeyraCheck { Layout.fillWidth: true; text: "Frame around bar"; checked: prefs.barFrame; onToggled: prefs.barFrame = checked }
                    Rectangle { Layout.fillWidth: true; height: 1; color: root.uiLine }
                    RowLayout {
                        Caption { text: "Modules"; font.pixelSize: 18; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Pill { text: "Restore source order"; onClicked: root.applySourceBar(root.styleFor("Bar").name) }
                    }
                    Muted { text: "Choose a widget and section. Move modules with arrows or remove them; changes are saved immediately."; Layout.fillWidth: true; wrapMode: Text.Wrap }
                    RowLayout {
                        DeyraCombo { id: modulePick; Layout.fillWidth: true; model: root.barCatalog.map(function(m){return m.title}) }
                        DeyraCombo { id: sectionPick; model: ["left","center","right"]; Layout.preferredWidth: 120 }
                        Pill { text: "Add"; onClicked: root.addBarModule(sectionPick.currentText,root.barCatalog[modulePick.currentIndex].key) }
                    }
                    Repeater {
                        model: ["left","center","right"]
                        delegate: ColumnLayout {
                            id: editorSection
                            required property string modelData
                            Layout.fillWidth: true
                            spacing: 4
                            Caption { text: editorSection.modelData.toUpperCase(); color: root.uiMuted; font.pixelSize: 11 }
                            Repeater {
                                model: root.effectiveBarLayout[editorSection.modelData] || []
                                delegate: Rectangle {
                                    id: editorRow
                                    required property string modelData
                                    required property int index
                                    Layout.fillWidth: true; Layout.preferredHeight: 39
                                    color: root.uiPanel; radius: 8
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 5
                                        Caption { text: root.moduleTitle(editorRow.modelData); Layout.fillWidth: true; Layout.leftMargin: 8 }
                                        Pill { text: "↑"; implicitWidth: 32; implicitHeight: 28; enabled: editorRow.index>0; onClicked: root.moveBarModule(editorSection.modelData,editorRow.index,-1) }
                                        Pill { text: "↓"; implicitWidth: 32; implicitHeight: 28; enabled: editorRow.index<root.effectiveBarLayout[editorSection.modelData].length-1; onClicked: root.moveBarModule(editorSection.modelData,editorRow.index,1) }
                                        Pill { text: "×"; implicitWidth: 32; implicitHeight: 28; onClicked: root.removeBarModule(editorSection.modelData,editorRow.index) }
                                    }
                                }
                            }
                        }
                    }
                    DeyraCheck { Layout.fillWidth: true; text: "Show audio module"; checked: prefs.showAudio; onToggled: prefs.showAudio = checked }
                    DeyraCheck { Layout.fillWidth: true; text: "Show notifications module"; checked: prefs.showNotifications; onToggled: prefs.showNotifications = checked }
                }
            }
        }
        Component {
            id: widgetsPage
            Section {
                DeyraCheck { Layout.fillWidth: true; text: "Desktop clock"; checked: prefs.desktopClock; onToggled: prefs.desktopClock = checked }
                Caption { text: "Clock implementation" }
                DeyraCombo {
                    Layout.fillWidth: true
                    model: ["source","deyra","dux"]
                    currentIndex: Math.max(0,model.indexOf(prefs.desktopClockStyle))
                    onActivated: prefs.desktopClockStyle = currentText
                }
                Muted { text: "Dux uses the original ExampleDesktopClock QML with a Deyra theme adapter."; Layout.fillWidth: true; wrapMode: Text.Wrap }
                Item { Layout.fillHeight: true }
            }
        }
        Component { id: notificationsPage; Section { DeyraCheck { text: "Do not disturb"; checked: root.dnd; onToggled: root.dnd = checked } Item { Layout.fillHeight: true } } }
        Component {
            id: switcherPage
            Section {
                Caption { text: "Window switcher"; font.pixelSize: 18; font.weight: Font.DemiBold }
                Muted { text: "Alignment, compact mode and motion controls adapted from iNiR's altSwitcher configuration."; Layout.fillWidth: true; wrapMode: Text.Wrap }
                RowLayout {
                    Layout.fillWidth: true
                    Caption { text: "Alignment"; Layout.fillWidth: true }
                    DeyraCombo { model: ["left","center","right"]; currentIndex: Math.max(0,model.indexOf(prefs.switcherAlign)); onActivated: prefs.switcherAlign = currentText; Layout.preferredWidth: 160 }
                }
                DeyraCheck { Layout.fillWidth: true; text: "Compact layout"; checked: prefs.switcherCompact; onToggled: prefs.switcherCompact = checked }
                DeyraCheck { Layout.fillWidth: true; text: "Animate opening and closing"; checked: prefs.switcherAnimated; onToggled: prefs.switcherAnimated = checked }
                RowLayout { Caption { text: "Transition duration"; Layout.fillWidth: true } Muted { text: prefs.switcherDuration+" ms" } }
                DeyraSlider { Layout.fillWidth: true; from: 0; to: 450; stepSize: 10; value: prefs.switcherDuration; onMoved: prefs.switcherDuration = value }
                Pill { text: "Use source defaults"; onClicked: root.applySwitcherSource(root.styleFor("Window Switcher").name) }
                Item { Layout.fillHeight: true }
            }
        }
        Component { id: pendingPage; Section { Caption { text: root.editTab + " customization is planned for a later alpha." } Item { Layout.fillHeight: true } } }
        Component {
            id: wallpapersPage
            Section {
                RowLayout {
                    Repeater {
                        model: ["Local","Online","Animated","Favorites","Collections","Daily"]
                        delegate: Pill { required property string modelData; text: modelData; deyraSelected: root.wallpaperTab === modelData; onClicked: root.wallpaperTab = modelData }
                    }
                }
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    sourceComponent: root.wallpaperTab === "Local" ? localPage : root.wallpaperTab === "Online" ? onlinePage : wallpaperPending
                }
            }
        }
        Component {
            id: localPage
            Section {
                Image { Layout.fillWidth: true; Layout.fillHeight: true; source: prefs.wallpaper; fillMode: Image.PreserveAspectFit; asynchronous: true; sourceSize.width: 700 }
                RowLayout {
                    Pill { text: "Choose local image"; onClicked: settings.openImage("wallpaper") }
                    Pill { text: "Clear"; onClicked: prefs.wallpaper = "" }
                }
            }
        }
        Component {
            id: onlinePage
            Section {
                Flow {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: ["forest fog","mountains","space","nebula","ocean","landscape"]
                        delegate: Pill { required property string modelData; text: modelData; enabled: !root.searching; onClicked: root.searchWallpapers(modelData) }
                    }
                }
                GridView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    cellWidth: 150; cellHeight: 112
                    model: root.onlineResults
                    delegate: Button {
                        required property var modelData
                        width: 142; height: 104
                        enabled: !download.running && !moveFile.running
                        onClicked: root.downloadWallpaper(modelData)
                        contentItem: Image { source: modelData.thumbs.small; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 142 }
                        background: Rectangle { radius: 10; color: "#252943"; border.color: root.accent }
                        ToolTip.visible: hovered
                        ToolTip.text: "Download and apply · " + modelData.resolution
                    }
                }
                Caption { text: "Wallhaven · landscape categories · SFW only"; opacity: .7 }
            }
        }
        Component { id: wallpaperPending; Section { Caption { text: root.wallpaperTab + " is planned; static local and online images are available now." } Item { Layout.fillHeight: true } } }
        Component {
            id: communityPage
            Section {
                Caption { text: "12 Deyra layout and style profiles available"; font.pixelSize: 17 }
                Pill { text: "Open preset library"; onClicked: { root.editTab = "Presets"; root.settingsTab = "Edit Mode" } }
                Caption { text: "Third-party widgets and upstream code ports require separate license review."; Layout.fillWidth: true; wrapMode: Text.Wrap }
                Item { Layout.fillHeight: true }
            }
        }
        Component {
            id: profilePage
            Section {
                Image { source: prefs.avatar; Layout.preferredWidth: 100; Layout.preferredHeight: 100; fillMode: Image.PreserveAspectCrop }
                Caption { text: root.profileName; font.pixelSize: 22 }
                Pill { text: "Choose avatar"; onClicked: settings.openImage("avatar") }
                Caption { text: root.systemInfo; Layout.fillWidth: true; wrapMode: Text.Wrap }
                Item { Layout.fillHeight: true }
            }
        }
        Component {
            id: systemPage
            Section {
                DeyraCheck { Layout.fillWidth: true; text: "Use imported original components"; checked: prefs.useOriginalPorts; onToggled: prefs.useOriginalPorts = checked }
                Muted { text: "TQQ launcher, Niri switcher and Wi-Fi; Dux clock; DarkShadow volume wave. Turn off for Deyra fallbacks."; Layout.fillWidth: true; wrapMode: Text.Wrap }
                Caption { text: "Language: English (additional translations planned)" }
                Caption { text: "Keybinds are configured in your compositor." }
                Caption { text: "Super+D · Launcher   Super+I · Settings\nSuper+B · Wallpapers   Super+Shift+Space · Control"; wrapMode: Text.Wrap; Layout.fillWidth: true }
                Item { Layout.fillHeight: true }
            }
        }
        Component {
            id: performancePage
            Section {
                Caption { text: "Motion & rendering"; font.pixelSize: 18; font.weight: Font.DemiBold }
                DeyraCheck { Layout.fillWidth: true; text: "Reduce motion"; checked: prefs.reduceMotion; onToggled: prefs.reduceMotion = checked }
                Muted { text: "Disables interface transitions and hover animations."; Layout.fillWidth: true; wrapMode: Text.Wrap }
                Caption { text: "Lightweight static wallpaper renderer" }
                Caption { text: "Animated wallpapers and adaptive performance modes are planned." ; wrapMode: Text.Wrap; Layout.fillWidth: true }
                DeyraCheck { text: "Disable desktop clock"; checked: !prefs.desktopClock; onToggled: prefs.desktopClock = !checked }
                Item { Layout.fillHeight: true }
            }
        }
        Component { id: updatesPage; Section { Caption { text: "Deyra Shell 0.2.6 alpha" } Caption { text: "Updates currently use git pull. Automatic updates are planned." ; wrapMode: Text.Wrap; Layout.fillWidth: true } Item { Layout.fillHeight: true } } }
    }
}
