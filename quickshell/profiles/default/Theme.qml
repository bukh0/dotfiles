pragma Singleton
import QtQuick
import Quickshell

BaseTheme {
    readonly property string sysmonPath: Quickshell.shellPath("../../native/sysmon")
}
