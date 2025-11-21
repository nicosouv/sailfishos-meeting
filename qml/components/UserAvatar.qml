import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

Item {
    id: root

    property string username: ""
    property color userColor: UserColorManager.getColorForUser(username)

    width: Theme.iconSizeSmall + Theme.paddingSmall
    height: Theme.iconSizeSmall + Theme.paddingSmall

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: userColor

        Label {
            anchors.centerIn: parent
            text: username.length > 0 ? username.charAt(0).toUpperCase() : ""
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
            color: "white"
        }
    }
}
