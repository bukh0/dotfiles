import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: rootPill
    default property alias content: layout.data
    
    property bool isActive: false
    property bool isHovered: false
    
    implicitHeight: 32 
    implicitWidth: layout.implicitWidth + 24 
    
    radius: height / 2.5 
    
    color: isActive ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
                    : isHovered ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.9)
                    : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.85)
                    
    border.color: isActive ? Colors.primary : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.5)
    border.width: 1
    
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 12
    }
}
