import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.sailfishos.meetings 1.0

Page {
    id: page

    property int year
    property var allMeetings: []
    property bool showOnlyFavorites: false

    allowedOrientations: Orientation.All

    function filterMeetings() {
        if (showOnlyFavorites) {
            var filtered = []
            for (var i = 0; i < allMeetings.length; i++) {
                if (meetingManager.isFavorite(allMeetings[i].filename)) {
                    filtered.push(allMeetings[i])
                }
            }
            listView.model = filtered
        } else {
            listView.model = allMeetings
        }
    }

    function countFavorites() {
        var count = 0
        for (var i = 0; i < allMeetings.length; i++) {
            if (meetingManager.isFavorite(allMeetings[i].filename)) {
                count++
            }
        }
        return count
    }

    Component.onCompleted: {
        meetingManager.fetchMeetingsForYear(year)
    }

    Connections {
        target: meetingManager
        onMeetingsLoaded: {
            allMeetings = meetings
            filterMeetings()
        }
        onFavoritesChanged: {
            filterMeetings()
        }
        onReadStatusChanged: {
            // Force list refresh
            listView.model = []
            filterMeetings()
        }
    }

    onShowOnlyFavoritesChanged: {
        filterMeetings()
    }

    SilicaFlickable {
        anchors.fill: parent

        PullDownMenu {
            MenuItem {
                text: showOnlyFavorites ? qsTr("Show all meetings") : qsTr("Show only favorites")
                visible: countFavorites() > 0
                onClicked: showOnlyFavorites = !showOnlyFavorites
            }
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

            // Statistics row
            Row {
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingLarge
                visible: allMeetings.length > 0

                Label {
                    text: qsTr("%n meeting(s)", "", allMeetings.length)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryHighlightColor
                }

                Label {
                    visible: countFavorites() > 0
                    text: "★ " + countFavorites()
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.highlightColor
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

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

            section.property: "month"
            section.delegate: SectionHeader {
                text: section
                height: Theme.itemSizeSmall
            }

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
                            color: {
                                if (meetingManager.isRead(modelData.filename)) {
                                    return delegate.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                                }
                                return delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                            }
                            opacity: meetingManager.isRead(modelData.filename) ? 0.6 : 1.0
                        }

                        Label {
                            text: modelData.date
                            font.pixelSize: Theme.fontSizeSmall
                            color: delegate.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            opacity: meetingManager.isRead(modelData.filename) ? 0.6 : 1.0
                        }

                        Label {
                            text: modelData.time
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: delegate.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            opacity: meetingManager.isRead(modelData.filename) ? 0.6 : 1.0
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

            ViewPlaceholder {
                enabled: !meetingManager.loading && listView.count === 0
                text: showOnlyFavorites ? qsTr("No favorite meetings") : qsTr("No meetings found")
                hintText: showOnlyFavorites ? qsTr("Mark meetings as favorites to see them here") : ""
            }
        }
    }
}
