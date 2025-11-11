import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.mer.meeting 1.0

Page {
    id: page

    property int year

    allowedOrientations: Orientation.All

    Component.onCompleted: {
        meetingManager.fetchMeetingsForYear(year)
    }

    Connections {
        target: meetingManager
        onMeetingsLoaded: {
            listView.model = meetings
        }
        onFavoritesChanged: {
            // Force model refresh to update favorite indicators
            var temp = listView.model
            listView.model = null
            listView.model = temp
        }
    }

    SilicaFlickable {
        anchors.fill: parent

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: meetingManager.fetchMeetingsForYear(year)
            }
        }

        Column {
            id: headerColumn
            width: parent.width

            PageHeader {
                title: qsTr("Meetings %1").arg(year)
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: meetingManager.loading
                size: BusyIndicatorSize.Large
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: meetingManager.error !== ""
                text: meetingManager.error
                color: Theme.errorColor
                wrapMode: Text.WordWrap
                width: parent.width - 2 * Theme.horizontalPageMargin
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

            delegate: ListItem {
                id: delegate
                contentHeight: Theme.itemSizeLarge

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    spacing: Theme.paddingMedium

                    Label {
                        text: meetingManager.isFavorite(modelData.filename) ? "★" : ""
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.highlightColor
                        width: visible ? Theme.iconSizeSmall : 0
                        visible: text !== ""
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - (meetingManager.isFavorite(modelData.filename) ? Theme.iconSizeSmall + Theme.paddingMedium : 0)

                        Label {
                            text: modelData.title
                            font.pixelSize: Theme.fontSizeMedium
                            color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                        }

                        Label {
                            text: modelData.date
                            font.pixelSize: Theme.fontSizeSmall
                            color: delegate.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        }

                        Label {
                            text: modelData.time
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: delegate.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        }
                    }
                }

                onClicked: {
                    pageStack.push(Qt.resolvedUrl("MeetingLogPage.qml"), {
                        meeting: modelData
                    })
                }
            }

            VerticalScrollDecorator {}
        }
    }
}
