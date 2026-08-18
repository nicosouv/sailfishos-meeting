import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.sailfishos.meetings 1.0
import "../components"

/*
 * Meetbot publishes a summary next to every log: decisions, action items and
 * who spoke how much. Each entry links back to its line in the log.
 */
Page {
    id: page

    property var meeting
    property var summary: null
    property bool loaded: false

    allowedOrientations: Orientation.All

    function openLogAt(line) {
        pageStack.push(Qt.resolvedUrl("MeetingLogPage.qml"), {
            meeting: meeting,
            jumpToLine: line
        })
    }

    function load() {
        loaded = false
        summary = null
        meetingManager.fetchHtmlContent(meeting.url)
    }

    Component.onCompleted: load()

    Connections {
        target: meetingManager
        onHtmlContentLoaded: {
            if (url !== meeting.url) return
            summary = meetingManager.parseSummaryFromHtml(content)
            loaded = true
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Read full log")
                onClicked: openLogAt(0)
            }
            MenuItem {
                text: qsTr("Copy link")
                onClicked: Clipboard.text = meeting.url
            }
            MenuItem {
                text: qsTr("Refresh")
                onClicked: load()
            }
        }

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Summary")
                description: meeting.seriesName + " — " + meeting.date
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: summary && summary.chair !== ""
                text: summary ? qsTr("Chaired by %1, %2 to %3 UTC")
                                    .arg(summary.chair).arg(summary.started).arg(summary.ended)
                              : ""
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: !loaded && meetingManager.error === ""
                size: BusyIndicatorSize.Large
            }

            Column {
                width: parent.width
                visible: meetingManager.error !== "" && !loaded
                spacing: Theme.paddingMedium

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: meetingManager.error
                    color: Theme.errorColor
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Retry")
                    onClicked: load()
                }
            }

            // Action items
            SectionHeader {
                text: qsTr("Action items")
                visible: summary && summary.actions.length > 0
            }

            Repeater {
                model: summary ? summary.actions : []

                Item {
                    width: page.width
                    height: actionLabel.height + Theme.paddingMedium

                    Rectangle {
                        x: Theme.horizontalPageMargin
                        y: Math.round(actionLabel.font.pixelSize / 2)
                        width: Theme.paddingSmall
                        height: width
                        radius: width / 2
                        color: "#e8a33d"
                    }

                    Label {
                        id: actionLabel
                        x: Theme.horizontalPageMargin + Theme.paddingLarge
                        y: Theme.paddingSmall / 2
                        width: parent.width - x - Theme.horizontalPageMargin
                        text: modelData
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            // Decisions and notes, grouped under their topic
            SectionHeader {
                text: qsTr("Notes")
                visible: summary && summary.entries.length > 0
            }

            Repeater {
                model: summary ? summary.entries : []

                BackgroundItem {
                    width: page.width
                    height: entryColumn.height + Theme.paddingMedium

                    property bool isTopic: modelData.type === "TOPIC"

                    Rectangle {
                        width: Math.round(Theme.paddingSmall / 2)
                        height: parent.height
                        x: Theme.horizontalPageMargin
                        visible: !isTopic
                        color: Theme.rgba(Theme.highlightColor, 0.4)
                    }

                    Column {
                        id: entryColumn
                        x: Theme.horizontalPageMargin + (isTopic ? 0 : Theme.paddingLarge)
                        y: Theme.paddingSmall
                        width: page.width - x - Theme.horizontalPageMargin
                        spacing: Theme.paddingSmall / 2

                        Label {
                            width: parent.width
                            text: modelData.text
                            font.pixelSize: isTopic ? Theme.fontSizeMedium : Theme.fontSizeSmall
                            font.bold: isTopic
                            color: isTopic ? Theme.highlightColor : Theme.primaryColor
                            wrapMode: Text.Wrap
                        }

                        Row {
                            spacing: Theme.paddingSmall

                            Label {
                                visible: modelData.type !== "INFO" && modelData.type !== "TOPIC"
                                text: modelData.type
                                font.pixelSize: Theme.fontSizeTiny
                                font.bold: true
                                color: modelData.type === "ACTION" ? "#e8a33d" : Theme.secondaryHighlightColor
                            }

                            Label {
                                text: modelData.nick + " · " + modelData.time
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.secondaryColor
                            }
                        }
                    }

                    onClicked: openLogAt(modelData.line)
                }
            }

            // People present
            SectionHeader {
                text: qsTr("People present")
                visible: summary && summary.people.length > 0
            }

            Repeater {
                model: summary ? summary.people : []

                Row {
                    x: Theme.horizontalPageMargin
                    width: page.width - 2 * Theme.horizontalPageMargin
                    height: Theme.itemSizeExtraSmall
                    spacing: Theme.paddingMedium

                    UserAvatar {
                        id: personAvatar
                        anchors.verticalCenter: parent.verticalCenter
                        username: modelData.nick
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - personAvatar.width - lineCount.width
                               - Theme.paddingMedium * 2
                        text: modelData.nick
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        id: lineCount
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("%1 lines").arg(modelData.lines)
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                visible: loaded && summary && summary.entries.length === 0
                         && summary.actions.length === 0
                text: qsTr("No summary published for this meeting")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }
        }

        VerticalScrollDecorator {}
    }
}
