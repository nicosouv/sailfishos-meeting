import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.mer.meeting 1.0

Page {
    id: page

    property var meeting
    property string logContent: ""
    property var messages: []

    allowedOrientations: Orientation.All

    Component.onCompleted: {
        meetingManager.fetchHtmlContent(meeting.logUrl)
    }

    Connections {
        target: meetingManager
        onHtmlContentLoaded: {
            logContent = content
            messages = meetingManager.parseIrcMessagesFromHtml(content)
        }
    }

    SilicaFlickable {
        anchors.fill: parent

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    logContent = ""
                    messages = []
                    meetingManager.fetchHtmlContent(meeting.logUrl)
                }
            }
        }

        Column {
            id: headerColumn
            width: parent.width

            PageHeader {
                title: qsTr("IRC Log")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: meeting.date + " - " + meeting.time
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            Item { width: 1; height: Theme.paddingMedium }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: logContent === "" && messages.length === 0
                size: BusyIndicatorSize.Large
            }
        }

        SilicaListView {
            id: listView
            anchors {
                top: headerColumn.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            clip: true
            model: messages

            delegate: Item {
                width: listView.width
                height: Math.max(messageColumn.height + Theme.paddingSmall, Theme.itemSizeSmall)

                Rectangle {
                    anchors.fill: parent
                    color: modelData.isTopic ? Theme.rgba(Theme.highlightBackgroundColor, 0.1) :
                           modelData.isCommand ? Theme.rgba(Theme.secondaryHighlightColor, 0.05) :
                           "transparent"
                }

                Row {
                    id: messageRow
                    width: parent.width - 2 * Theme.paddingSmall
                    x: Theme.paddingSmall
                    spacing: Theme.paddingSmall

                    // Timestamp
                    Label {
                        width: Theme.fontSizeExtraSmall * 5
                        text: modelData.timestamp
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        font.family: "Monospace"
                    }

                    Column {
                        id: messageColumn
                        width: parent.width - Theme.fontSizeExtraSmall * 5 - Theme.paddingSmall
                        spacing: 2

                        // Username (if present)
                        Label {
                            visible: modelData.username !== ""
                            text: modelData.username
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: modelData.userColor
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        // Message
                        Label {
                            text: modelData.message
                            font.pixelSize: Theme.fontSizeSmall
                            font.italic: modelData.isAction
                            font.bold: modelData.isCommand
                            color: modelData.isTopic ? Theme.highlightColor :
                                   modelData.isCommand ? Theme.secondaryHighlightColor :
                                   Theme.primaryColor
                            wrapMode: Text.Wrap
                            width: parent.width
                            textFormat: Text.PlainText
                        }
                    }
                }
            }

            VerticalScrollDecorator {}
        }
    }
}
