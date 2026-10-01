import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: 8

    property string uiFont: Theme.fontUI
    property string iconFont: Theme.fontMono

    readonly property string cpuPercent: SysmonService.cpuPercent
    readonly property string ramPercent: SysmonService.ramPercent
    readonly property string rxSpeed: SysmonService.rxSpeed
    readonly property string txSpeed: SysmonService.txSpeed
    readonly property string powerProfile: SysmonService.powerProfile
    readonly property string cpuTemp: SysmonService.cpuTemp
    readonly property bool cpuHot: SysmonService.cpuHot
    readonly property string tooltipRam: SysmonService.tooltipRam
    readonly property string tooltipCpu: SysmonService.tooltipCpu
    readonly property string tooltipNet: SysmonService.tooltipNet
    readonly property string tooltipTemp: SysmonService.tooltipTemp
    readonly property string tooltipProfile: SysmonService.tooltipProfile

    component Stat: RowLayout {
        id: statRoot
        property string icon: ""
        property string value: ""
        property string tooltipText: ""
        property color textColor: Colors.surfaceFg

        Layout.minimumWidth: 0
        Layout.fillWidth: true

        spacing: 6

        Text {
            text: statRoot.icon
            color: statRoot.textColor
            font.pixelSize: 15; font.family: root.iconFont; font.weight: Font.Bold
        }
        Text {
            text: statRoot.value
            color: statRoot.textColor
            font.pixelSize: 12; font.family: root.uiFont; font.weight: Font.Bold

            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        HoverHandler { id: hoverHandler }

        ToolTip.visible: hoverHandler.hovered && statRoot.tooltipText !== ""
        ToolTip.text: statRoot.tooltipText
        ToolTip.delay: 300
        ToolTip.timeout: 2000
    }

    Stat {
        icon: "󰍛"
        value: root.cpuPercent
        tooltipText: root.tooltipCpu
        textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.8)
    }
    VDivider {}

    Stat {
        icon: "󰆼"
        value: root.ramPercent
        tooltipText: root.tooltipRam
        textColor: Colors.surfaceFg
    }
    VDivider {}

    Stat {
        icon: "󰔏"
        value: root.cpuTemp
        tooltipText: root.tooltipTemp
        textColor: root.cpuHot ? Colors.error : Colors.surfaceFg
    }
    VDivider {}

    Stat {
        icon: "󰁅"
        value: root.rxSpeed
        tooltipText: root.tooltipNet
        textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.65)
    }
    Stat {
        icon: "󰁝"
        value: root.txSpeed
        tooltipText: root.tooltipNet
        textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.65)
    }

    Item {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
    }

    RowLayout {
        Layout.alignment: Qt.AlignVCenter

        Text {
            id: profileText
            text: root.powerProfile === "powersave" ? "󰌪" : (root.powerProfile === "performance" ? "󰓅" : "󰗑")
            color: root.powerProfile === "performance"
                ? Colors.error
                : (root.powerProfile === "powersave" ? Colors.tertiary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.9))
            font.pixelSize: 18
            font.family: root.iconFont
            font.weight: Font.Bold

            HoverHandler { id: profileHover }

            ToolTip.visible: profileHover.hovered && root.tooltipProfile !== ""
            ToolTip.text: root.tooltipProfile
            ToolTip.delay: 300
            ToolTip.timeout: 2000

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (profileProc.running) return
                    profileProc.command = ["bash", "-c", "exec \"$HOME/.scripts/toggle-performance.sh\""]
                    profileProc.running = true
                }
            }
        }
    }

    Process {
        id: profileProc
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim()
                if (msg.length > 0) console.warn("power profile:", msg)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached(["notify-send", "-a", "Power Profile", "--",
                    "Power profile change failed", "Exit status " + exitCode])
            }
        }
    }
}
