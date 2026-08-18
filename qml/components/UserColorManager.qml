pragma Singleton
import QtQuick 2.0
import Sailfish.Silica 1.0

/*
 * Gives every nick a stable color: the same person keeps the same color
 * across pages, meetings and app restarts.
 */
QtObject {
    property var userColorMap: ({})

    function getColorForUser(username) {
        if (username === "") return Theme.secondaryColor

        if (userColorMap[username] !== undefined) {
            return userColorMap[username]
        }

        var color = colorFromHash(hashOf(username))
        userColorMap[username] = color
        return color
    }

    // Small deterministic string hash (djb2 style, kept in 32 bits)
    function hashOf(text) {
        var hash = 0
        for (var i = 0; i < text.length; i++) {
            hash = ((hash << 5) - hash + text.charCodeAt(i)) | 0
        }
        return Math.abs(hash)
    }

    // Spread hues over the wheel, keep saturation and lightness in a band that
    // stays readable on both light and dark ambiences
    function colorFromHash(hash) {
        var hue = (hash % 360) / 360
        var saturation = 0.5 + ((hash >> 9) & 0xff) / 255 * 0.3
        var lightness = 0.45 + ((hash >> 17) & 0xff) / 255 * 0.2
        return Qt.hsla(hue, saturation, lightness, 1.0)
    }

    function resetColors() {
        userColorMap = {}
    }
}
