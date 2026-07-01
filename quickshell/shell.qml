import QtQuick
import Quickshell
import "./."

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Item {
                required property var modelData

                Bar {
                    id: bar
                    screen: modelData
                }

                NotificationDrawer {
                    anchor.window: bar
                    anchor.rect.x: bar.width - implicitWidth - 10
                    anchor.rect.y: bar.height + 6
                }
            }
        }
    }
}
