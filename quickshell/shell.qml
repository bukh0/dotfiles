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
            }
        }
    }
}
