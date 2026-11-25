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
    property var selectedOnline: null
    property int selectedWindow: 0
    property var windows: ToplevelManager.toplevels.values
    property var now: new Date()
    property color accent: prefs.accent
    property color surface: Qt.rgba(15/255,17/255,30/255,prefs.opacity)
    property color foreground: "#eef2ff"
    property string configPath: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    property string statePath: configPath + "/deyra-shell"
    property var currentToast: null
    property bool dnd: false
    property string systemInfo: ""
    property string profileName: Quickshell.env("USER") || "User"
    property string[] presetNames: ["TQQ Rice", "Noctalia", "DankMaterialShell", "Caelestia", "Illogical Impulse", "HyDE", "ML4W", "iNiR", "DotFriedRice", "Ambxst", "DarkShadow", "Serpantinum"]

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
        if (download.running || !w || !/^https:\/\/w\.wallhaven\.cc\/full\//.test(w.path)) return
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
            property real opacity: 0.91
            property int radius: 17
            property int barHeight: 42
            property bool barBottom: false
            property bool dockEnabled: true
            property bool desktopClock: false
            property bool animations: true
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
        color: root.foreground
        font.family: "JetBrains Mono"
        font.pixelSize: 13
        textFormat: Text.PlainText
    }
    component Pill: Button {
        id: button
        property bool highlighted: false
        implicitHeight: 34
        implicitWidth: Math.max(42, contentItem.implicitWidth + 24)
        padding: 10
        contentItem: Caption {
            text: button.text
            color: button.highlighted ? root.accent : root.foreground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: prefs.radius
            color: button.hovered || button.highlighted ? "#292d46" : root.surface
            border.color: root.accent
            border.width: 1
        }
    }
    component Card: Rectangle {
        color: root.surface
        radius: prefs.radius
        border.color: root.accent
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
            Image { anchors.fill: parent; source: prefs.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; sourceSize.width: parent.width * 2 }
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
            required property var modelData
            screen: modelData
            anchors { top: !prefs.barBottom; bottom: prefs.barBottom; left: true; right: true }
            implicitHeight: prefs.barHeight
            color: "transparent"
            Row {
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 6
                Pill { text: "⌕"; highlighted: true; onClicked: root.toggle("launcher") }
                Pill { text: "Deyra"; onClicked: root.toggle("settings") }
            }
            Pill {
                anchors.centerIn: parent
                text: Qt.formatDateTime(root.now, "ddd  hh:mm")
                onClicked: root.toggle("control")
            }
            Row {
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 6
                Pill { visible: prefs.showAudio; text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? "Vol " + Math.round(Pipewire.defaultAudioSink.audio.volume*100) + "%" : "Audio"; onClicked: root.toggle("control") }
                Pill { visible: prefs.showNotifications; text: "Alerts " + notifications.trackedNotifications.values.length; onClicked: root.toggle("notifications") }
                Pill { text: "⚙"; onClicked: root.toggle("settings") }
            }
        }
    }
    PanelWindow {
        visible: prefs.dockEnabled
        anchors.bottom: true
        margins.bottom: prefs.barBottom ? prefs.barHeight + 6 : 6
        implicitWidth: Math.min(screen ? screen.width - 20 : 700, dockRow.implicitWidth + 18)
        implicitHeight: 58
        color: "transparent"
        Card {
            anchors.fill: parent
            Row {
                id: dockRow
                anchors.centerIn: parent
                spacing: 6
                Pill { text: "⌕"; onClicked: root.toggle("launcher") }
                Repeater {
                    model: root.windows.slice(0, 12)
                    delegate: Button {
                        required property var modelData
                        width: 42; height: 42
                        onClicked: modelData.activate()
                        background: Rectangle { radius: 12; color: parent.hovered ? "#343854" : "transparent"; border.width: modelData.activated ? 1 : 0; border.color: root.accent }
                        contentItem: Image { source: root.appIcon(modelData); fillMode: Image.PreserveAspectFit; sourceSize.width: 32; sourceSize.height: 32 }
                        ToolTip.visible: hovered
                        ToolTip.text: modelData.title
                    }
                }
            }
        }
    }
    PanelWindow {
        id: launcher
        visible: root.page === "launcher"
        anchors { top: !prefs.barBottom; bottom: prefs.barBottom; left: true }
        margins { top: prefs.barHeight + 8; bottom: prefs.barHeight + 8; left: 12 }
        implicitWidth: Math.min(440, screen ? screen.width - 24 : 440)
        implicitHeight: 460
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onVisibleChanged: if (visible) { query.text = ""; query.forceActiveFocus() }
        Card {
            anchors.fill: parent
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16
                TextField { id: query; Layout.fillWidth: true; placeholderText: "Search applications"; color: root.foreground; Keys.onEscapePressed: root.page = ""; onAccepted: { if (apps.count > 0) { apps.model[0].execute(); root.page = "" } } }
                ListView {
                    id: apps
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 5
                    model: DesktopEntries.applications.values.filter(function(a) { return !a.noDisplay && (a.name + " " + a.genericName).toLowerCase().indexOf(query.text.toLowerCase()) >= 0 }).sort(function(a,b) { return a.name.localeCompare(b.name) })
                    delegate: Button {
                        required property var modelData
                        width: ListView.view.width; height: 44
                        onClicked: { modelData.execute(); root.page = "" }
                        background: Rectangle { radius: 12; color: parent.hovered ? "#343854" : "#1c2033" }
                        contentItem: RowLayout {
                            Image { source: Quickshell.iconPath(modelData.icon || "application-x-executable"); Layout.preferredWidth: 28; Layout.preferredHeight: 28; fillMode: Image.PreserveAspectFit }
                            Caption { text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }
    }
    PanelWindow {
        visible: root.page === "control"
        anchors { top: !prefs.barBottom; bottom: prefs.barBottom }
        margins { top: prefs.barHeight + 8; bottom: prefs.barHeight + 8 }
        implicitWidth: Math.min(620, screen ? screen.width - 24 : 620)
        implicitHeight: 320
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        Card {
            anchors.fill: parent
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                RowLayout {
                    Caption { text: Qt.formatTime(root.now, "hh:mm"); font.pixelSize: 42; Layout.fillWidth: true }
                    Pill { text: "Settings"; onClicked: root.showSettings("System") }
                    Pill { text: "×"; onClicked: root.page = "" }
                }
                Caption { text: Qt.formatDate(root.now, "dddd, d MMMM yyyy") }
                Caption { text: "Volume" }
                Slider {
                    Layout.fillWidth: true
                    from: 0; to: 1
                    enabled: !!Pipewire.defaultAudioSink && !!Pipewire.defaultAudioSink.audio
                    value: enabled ? Pipewire.defaultAudioSink.audio.volume : 0
                    onMoved: if (enabled) Pipewire.defaultAudioSink.audio.volume = value
                }
                RowLayout {
                    Pill { text: root.dnd ? "DND on" : "DND off"; onClicked: root.dnd = !root.dnd }
                    Pill { text: "Brightness −"; onClicked: Quickshell.execDetached(["brightnessctl", "set", "5%-"]) }
                    Pill { text: "Brightness +"; onClicked: Quickshell.execDetached(["brightnessctl", "set", "+5%"]) }
                }
                RowLayout {
                    Pill { text: "Wallpapers"; onClicked: root.showWallpapers() }
                    Pill { text: "Notifications"; onClicked: root.toggle("notifications") }
                    Pill { text: "Lock"; onClicked: { root.page = ""; Quickshell.execDetached(["loginctl","lock-session"]) } }
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
            anchors.fill: parent
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14
                RowLayout { Caption { text: "Notifications"; Layout.fillWidth: true; font.pixelSize: 18 } Pill { text: "×"; onClicked: root.page = "" } }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    model: notifications.trackedNotifications
                    delegate: ItemDelegate {
                        required property var modelData
                        width: ListView.view.width
                        onClicked: modelData.dismiss()
                        contentItem: Column {
                            Caption { text: modelData.appName + " · " + modelData.summary; width: parent.width; elide: Text.ElideRight }
                            Caption { text: modelData.body; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight }
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
            anchors.fill: parent
            Column {
                anchors.fill: parent; anchors.margins: 12
                Caption { width: parent.width; elide: Text.ElideRight; text: root.currentToast ? root.currentToast.summary : "" }
                Caption { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; text: root.currentToast ? root.currentToast.body : "" }
            }
        }
    }
    PanelWindow {
        id: switcher
        visible: root.page === "switcher"
        implicitWidth: 390; implicitHeight: 390
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onVisibleChanged: if (visible) ring.forceActiveFocus()
        Card {
            id: ring
            anchors.fill: parent; radius: width/2; focus: true
            Keys.onEscapePressed: root.page = ""
            Keys.onTabPressed: function(event) { if(root.windows.length) root.selectedWindow = (root.selectedWindow + ((event.modifiers & Qt.ShiftModifier) ? root.windows.length - 1 : 1)) % root.windows.length; event.accepted = true }
            Keys.onBacktabPressed: if(root.windows.length) root.selectedWindow = (root.selectedWindow + root.windows.length - 1) % root.windows.length
            Keys.onReturnPressed: root.confirmWindow()
            Keys.onReleased: function(event) { if(event.key === Qt.Key_Alt) root.confirmWindow() }
            Caption { anchors.centerIn: parent; width: 130; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight; text: root.windows[root.selectedWindow] ? root.windows[root.selectedWindow].title : "No windows" }
            Repeater {
                model: root.windows.slice(0, 12)
                delegate: Button {
                    required property var modelData
                    required property int index
                    width: 48; height: 48
                    x: ring.width/2 - width/2 + 138*Math.cos(index*2*Math.PI/Math.min(root.windows.length,12)-Math.PI/2)
                    y: ring.height/2 - height/2 + 138*Math.sin(index*2*Math.PI/Math.min(root.windows.length,12)-Math.PI/2)
                    onClicked: { root.selectedWindow = index; root.confirmWindow() }
                    background: Rectangle { radius: 24; color: index === root.selectedWindow ? "#3d4263" : "#22263c"; border.width: 2; border.color: index === root.selectedWindow ? root.accent : "transparent" }
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
                    Caption { text: "Shell  /  0.1 alpha"; opacity: .7 }
                    Repeater {
                        model: ["Themes","Edit Mode","Community","Profile","System","Performance","Updates"]
                        delegate: Pill { required property string modelData; Layout.fillWidth: true; text: modelData; highlighted: root.settingsTab === modelData; onClicked: root.settingsTab = modelData }
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
        component Section: ColumnLayout { spacing: 12 }
        Component {
            id: themesPage
            Section {
                Caption { text: "Deyra Default · inspired by TQQ Rice"; font.pixelSize: 17 }
                Flow {
                    Layout.fillWidth: true; spacing: 12
                    Repeater {
                        model: ["#a38ff7","#ffb4a2","#8bd5ca","#8aadf4","#d9c3a5"]
                        delegate: Rectangle {
                            required property string modelData
                            width: 76; height: 76; radius: 18; color: modelData
                            border.width: prefs.accent === modelData ? 4 : 0; border.color: "white"
                            MouseArea { anchors.fill: parent; onClicked: prefs.accent = modelData }
                        }
                    }
                }
                Caption { text: "Panel opacity" }
                Slider { Layout.fillWidth: true; from: .45; to: 1; value: prefs.opacity; onMoved: prefs.opacity = value }
                Caption { text: "Corner radius" }
                Slider { Layout.fillWidth: true; from: 0; to: 28; stepSize: 1; value: prefs.radius; onMoved: prefs.radius = value }
                Item { Layout.fillHeight: true }
            }
        }
        Component {
            id: editPage
            Section {
                Flow {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: ["Bar","Dock","Desktop Widgets","Launcher","Control Center","Lock Screen","Notifications","Window Switcher","Wallpapers"]
                        delegate: Pill { required property string modelData; text: modelData; highlighted: root.editTab === modelData; onClicked: root.editTab = modelData }
                    }
                }
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    sourceComponent: root.editTab === "Wallpapers" ? wallpapersPage : root.editTab === "Bar" ? barPage : root.editTab === "Dock" ? dockPage : root.editTab === "Desktop Widgets" ? widgetsPage : root.editTab === "Notifications" ? notificationsPage : pendingPage
                }
            }
        }
        Component {
            id: barPage
            Section {
                Caption { text: "Bar position" }
                RowLayout {
                    Pill { text: "Top"; highlighted: !prefs.barBottom; onClicked: prefs.barBottom = false }
                    Pill { text: "Bottom"; highlighted: prefs.barBottom; onClicked: prefs.barBottom = true }
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
                        delegate: Pill { required property string modelData; text: modelData; highlighted: root.wallpaperTab === modelData; onClicked: root.wallpaperTab = modelData }
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
                Caption { text: "Preset roadmap · not installed or copied"; font.pixelSize: 17 }
                Flow { Layout.fillWidth: true; spacing: 7; Repeater { model: root.presetNames; delegate: Pill { required property string modelData; text: modelData; enabled: false } } }
                Caption { text: "Author and license review required before integration."; Layout.fillWidth: true; wrapMode: Text.Wrap }
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
        Component { id: updatesPage; Section { Caption { text: "Deyra Shell 0.1 alpha" } Caption { text: "Updates currently use git pull. Automatic updates are planned." ; wrapMode: Text.Wrap; Layout.fillWidth: true } Item { Layout.fillHeight: true } } }
    }
}
