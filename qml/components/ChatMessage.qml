import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

/*
 * Renders a regular conversation line in the style picked by the user in the
 * settings:
 *   0 Avatars  colored avatar, nick above the message
 *   1 Bubbles  chat bubble tinted with the nick color
 *   2 Compact  classic IRC line: time, nick and message on one flow
 *   3 Columns  nick right aligned in its own column
 */
Item {
    id: root

    property var message
    property int style: 0
    property bool showHeader: true
    property bool mentionsMe: false

    signal nickClicked(string name)

    readonly property string nick: message ? message.username : ""
    readonly property bool isSystem: nick === ""
    readonly property bool isAction: message ? message.isAction === true : false
    readonly property string bodyText: message ? message.richMessage : ""
    readonly property string timestamp: message ? message.timestamp : ""
    readonly property color nickColor: isSystem ? Theme.secondaryColor : UserColorManager.getColorForUser(nick)
    readonly property color textColor: Theme.primaryColor

    height: styleLoader.item ? styleLoader.item.height : 0

    Rectangle {
        anchors.fill: parent
        visible: root.mentionsMe && root.style !== 1
        color: Theme.rgba(Theme.highlightColor, 0.15)
    }

    Loader {
        id: styleLoader
        width: root.width
        sourceComponent: {
            if (!root.message) return null
            if (root.isSystem) return systemStyle
            switch (root.style) {
            case 1: return bubbleStyle
            case 2: return compactStyle
            case 3: return columnStyle
            default: return avatarStyle
            }
        }
    }

    // Joins, parts and meetbot announcements
    Component {
        id: systemStyle

        Item {
            width: styleLoader.width
            height: systemLabel.height + Theme.paddingSmall * 2

            Label {
                id: systemLabel
                x: Theme.horizontalPageMargin
                y: Theme.paddingSmall
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: root.timestamp + " - " + root.bodyText
                font.pixelSize: Theme.fontSizeExtraSmall
                font.italic: true
                color: Theme.secondaryColor
                linkColor: Theme.highlightColor
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                onLinkActivated: Qt.openUrlExternally(link)
            }
        }
    }

    Component {
        id: avatarStyle

        Item {
            width: styleLoader.width
            height: avatarColumn.height + Theme.paddingMedium * 2

            UserAvatar {
                x: Theme.horizontalPageMargin
                y: Theme.paddingMedium
                username: root.nick
                visible: root.showHeader

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.nickClicked(root.nick)
                }
            }

            Column {
                id: avatarColumn
                x: Theme.horizontalPageMargin + Theme.iconSizeSmall + Theme.paddingSmall + Theme.paddingMedium
                y: Theme.paddingMedium
                width: parent.width - x - Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                Row {
                    spacing: Theme.paddingMedium
                    visible: root.showHeader

                    Label {
                        text: root.nick
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: root.nickColor

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.nickClicked(root.nick)
                        }
                    }

                    Label {
                        anchors.baseline: parent.children[0].baseline
                        text: root.timestamp
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width - (groupedTimestamp.visible ? groupedTimestamp.width + Theme.paddingMedium : 0)
                        text: root.bodyText
                        font.pixelSize: Theme.fontSizeSmall
                        font.italic: root.isAction
                        color: root.textColor
                        linkColor: Theme.highlightColor
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        onLinkActivated: Qt.openUrlExternally(link)
                    }

                    Label {
                        id: groupedTimestamp
                        anchors.baseline: parent.children[0].baseline
                        visible: !root.showHeader
                        text: root.timestamp
                        font.pixelSize: Theme.fontSizeTiny
                        color: Theme.secondaryColor
                        opacity: 0.6
                    }
                }
            }
        }
    }

    Component {
        id: bubbleStyle

        Item {
            width: styleLoader.width
            height: bubble.height + Theme.paddingSmall * 2

            Rectangle {
                id: bubble
                x: Theme.horizontalPageMargin
                y: Theme.paddingSmall
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: bubbleColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingLarge
                color: root.mentionsMe ? Theme.rgba(Theme.highlightColor, 0.25)
                                       : Theme.rgba(root.nickColor, 0.16)

                Column {
                    id: bubbleColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - Theme.paddingMedium * 2
                    spacing: Theme.paddingSmall

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium
                        visible: root.showHeader

                        Label {
                            text: root.nick
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: true
                            color: root.nickColor

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.nickClicked(root.nick)
                            }
                        }

                        Label {
                            anchors.baseline: parent.children[0].baseline
                            text: root.timestamp
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.secondaryColor
                        }
                    }

                    Label {
                        width: parent.width
                        text: root.bodyText
                        font.pixelSize: Theme.fontSizeSmall
                        font.italic: root.isAction
                        color: root.textColor
                        linkColor: Theme.highlightColor
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        onLinkActivated: Qt.openUrlExternally(link)
                    }
                }
            }
        }
    }

    Component {
        id: compactStyle

        Item {
            width: styleLoader.width
            height: compactLabel.height + Theme.paddingSmall

            Label {
                id: compactLabel
                x: Theme.horizontalPageMargin
                y: Theme.paddingSmall / 2
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "<font color=\"" + Theme.secondaryColor + "\">" + root.timestamp + "</font> "
                      + "<font color=\"" + root.nickColor + "\">"
                      + (root.isAction ? "* " + root.nick : "&lt;" + root.nick + "&gt;") + "</font> "
                      + root.bodyText
                font.pixelSize: Theme.fontSizeExtraSmall
                font.italic: root.isAction
                color: root.textColor
                linkColor: Theme.highlightColor
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                onLinkActivated: Qt.openUrlExternally(link)

                MouseArea {
                    width: Math.min(parent.width, Theme.itemSizeSmall * 2)
                    height: parent.font.pixelSize * 1.5
                    onClicked: root.nickClicked(root.nick)
                }
            }
        }
    }

    Component {
        id: columnStyle

        Item {
            width: styleLoader.width
            height: Math.max(columnNick.height, columnBody.height) + Theme.paddingSmall * 2

            Label {
                id: columnNick
                x: Theme.horizontalPageMargin
                y: Theme.paddingSmall
                width: Math.round(parent.width * 0.25)
                visible: root.showHeader
                horizontalAlignment: Text.AlignRight
                text: root.nick
                font.pixelSize: Theme.fontSizeExtraSmall
                font.bold: true
                color: root.nickColor
                truncationMode: TruncationMode.Fade

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.nickClicked(root.nick)
                }
            }

            Label {
                id: columnBody
                x: Theme.horizontalPageMargin + Math.round(parent.width * 0.25) + Theme.paddingMedium
                y: Theme.paddingSmall
                width: parent.width - x - Theme.horizontalPageMargin
                text: root.bodyText
                font.pixelSize: Theme.fontSizeExtraSmall
                font.italic: root.isAction
                color: root.textColor
                linkColor: Theme.highlightColor
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                onLinkActivated: Qt.openUrlExternally(link)
            }
        }
    }
}
