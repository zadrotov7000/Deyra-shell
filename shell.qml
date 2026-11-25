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
    property color accent: prefs.accent
    property color surface: Qt.alpha(prefs.background, prefs.opacity)
    property color foreground: "#eef2ff"
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
        return app && app.icon ? Quickshell.iconPath(app.icon) : Quickshell.iconPath("application-x-executable")
    }
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

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
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

    component Caption: Text {
        property string deyraTextScope: ""
        color: deyraTextScope === "" ? root.foreground : root.contrastingText(root.styleFor(deyraTextScope).bg)
        font.family: "JetBrains Mono"
        font.pixelSize: 13
        textFormat: Text.PlainText
    }
    component Pill: Button {
        id: button
        property bool deyraSelected: false
        property string styleScope: ""
        property bool deyraFlat: false
        readonly property var deyraStyle: root.styleFor(styleScope)
        implicitHeight: 34
        implicitWidth: Math.max(42, contentItem.implicitWidth + 24)
        padding: 10
        contentItem: Caption {
            text: button.text
            color: button.deyraSelected ? button.deyraStyle.accent : root.contrastingText(button.deyraStyle.bg)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: button.deyraStyle.radius
            color: button.hovered || button.deyraSelected ? Qt.lighter(button.deyraStyle.bg, 1.45) : button.deyraFlat ? "transparent" : Qt.alpha(button.deyraStyle.bg, button.deyraStyle.opacity)
            border.color: button.deyraStyle.accent
            border.width: button.deyraFlat ? 0 : 1
        }
    }
    component Section: ColumnLayout { spacing: 12 }
    component BarPill: Pill { styleScope: "Bar"; deyraFlat: root.layoutFor("Bar") !== "islands" }
    component Card: Rectangle {
        property string styleScope: ""
        readonly property var deyraStyle: root.styleFor(styleScope)
        color: Qt.alpha(deyraStyle.bg, deyraStyle.opacity)
        radius: deyraStyle.radius
        border.color: deyraStyle.accent
        border.width: 1
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
                    BarPill { text: "⌕"; deyraSelected: true; onClicked: root.toggle("launcher") }
                    BarPill { visible: barArea.mode !== "minimal" && barArea.mode !== "dynamic"; text: "Deyra"; onClicked: root.toggle("settings") }
                    Caption { visible: barArea.mode === "minimal"; anchors.verticalCenter: parent.verticalCenter; width: Math.min(170, barArea.width/5); elide: Text.ElideRight; text: root.windows.length ? root.windows[0].title : "Desktop" }
                }
                Card {
                    styleScope: "Bar"
                    visible: ["notch","dynamic","groups"].indexOf(barArea.mode) >= 0
                    anchors.centerIn: parent
                    width: barArea.mode === "dynamic" && islandHover.hovered ? 230 : Math.max(110, central.implicitWidth+12)
                    height: Math.min(38, barArea.height)
                    radius: barArea.mode === "notch" ? 10 : 22
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    
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
                    BarPill { visible: prefs.showAudio && barArea.mode !== "minimal"; text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? "Vol " + Math.round(Pipewire.defaultAudioSink.audio.volume*100) + "%" : "Audio"; onClicked: root.toggle("control") }
                    BarPill { visible: prefs.showNotifications && barArea.mode !== "minimal"; text: "Alerts " + notifications.trackedNotifications.values.length; onClicked: root.toggle("notifications") }
                    BarPill { text: "⚙"; onClicked: root.toggle("settings") }
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
                Pill { styleScope: "Dock"; text: "⌕"; onClicked: root.toggle("launcher") }
                Repeater {
                    model: root.windows.slice(0, Math.max(1, Math.min(12, Math.floor(((dockWindow.screen ? dockWindow.screen.width : 700)-80)/(dockWindow.labeled ? 84 : 48)))))
                    delegate: Button {
                        required property var modelData
                        width: dockWindow.labeled ? 78 : 42; height: dockWindow.labeled ? 60 : 42
                        onClicked: modelData.activate()
                        background: Rectangle { radius: 12; color: parent.hovered ? "#343854" : "transparent"; border.width: modelData.activated ? 1 : 0; border.color: root.styleFor("Dock").accent }
                        contentItem: ColumnLayout {
                            Image { source: root.appIcon(modelData); fillMode: Image.PreserveAspectFit; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 30; Layout.preferredHeight: 30 }
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
        visible: root.page === "launcher"
        anchors { top: mode === "list-left" && !prefs.barBottom; bottom: mode === "list-left" && prefs.barBottom; left: mode === "list-left" }
        margins { top: prefs.barHeight + 8; bottom: prefs.barHeight + 8; left: 12 }
        implicitWidth: Math.min(mode === "grid-wide" ? 760 : grid ? 600 : 440, screen ? screen.width - 24 : 760)
        implicitHeight: grid ? 510 : 460
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onVisibleChanged: if (visible) { query.text = ""; query.forceActiveFocus() }
        function launch(app) { if (app) { app.execute(); root.page = "" } }
        Card {
            styleScope: "Launcher"
            anchors.fill: parent
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16
                RowLayout {
                    Caption { deyraTextScope: "Launcher"; text: launcher.grid ? "Applications" : "Launcher"; font.pixelSize: 20; Layout.fillWidth: true }
                    Pill { styleScope: "Launcher"; text: "×"; onClicked: root.page = "" }
                }
                TextField { id: query; Layout.fillWidth: true; placeholderText: "Search applications"; color: root.foreground; Keys.onEscapePressed: root.page = ""; onAccepted: launcher.launch(launcher.matches[0]) }
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
                        Image { source: Quickshell.iconPath(modelData.icon || "application-x-executable"); Layout.preferredWidth: 28; Layout.preferredHeight: 28; fillMode: Image.PreserveAspectFit }
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
                        Image { source: Quickshell.iconPath(modelData.icon || "application-x-executable"); Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 40; Layout.preferredHeight: 40; fillMode: Image.PreserveAspectFit }
                        Caption { deyraTextScope: "Launcher"; text: modelData.name; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.pixelSize: 11 }
                    }
                }
            }
        }
    }
    PanelWindow {
        id: controlWindow
        readonly property string mode: root.layoutFor("Control Center")
        visible: root.page === "control"
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
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                RowLayout {
                    Caption { deyraTextScope: "Control Center"; text: Qt.formatTime(root.now, "hh:mm"); font.pixelSize: 42; Layout.fillWidth: true }
                    Pill { styleScope: "Control Center"; text: "Settings"; onClicked: root.showSettings("System") }
                    Pill { styleScope: "Control Center"; text: "×"; onClicked: root.page = "" }
                }
                Caption { deyraTextScope: "Control Center"; text: Qt.formatDate(root.now, "dddd, d MMMM yyyy") }
                Caption { deyraTextScope: "Control Center"; text: "Volume" }
                Slider {
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
                    Pill { styleScope: "Control Center"; text: "Lock (planned)"; enabled: false }
                }
            }
        }
    }
    PanelWindow {
        visible: root.page === "notifications"
        anchors { top: !prefs.barBottom; bottom: prefs.barBottom; right: true }
        margins { top: prefs.barHeight + 8; bottom: prefs.barHeight + 8; right: 12 }
        implicitWidth: 360; implicitHeight: 380
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        Card {
            styleScope: "Notifications"
            anchors.fill: parent
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
        visible: root.page === "switcher"
        implicitWidth: switcher.radial ? 390 : Math.min(screen ? screen.width - 24 : 740, Math.max(300, root.windows.length*54 + 32)); implicitHeight: switcher.radial ? 390 : 160
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onVisibleChanged: if (visible) ring.forceActiveFocus()
        Card {
            styleScope: "Window Switcher"
            id: ring
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
                    contentItem: Image { source: root.appIcon(modelData); fillMode: Image.PreserveAspectFit; sourceSize.width: 32; sourceSize.height: 32 }
                }
            }
        }
    }

    FloatingWindow {
        id: settings
        visible: root.page === "settings"
        title: "Deyra Settings"
        implicitWidth: 900; implicitHeight: 570
        color: "#10121e"
        onVisibleChanged: if (!visible && root.page === "settings") root.page = ""
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
        RowLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 16
            Card {
                Layout.preferredWidth: 184; Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Caption { text: "DEYRA"; color: root.accent; font.pixelSize: 24 }
                    Caption { text: "Shell  /  0.1.3 alpha"; opacity: .7 }
                    Repeater {
                        model: ["Themes","Edit Mode","Community","Profile","System","Performance","Updates"]
                        delegate: Pill { required property string modelData; Layout.fillWidth: true; text: modelData; deyraSelected: root.settingsTab === modelData; onClicked: root.settingsTab = modelData }
                    }
                    Item { Layout.fillHeight: true }
                    Pill { text: "Close"; Layout.fillWidth: true; onClicked: root.page = "" }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                Caption { text: root.settingsTab; font.pixelSize: 25 }
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    sourceComponent: root.settingsTab === "Themes" ? themesPage : root.settingsTab === "Edit Mode" ? editPage : root.settingsTab === "Community" ? communityPage : root.settingsTab === "Profile" ? profilePage : root.settingsTab === "System" ? systemPage : root.settingsTab === "Performance" ? performancePage : updatesPage
                }
                Caption { text: root.status; color: root.accent; Layout.fillWidth: true; elide: Text.ElideRight }
            }
        }
        Component {
            id: themesPage
            ScrollView {
                id: themeScroll
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: themeScroll.availableWidth
                    spacing: 12
                    Caption { text: "Appearance"; font.pixelSize: 20 }
                    RowLayout {
                        Layout.fillWidth: true
                        Caption { text: "Preset: " + prefs.activePreset; Layout.fillWidth: true; elide: Text.ElideRight }
                        Pill { text: "Browse 12 presets"; onClicked: { root.editTab = "Presets"; root.settingsTab = "Edit Mode" } }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Caption { text: "Customize" }
                        ComboBox {
                            Layout.fillWidth: true
                            model: ["All"].concat(root.supportedScopes)
                            currentIndex: Math.max(0, model.indexOf(root.colorScope))
                            onActivated: root.colorScope = currentText
                        }
                        Pill { text: "Inherit"; visible: root.colorScope !== "All"; onClicked: root.resetComponent(root.colorScope) }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 78
                        radius: root.editorStyle.radius
                        color: Qt.alpha(root.editorStyle.bg, root.editorStyle.opacity)
                        border.width: 2; border.color: root.editorStyle.accent
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
                        TextField {
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
                    Caption { text: "80 color swatches · choose any color"; opacity: .8 }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: 5
                        Repeater {
                            model: root.colorSwatches
                            delegate: Rectangle {
                                id: swatch
                                required property string modelData
                                width: 34; height: 34; radius: 8; color: modelData
                                border.width: root.editorColor.toLowerCase() === modelData ? 3 : 1
                                border.color: root.editorColor.toLowerCase() === modelData ? root.contrastingText(modelData) : "#777f95"
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
                    Slider { Layout.fillWidth: true; from: .45; to: 1; value: root.editorStyle.opacity; onMoved: root.setAppearance(root.colorScope, "opacity", value) }
                    RowLayout {
                        Caption { text: "Corner radius"; Layout.fillWidth: true }
                        Caption { text: root.editorStyle.radius + " px"; color: root.accent }
                    }
                    Slider { Layout.fillWidth: true; from: 0; to: 40; stepSize: 1; value: root.editorStyle.radius; onMoved: root.setAppearance(root.colorScope, "radius", value) }
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
                    ComboBox {
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
                Slider { Layout.fillWidth: true; from: 38; to: 60; stepSize: 1; value: prefs.barHeight; onMoved: prefs.barHeight = value }
                CheckBox { text: "Audio module"; checked: prefs.showAudio; onToggled: prefs.showAudio = checked }
                CheckBox { text: "Notifications module"; checked: prefs.showNotifications; onToggled: prefs.showNotifications = checked }
                Item { Layout.fillHeight: true }
            }
        }
        Component { id: dockPage; Section { CheckBox { text: "Show running applications dock"; checked: prefs.dockEnabled; onToggled: prefs.dockEnabled = checked } Item { Layout.fillHeight: true } } }
        Component { id: widgetsPage; Section { CheckBox { text: "Desktop clock"; checked: prefs.desktopClock; onToggled: prefs.desktopClock = checked } Item { Layout.fillHeight: true } } }
        Component { id: notificationsPage; Section { CheckBox { text: "Do not disturb"; checked: root.dnd; onToggled: root.dnd = checked } Item { Layout.fillHeight: true } } }
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
                Caption { text: "Lightweight static wallpaper renderer" }
                Caption { text: "Animated wallpapers and adaptive performance modes are planned." ; wrapMode: Text.Wrap; Layout.fillWidth: true }
                CheckBox { text: "Disable desktop clock"; checked: !prefs.desktopClock; onToggled: prefs.desktopClock = !checked }
                Item { Layout.fillHeight: true }
            }
        }
        Component { id: updatesPage; Section { Caption { text: "Deyra Shell 0.1.3 alpha" } Caption { text: "Updates currently use git pull. Automatic updates are planned." ; wrapMode: Text.Wrap; Layout.fillWidth: true } Item { Layout.fillHeight: true } } }
    }
}
