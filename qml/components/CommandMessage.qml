import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "TextMarkup.js" as TextMarkup

/*
 * Renders a meetbot command (#info, #topic, #action...) in the style picked
 * by the user in the settings:
 *   0 Card     rounded tinted card with an icon
 *   1 Banner   full width block between two separators
 *   2 Compact  a single inline line
 *   3 Quote    indented text behind a colored bar
 */
Item {
    id: root

    property var message
    property int style: 0
    // Search term to point out inside the message
    property string highlight: ""

    signal nickClicked(string name)

    readonly property string command: message && message.command ? message.command : ""
    readonly property string quotedNick: message && message.quotedNick ? message.quotedNick : ""
    readonly property bool isJolla: message ? message.isJolla === true : false
    readonly property bool isTopic: message ? message.isTopic === true : false
    readonly property string bodyText: message
        ? TextMarkup.markMatches(message.richBody, highlight, Theme.highlightColor)
        : ""
    readonly property string timestamp: message ? message.timestamp : ""

    readonly property color accentColor: {
        switch (command) {
        case "topic":
        case "subtopic": return Theme.highlightColor
        case "action": return "#e8a33d"
        case "agreed":
        case "accepted": return "#5cb85c"
        case "rejected": return Theme.errorColor
        case "idea":
        case "help":
        case "halp": return "#a06bd4"
        case "link": return "#4a9ede"
        default: return Theme.secondaryHighlightColor
        }
    }

    readonly property color nickColor: {
        if (isJolla) return Theme.highlightColor
        if (quotedNick !== "") return UserColorManager.getColorForUser(quotedNick)
        return accentColor
    }

    // Text drawn on top of a filled accent badge
    readonly property color badgeTextColor: Theme.colorScheme === Theme.LightOnDark ? "black" : "white"

    readonly property string iconSource: {
        switch (command) {
        case "topic":
        case "subtopic": return "image://theme/icon-m-events"
        case "link": return "image://theme/icon-m-link"
        case "action": return "image://theme/icon-m-add"
        case "agreed":
        case "accepted": return "image://theme/icon-m-accept"
        case "rejected": return "image://theme/icon-m-dismiss"
        case "idea":
        case "help":
        case "halp": return "image://theme/icon-m-question"
        case "info": return "image://theme/icon-m-about"
        default: return "image://theme/icon-m-note"
        }
    }

    // Compact styles put everything on a single styled text line
    readonly property string inlineText: {
        var out = "<font color=\"" + accentColor + "\">#" + command + "</font> "
        if (quotedNick !== "") {
            out += "<font color=\"" + nickColor + "\"><b>" + quotedNick + ":</b></font> "
        }
        return out + bodyText
    }

    height: styleLoader.item ? styleLoader.item.height : 0

    Loader {
        id: styleLoader
        width: root.width
        sourceComponent: {
            if (!root.message) return null
            switch (root.style) {
            case 1: return bannerStyle
            case 2: return compactStyle
            case 3: return quoteStyle
            default: return cardStyle
            }
        }
    }

    // Nick badge shared by the card and banner styles
    Component {
        id: nickBadge

        Rectangle {
            width: badgeLabel.width + Theme.paddingMedium
            height: badgeLabel.height + Theme.paddingSmall
            radius: Theme.paddingSmall
            color: root.isJolla ? root.nickColor : Theme.rgba(root.nickColor, 0.2)
            border.width: root.isJolla ? 0 : 1
            border.color: root.nickColor

            Label {
                id: badgeLabel
                anchors.centerIn: parent
                text: root.quotedNick
                font.pixelSize: Theme.fontSizeExtraSmall
                font.bold: true
                color: root.isJolla ? root.badgeTextColor : root.nickColor
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.nickClicked(root.quotedNick)
            }
        }
    }

    Component {
        id: cardStyle

        Item {
            width: styleLoader.width
            height: card.height + Theme.paddingMedium

            Rectangle {
                id: card
                x: Theme.horizontalPageMargin
                y: Theme.paddingSmall
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: cardRow.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(root.accentColor, 0.13)

                Rectangle {
                    width: Math.round(Theme.paddingSmall / 2)
                    height: parent.height
                    radius: width / 2
                    color: root.accentColor
                }

                Row {
                    id: cardRow
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - Theme.paddingMedium * 2
                    spacing: Theme.paddingMedium

                    Image {
                        id: cardIcon
                        width: Theme.iconSizeSmall
                        height: Theme.iconSizeSmall
                        source: root.iconSource
                        opacity: 0.8
                    }

                    Column {
                        width: parent.width - cardIcon.width - Theme.paddingMedium
                        spacing: Theme.paddingSmall

                        Row {
                            spacing: Theme.paddingMedium

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.command.toUpperCase()
                                font.pixelSize: Theme.fontSizeExtraSmall
                                font.bold: true
                                color: root.accentColor
                            }

                            Loader {
                                anchors.verticalCenter: parent.verticalCenter
                                active: root.quotedNick !== ""
                                sourceComponent: root.quotedNick !== "" ? nickBadge : null
                            }
                        }

                        Label {
                            width: parent.width
                            text: root.bodyText
                            font.pixelSize: root.isTopic ? Theme.fontSizeMedium : Theme.fontSizeSmall
                            font.bold: root.isTopic
                            color: Theme.primaryColor
                            linkColor: Theme.highlightColor
                            wrapMode: Text.Wrap
                            textFormat: Text.StyledText
                            onLinkActivated: Qt.openUrlExternally(link)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: bannerStyle

        Column {
            width: styleLoader.width

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.secondaryColor
                opacity: 0.15
            }

            Item { width: 1; height: Theme.paddingMedium }

            Row {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                spacing: Theme.paddingMedium

                Image {
                    id: bannerIcon
                    width: Theme.iconSizeSmall
                    height: Theme.iconSizeSmall
                    source: root.iconSource
                }

                Column {
                    width: parent.width - bannerIcon.width - Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Loader {
                        active: root.quotedNick !== ""
                        sourceComponent: root.quotedNick !== "" ? nickBadge : null
                    }

                    Label {
                        width: parent.width
                        text: root.bodyText
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        color: root.quotedNick !== "" ? Theme.primaryColor : root.accentColor
                        linkColor: Theme.highlightColor
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        onLinkActivated: Qt.openUrlExternally(link)
                    }
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.secondaryColor
                opacity: 0.15
            }
        }
    }

    Component {
        id: compactStyle

        Item {
            width: styleLoader.width
            height: compactLabel.height + Theme.paddingSmall * 2

            Label {
                id: compactLabel
                x: Theme.horizontalPageMargin
                y: Theme.paddingSmall
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: root.inlineText
                font.pixelSize: Theme.fontSizeSmall
                font.bold: root.isTopic
                color: Theme.primaryColor
                linkColor: Theme.highlightColor
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                onLinkActivated: Qt.openUrlExternally(link)
            }
        }
    }

    Component {
        id: quoteStyle

        Item {
            width: styleLoader.width
            height: quoteLabel.height + Theme.paddingMedium * 2

            Rectangle {
                x: Theme.horizontalPageMargin
                y: Theme.paddingSmall
                width: Math.round(Theme.paddingSmall / 2)
                height: parent.height - Theme.paddingSmall * 2
                radius: width / 2
                color: root.accentColor
            }

            Label {
                id: quoteLabel
                x: Theme.horizontalPageMargin + Theme.paddingLarge
                y: Theme.paddingMedium
                width: parent.width - x - Theme.horizontalPageMargin
                text: root.inlineText
                font.pixelSize: root.isTopic ? Theme.fontSizeMedium : Theme.fontSizeSmall
                font.italic: !root.isTopic
                font.bold: root.isTopic
                color: root.quotedNick !== "" ? Theme.primaryColor : root.accentColor
                linkColor: Theme.highlightColor
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                onLinkActivated: Qt.openUrlExternally(link)
            }
        }
    }
}
