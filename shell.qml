import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications

ShellRoot {
    id: root
    property string page: ""
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
        if (isNiri) Quickshell.execDetached(["niri","msg","raw-request",JSON.stringify({Action:{FocusWorkspace:{reference:{Id:ws.id}}}})])
        else if (isHyprland && ws.id > 0) Quickshell.execDetached(["hyprctl","dispatch","workspace",String(ws.id)])
    }
    property color accent: prefs.accent
    property color surface: Qt.alpha(prefs.background, prefs.opacity)
    property color foreground: "#e9eaf0"
    readonly property color uiBase: "#17181d"
    readonly property color uiPanel: "#202127"
    readonly property color uiRaised: "#292b33"
    readonly property color uiMuted: "#999da9"
    readonly property color uiLine: "#34363e"
    readonly property int motion: prefs.reduceMotion ? 0 : 200
    function tint(bg, amount) { return Qt.tint(bg, Qt.rgba(1,1,1,amount)) }
    function pageDescription(tab) {
        return ({ "Themes":"Make the desktop feel like your own.", "Edit Mode":"Arrange and customize each part of your desktop.", "Community":"Discover community designs and their creators.", "Profile":"Your account and machine.", "System":"Shell behavior and keyboard shortcuts.", "Performance":"Balance motion, appearance and resource usage.", "Updates":"Version and release information." })[tab] || ""
    }
    property string configPath: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    property string statePath: configPath + "/deyra-shell"
    property var currentToast: null
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
            "dock": true,
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
            "dock": true,
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
            "dock": true,
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
            "dock": false,
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
            "dock": true,
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
            "dock": true,
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
            "dock": true,
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
            "dock": true,
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
            "dock": false,
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
            "dock": true,
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
            "dock": true,
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
            "dock": true,
            "clock": true,
            "description": "Teal glass-inspired panels"
        }
    ]
    readonly property var supportedScopes: ["Bar", "Dock", "Launcher", "Control Center", "Notifications", "Window Switcher"]
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
    function styleFor(scope) {
        const p = (prefs.componentStyles || {})[scope]
        return p || {name: prefs.activePreset, accent: prefs.accent, bg: prefs.background, opacity: prefs.opacity, radius: prefs.radius}
    }
    function applyPreset(preset, scope) {
        if (scope === "All") {
            prefs.accent = preset.accent
            prefs.background = preset.bg
            prefs.opacity = preset.opacity
            prefs.radius = preset.radius
            prefs.barHeight = preset.height
            prefs.barBottom = preset.bottom
            prefs.dockEnabled = preset.dock
            prefs.desktopClock = preset.clock
            prefs.activePreset = preset.name
            prefs.componentStyles = ({})
        } else if (supportedScopes.indexOf(scope) >= 0) {
            const next = Object.assign({}, prefs.componentStyles)
            next[scope] = {name: preset.name, accent: preset.accent, bg: preset.bg, opacity: preset.opacity, radius: preset.radius}
            prefs.componentStyles = next
            if (scope === "Bar") { prefs.barHeight = preset.height; prefs.barBottom = preset.bottom }
        } else return
        status = preset.name + " applied to " + scope
    }
    function resetComponent(scope) {
        const next = Object.assign({}, prefs.componentStyles)
        delete next[scope]
        prefs.componentStyles = next
        status = scope + " now follows global appearance"
    }
    function componentPreview(scope) { return scope === "All" ? prefs.activePreset : styleFor(scope).name }
    property string presetScope: "All"
    property string colorScope: "All"
    property string colorRole: "accent"
    readonly property var editorStyle: styleFor(colorScope === "All" ? "" : colorScope)
    readonly property string editorColor: colorRole === "accent" ? editorStyle.accent : editorStyle.bg
    function setAppearance(scope, key, value) {
        if (key === "accent" || key === "bg") {
            value = String(value).trim().toLowerCase()
            if (!/^#[0-9a-f]{6}$/.test(value)) { status = "Enter a valid #RRGGBB color"; return }
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

    function toggle(name) { page = page === name ? "" : name }
    function showSettings(section) { settingsTab = section; page = "settings" }
    function showWallpapers() { editTab = "Wallpapers"; showSettings("Edit Mode") }
    function cycleWindow() {
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
            property bool barBottom: false
            property bool dockEnabled: true
            property bool desktopClock: false
            property bool reduceMotion: false
            property bool showAudio: true
            property bool showNotifications: true
            property string wallpaper: ""
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
            if (!root.dnd) { root.currentToast = notification; toastTimer.restart() }
        }
    }
    Timer { id: toastTimer; interval: 4500; onTriggered: root.currentToast = null }

    IpcHandler {
        target: "deyra"
        function launcher(): void { root.toggle("launcher") }
        function control(): void { root.toggle("control") }
        function settings(): void { root.toggle("settings") }
        function wallpapers(): void { if(root.page === "settings" && root.editTab === "Wallpapers") root.page = ""; else root.showWallpapers() }
        function notifications(): void { root.toggle("notifications") }
        function switcher(): void { root.cycleWindow() }
        function confirm(): void { root.confirmWindow() }
        function close(): void { root.page = "" }
    }

    // Shared visual primitives. Only event-driven animations, no continuous shaders.
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
        property bool selected: false
        implicitHeight: 42
        padding: 12
        contentItem: RowLayout {
            spacing: 12
            Caption { text: nav.glyph; font.pixelSize: 17; color: nav.selected ? root.accent : root.uiMuted; Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter }
            Caption { text: nav.text; font.weight: nav.selected ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; color: nav.selected ? root.foreground : "#b5b7c2" }
        }
        background: Rectangle {
            radius: 9
            color: nav.selected ? Qt.tint(root.uiRaised, Qt.alpha(root.accent,.10)) : nav.hovered ? root.uiRaised : "transparent"
            Behavior on color { ColorAnimation { duration: root.motion / 2 } }
            Rectangle { width: 3; height: 20; radius: 2; anchors { left: parent.left; verticalCenter: parent.verticalCenter }; color: root.accent; opacity: nav.selected ? 1 : 0; Behavior on opacity { NumberAnimation { duration: root.motion } } }
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
        implicitWidth: iconRow.implicitWidth + 20
        implicitHeight: 32
        padding: 10
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
                visible: prefs.desktopClock
                anchors { left: parent.left; top: parent.top; margins: 70 }
                Caption { text: Qt.formatTime(root.now, "hh:mm"); font.pixelSize: 68 }
                Caption { text: Qt.formatDate(root.now, "dddd, MMMM d"); font.pixelSize: 22 }
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
                readonly property string mode: barWindow.mode
                Card {
                    styleScope: "Bar"; visible: barArea.mode === "full"
                    anchors.fill: parent; anchors.margins: 2
                    radius: 4
                }
                Card {
                    styleScope: "Bar"; visible: barArea.mode === "groups"
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    width: leftBar.implicitWidth + 12; height: 36
                }
                Card {
                    styleScope: "Bar"; visible: barArea.mode === "groups"
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    width: rightBar.implicitWidth + 12; height: 36
                }
                Row {
                    id: leftBar
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 5
                    BarIconButton { glyph: "search"; detail: "Applications"; onClicked: root.toggle("launcher") }
                    Card {
                        visible: workspaceRow.count > 0 && barArea.mode !== "minimal"
                        styleScope: "Bar"
                        height: 32; width: workspaceLayout.implicitWidth+16
                        border.width: 0
                        Row {
                            id: workspaceLayout
                            anchors.centerIn: parent; spacing: 6
                            Repeater {
                                id: workspaceRow
                                model: root.workspacesFor(barWindow.screen ? barWindow.screen.name : "")
                                delegate: Rectangle {
                                    id: workspaceDot
                                    required property var modelData
                                    width: modelData.is_active ? 27 : 9
                                    height: 9; radius: 5
                                    color: modelData.is_active ? root.styleFor("Bar").accent : root.tint(root.styleFor("Bar").bg,.28)
                                    Behavior on width { NumberAnimation { duration: root.motion; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: root.motion } }
                                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.activateWorkspace(workspaceDot.modelData) }
                                }
                            }
                        }
                    }
                    Caption { visible: barArea.mode === "minimal"; anchors.verticalCenter: parent.verticalCenter; width: Math.min(170, barArea.width/5); elide: Text.ElideRight; text: root.windows.length ? root.windows[0].title : "Desktop" }
                }
                Card {
                    styleScope: "Bar"
                    visible: ["notch","dynamic","groups"].indexOf(barArea.mode) >= 0
                    anchors.centerIn: parent
                    width: barArea.mode === "dynamic" && islandHover.hovered ? 230 : Math.max(110, central.implicitWidth+12)
                    height: Math.min(38, barArea.height)
                    radius: barArea.mode === "notch" ? 10 : 22
                    Behavior on width { NumberAnimation { duration: root.motion; easing.type: Easing.OutCubic } }
                    
                }
                BarPill {
                    id: central
                    HoverHandler { id: islandHover }
                    anchors.centerIn: parent
                    text: barArea.mode === "dynamic" && islandHover.hovered ? Qt.formatDateTime(root.now, "hh:mm · d MMM") + (root.dnd ? " · DND" : "") : Qt.formatDateTime(root.now, "ddd  hh:mm")
                    onClicked: root.toggle("control")
                }
                Row {
                    id: rightBar
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 5
                    BarIconButton { visible: barArea.mode !== "minimal"; glyph: root.networkKind; detail: root.networkLabel; onClicked: root.toggle("control") }
                    BarIconButton { visible: prefs.showAudio && barArea.mode !== "minimal"; glyph: "audio"; label: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume*100) + "%" : ""; detail: "Volume"; onClicked: root.toggle("control") }
                    BarIconButton { visible: prefs.showNotifications && barArea.mode !== "minimal"; glyph: "bell"; label: notifications.trackedNotifications.values.length > 0 ? String(notifications.trackedNotifications.values.length) : ""; detail: "Notifications"; onClicked: root.toggle("notifications") }
                    BarIconButton { glyph: "settings"; detail: "Deyra Settings"; onClicked: root.toggle("settings") }
                }
            }
        }
    }
    PanelWindow {
        id: dockWindow
        readonly property bool labeled: root.layoutFor("Dock") === "labeled"
        visible: prefs.dockEnabled
        anchors.bottom: true
        margins.bottom: prefs.barBottom ? prefs.barHeight + 6 : 6
        implicitWidth: Math.min(screen ? screen.width - 20 : 700, dockRow.implicitWidth + 18)
        implicitHeight: dockWindow.labeled ? 76 : 58
        color: "transparent"
        Card {
            styleScope: "Dock"
            anchors.fill: parent
            Row {
                id: dockRow
                anchors.centerIn: parent
                spacing: 6
                Button {
                    width: 42; height: 42; onClicked: root.toggle("launcher")
                    background: Rectangle { radius: 12; color: parent.hovered ? root.tint(root.styleFor("Dock").bg,.15) : "transparent"; Behavior on color { ColorAnimation { duration: root.motion/2 } } }
                    contentItem: Item { ShellIcon { anchors.centerIn: parent; width: 21; height: 21; glyph: "search"; ink: root.styleFor("Dock").accent } }
                    ToolTip.visible: hovered; ToolTip.text: "Applications"
                }
                Repeater {
                    model: root.windows.slice(0, Math.max(1, Math.min(12, Math.floor(((dockWindow.screen ? dockWindow.screen.width : 700)-80)/(dockWindow.labeled ? 84 : 48)))))
                    delegate: Button {
                        id: dockEntry
                        required property var modelData
                        width: dockWindow.labeled ? 78 : 42; height: dockWindow.labeled ? 60 : 42
                        onClicked: modelData.activate()
                        background: Rectangle {
                            radius: 12; color: parent.hovered ? root.tint(root.styleFor("Dock").bg,.14) : "transparent"
                            Behavior on color { ColorAnimation { duration: root.motion/2 } }
                            Rectangle { anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 1 }; width: modelData.activated ? 16 : 4; height: 3; radius: 2; color: modelData.activated ? root.styleFor("Dock").accent : root.uiMuted; Behavior on width { NumberAnimation { duration: root.motion } } }
                        }
                        contentItem: ColumnLayout {
                            AppGlyph { imageSource: root.appIcon(modelData); fallbackText: modelData.title || modelData.appId || "?"; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 30; Layout.preferredHeight: 30; scale: dockEntry.hovered && !prefs.reduceMotion ? 1.13 : 1; Behavior on scale { NumberAnimation { duration: root.motion/2; easing.type: Easing.OutCubic } } }
                            Caption { deyraTextScope: "Dock"; visible: dockWindow.labeled; text: modelData.title; Layout.fillWidth: true; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 10 }
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: modelData.title
                    }
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
                DeyraSlider {
                    Layout.fillWidth: true
                    from: 0; to: 1
                    enabled: !!Pipewire.defaultAudioSink && !!Pipewire.defaultAudioSink.audio
                    value: enabled ? Pipewire.defaultAudioSink.audio.volume : 0
                    onMoved: if (enabled) Pipewire.defaultAudioSink.audio.volume = value
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
        visible: root.currentToast !== null && !root.dnd
        anchors { top: true; right: true }
        margins { top: prefs.barHeight + 8; right: 12 }
        implicitWidth: 330; implicitHeight: 85
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        Card {
            styleScope: "Notifications"
            anchors.fill: parent
            Column {
                anchors.fill: parent; anchors.margins: 12
                Caption { deyraTextScope: "Notifications"; width: parent.width; elide: Text.ElideRight; text: root.currentToast ? root.currentToast.summary : "" }
                Caption { deyraTextScope: "Notifications"; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; text: root.currentToast ? root.currentToast.body : "" }
            }
        }
    }
    PanelWindow {
        id: switcher
        readonly property bool radial: root.layoutFor("Window Switcher") === "radial"
        readonly property bool expanded: root.page === "switcher"
        property real reveal: expanded ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: root.motion; easing.type: Easing.OutCubic } }
        visible: expanded || reveal > .001
        implicitWidth: switcher.radial ? 390 : Math.min(screen ? screen.width - 24 : 740, Math.max(300, root.windows.length*54 + 32)); implicitHeight: switcher.radial ? 390 : 160
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
            Caption { deyraTextScope: "Window Switcher"; anchors.horizontalCenter: parent.horizontalCenter; y: switcher.radial ? (parent.height-height)/2 : parent.height-height-12; width: switcher.radial ? 130 : parent.width-32; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight; text: root.windows[root.selectedWindow] ? root.windows[root.selectedWindow].title : "No windows" }
            Repeater {
                model: root.windows.slice(0, 12)
                delegate: Button {
                    required property var modelData
                    required property int index
                    width: switcher.radial ? 48 : Math.min(48,(ring.width-20)/Math.max(1,root.windows.length)-4); height: 48
                    x: switcher.radial ? ring.width/2 - width/2 + 138*Math.cos(index*2*Math.PI/Math.min(root.windows.length,12)-Math.PI/2) : (ring.width - root.windows.length * Math.min(54,(ring.width-20)/Math.max(1,root.windows.length)))/2 + index * Math.min(54,(ring.width-20)/Math.max(1,root.windows.length))
                    y: switcher.radial ? ring.height/2 - height/2 + 138*Math.sin(index*2*Math.PI/Math.min(root.windows.length,12)-Math.PI/2) : 24
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
        WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"
        Shortcut { sequence: "Escape"; enabled: settings.expanded; onActivated: root.page = "" }
        ColorDialog {
            id: appearancePicker
            title: "Choose a custom color"
            onAccepted: root.setAppearance(root.colorScope, root.colorRole, selectedColor.toString())
        }
        FileDialog {
            id: localPicker
            title: "Choose wallpaper"
            nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
            onAccepted: prefs.wallpaper = selectedFile.toString()
        }
        FileDialog {
            id: avatarPicker
            title: "Choose avatar"
            nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
            onAccepted: prefs.avatar = selectedFile.toString()
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
                            delegate: NavButton { required property var modelData; Layout.fillWidth: true; text: modelData.name; glyph: modelData.glyph; selected: root.settingsTab === modelData.name; onClicked: root.settingsTab = modelData.name }
                        }
                        Item { Layout.preferredHeight: 15 }
                        Muted { text: "SYSTEM"; font.pixelSize: 10; font.letterSpacing: 1.2; Layout.leftMargin: 10 }
                        Repeater {
                            model: [{name:"Profile",glyph:"♙"},{name:"System",glyph:"⚙"},{name:"Performance",glyph:"↗"},{name:"Updates",glyph:"↻"}]
                            delegate: NavButton { required property var modelData; Layout.fillWidth: true; text: modelData.name; glyph: modelData.glyph; selected: root.settingsTab === modelData.name; onClicked: root.settingsTab = modelData.name }
                        }
                        Item { Layout.fillHeight: true }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.uiLine }
                        RowLayout {
                            Layout.fillWidth: true
                            Muted { text: "v0.2.0 alpha"; Layout.fillWidth: true }
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
        Component {
            id: themesPage
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
                        Pill { text: "Color picker"; onClicked: { appearancePicker.selectedColor = root.editorColor; appearancePicker.open() } }
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
                        model: ["Presets","Bar","Dock","Desktop Widgets","Launcher","Control Center","Lock Screen","Notifications","Window Switcher","Wallpapers"]
                        delegate: Pill { required property string modelData; text: modelData; deyraSelected: root.editTab === modelData; onClicked: root.editTab = modelData }
                    }
                }
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    sourceComponent: root.editTab === "Presets" ? presetsPage : root.editTab === "Wallpapers" ? wallpapersPage : root.editTab === "Bar" ? barPage : root.editTab === "Dock" ? dockPage : root.editTab === "Desktop Widgets" ? widgetsPage : root.editTab === "Notifications" ? notificationsPage : pendingPage
                }
            }
        }
        Component {
            id: presetsPage
            Section {
                RowLayout {
                    Caption { text: "Apply to:" }
                    DeyraCombo {
                        model: ["All"].concat(root.supportedScopes)
                        currentIndex: Math.max(0, model.indexOf(root.presetScope))
                        onActivated: root.presetScope = currentText
                        Layout.fillWidth: true
                    }
                    Pill { text: "Use global"; visible: root.presetScope !== "All"; onClicked: root.resetComponent(root.presetScope) }
                }
                Caption { text: "Selected: " + root.componentPreview(root.presetScope) + (root.presetScope === "All" ? "" : " · " + root.layoutFor(root.presetScope)); color: root.accent }
                GridView {
                    id: presetGrid
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; cellWidth: Math.max(190, width / 3); cellHeight: 144
                    model: root.presets
                    delegate: Rectangle {
                        id: presetCard
                        required property var modelData
                        width: presetGrid.cellWidth - 8; height: 136
                        radius: 13; color: "#202437"
                        border.width: 1
                        border.color: root.componentPreview(root.presetScope) === modelData.name ? root.accent : "#383e58"
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 32
                                color: Qt.alpha(modelData.bg, modelData.opacity); radius: modelData.radius / 2
                                Row {
                                    anchors.centerIn: parent; spacing: 6
                                    Repeater {
                                        model: [24, 46, 24]
                                        delegate: Rectangle {
                                            required property int modelData
                                            width: modelData; height: 16
                                            color: "#303449"; radius: 7
                                            border.color: presetCard.modelData.accent
                                        }
                                    }
                                }
                            }
                            Caption { text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                            Caption { text: modelData.author + " · " + root.layoutProfiles[modelData.name][0]; opacity: .7; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
                            RowLayout {
                                Pill { text: "Apply"; Layout.fillWidth: true; onClicked: root.applyPreset(modelData, root.presetScope) }
                                Pill { text: "Source"; onClicked: Qt.openUrlExternally(modelData.url) }
                            }
                        }
                    }
                }
                Caption { text: "Native layouts + styles, not full upstream ports."; opacity: .7; Layout.fillWidth: true; wrapMode: Text.Wrap }
            }
        }
        Component {
            id: barPage
            Section {
                Caption { text: "Bar position" }
                RowLayout {
                    Pill { text: "Top"; deyraSelected: !prefs.barBottom; onClicked: prefs.barBottom = false }
                    Pill { text: "Bottom"; deyraSelected: prefs.barBottom; onClicked: prefs.barBottom = true }
                }
                Caption { text: "Height" }
                DeyraSlider { Layout.fillWidth: true; from: 38; to: 60; stepSize: 1; value: prefs.barHeight; onMoved: prefs.barHeight = value }
                DeyraCheck { text: "Audio module"; checked: prefs.showAudio; onToggled: prefs.showAudio = checked }
                DeyraCheck { text: "Notifications module"; checked: prefs.showNotifications; onToggled: prefs.showNotifications = checked }
                Item { Layout.fillHeight: true }
            }
        }
        Component { id: dockPage; Section { DeyraCheck { text: "Show running applications dock"; checked: prefs.dockEnabled; onToggled: prefs.dockEnabled = checked } Item { Layout.fillHeight: true } } }
        Component { id: widgetsPage; Section { DeyraCheck { text: "Desktop clock"; checked: prefs.desktopClock; onToggled: prefs.desktopClock = checked } Item { Layout.fillHeight: true } } }
        Component { id: notificationsPage; Section { DeyraCheck { text: "Do not disturb"; checked: root.dnd; onToggled: root.dnd = checked } Item { Layout.fillHeight: true } } }
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
                    Pill { text: "Choose local image"; onClicked: localPicker.open() }
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
                Pill { text: "Choose avatar"; onClicked: avatarPicker.open() }
                Caption { text: root.systemInfo; Layout.fillWidth: true; wrapMode: Text.Wrap }
                Item { Layout.fillHeight: true }
            }
        }
        Component {
            id: systemPage
            Section {
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
        Component { id: updatesPage; Section { Caption { text: "Deyra Shell 0.2.0 alpha" } Caption { text: "Updates currently use git pull. Automatic updates are planned." ; wrapMode: Text.Wrap; Layout.fillWidth: true } Item { Layout.fillHeight: true } } }
    }
}
