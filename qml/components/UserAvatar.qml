import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: root

    property string username: ""
    property color userColor: calculateColor(username)

    width: Theme.iconSizeSmall
    height: Theme.iconSizeSmall

    function calculateColor(name) {
        if (name === "") return Theme.secondaryColor

        // Hash the username to generate a color
        var hash = 0
        for (var i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash)
        }

        // Convert to HSL color with fixed saturation and lightness for consistent appearance
        var hue = Math.abs(hash % 360)

        // Use HSL to RGB conversion for better color distribution
        return Qt.hsla(hue / 360, 0.6, 0.5, 1.0)
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: userColor

        Label {
            anchors.centerIn: parent
            text: username.length > 0 ? username.charAt(0).toUpperCase() : ""
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            color: "white"
        }
    }
}
