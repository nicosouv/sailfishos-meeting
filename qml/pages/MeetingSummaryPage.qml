import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.sailfishos.meetings 1.0

Page {
    id: page

    property var meeting
    property string htmlContent: ""
    property var topics: []

    allowedOrientations: Orientation.All

    Component.onCompleted: {
        meetingManager.fetchHtmlContent(meeting.url)
    }

    Connections {
        target: meetingManager
        onHtmlContentLoaded: {
            htmlContent = content
            topics = meetingManager.parseTopicsFromHtml(content)
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: qsTr("View full IRC log")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("MeetingLogPage.qml"), {
                        meeting: meeting
                    })
                }
            }
            MenuItem {
                text: qsTr("Refresh")
                onClicked: meetingManager.fetchHtmlContent(meeting.url)
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Meeting Summary")
            }

            // Meeting info
            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: meeting.date
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.highlightColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: meeting.time
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: htmlContent === ""
                size: BusyIndicatorSize.Large
            }

            // Topics list
            Repeater {
                model: topics

                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall

                    SectionHeader {
                        text: modelData.title
                    }

                    Label {
                        x: Theme.horizontalPageMargin * 2
                        width: parent.width - 4 * Theme.horizontalPageMargin
                        visible: modelData.items.length === 0
                        text: qsTr("No items discussed")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                        font.italic: true
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
        }

        VerticalScrollDecorator {}
    }
}
