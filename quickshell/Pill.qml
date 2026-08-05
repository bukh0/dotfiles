// Pill.qml
import QtQuick
import QtQuick.Layouts

Rectangle {
    default property alias content: layout.data
    
    // Fallback sizing, will stretch to fit contents
    implicitHeight: 36
    implicitWidth: layout.implicitWidth + 32
    
    // Dark background matching the screenshot
    color: "#1e1e2e" // Adjust this to match your Colors.qml if you have a specific surface color
    
    // Fully rounded corners
    radius: height / 2 
    
    // Optional border for contrast
    border.color: "#313244"
    border.width: 1

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 8
    }
}
