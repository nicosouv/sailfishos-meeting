import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.mer.meeting 1.0

Page {
    id: page

    property var meeting
    property string logContent: ""
    property var messages: []
    property var stats: null
    property var topicIndices: ([])
    property bool isFavorite: false
    property string searchText: ""
    property var filteredMessages: messages

    allowedOrientations: Orientation.All

    function filterMessages() {
        if (searchText === "") {
            filteredMessages = messages
        } else {
            var filtered = []
            var searchLower = searchText.toLowerCase()
            for (var i = 0; i < messages.length; i++) {
                var msg = messages[i]
                if (msg.message.toLowerCase().indexOf(searchLower) !== -1 ||
                    msg.username.toLowerCase().indexOf(searchLower) !== -1) {
                    filtered.push(msg)
                }
            }
            filteredMessages = filtered
        }
    }

    Component.onCompleted: {
        meetingManager.fetchHtmlContent(meeting.logUrl)
        isFavorite = meetingManager.isFavorite(meeting.filename)
    }

    Connections {
        target: meetingManager
        onHtmlContentLoaded: {
            logContent = content
            messages = meetingManager.parseIrcMessagesFromHtml(content)
            stats = meetingManager.calculateStatistics(messages)

            // Build topic indices
            var topics = []
            for (var i = 0; i < messages.length; i++) {
                if (messages[i].isTopic) {
                    topics.push({
                        index: i,
                        message: messages[i].message
                    })
                }
            }
            topicIndices = topics
            filterMessages()
        }
        onFavoritesChanged: {
            isFavorite = meetingManager.isFavorite(meeting.filename)
        }
    }

    onSearchTextChanged: {
        filterMessages()
    }

    SilicaFlickable {
        anchors.fill: parent

        PullDownMenu {
            MenuItem {
                text: isFavorite ? qsTr("Remove from favorites") : qsTr("Add to favorites")
                onClicked: meetingManager.toggleFavorite(meeting.filename)
            }
            MenuItem {
                text: qsTr("Topics") + " (" + topicIndices.length + ")"
                visible: topicIndices.length > 0
                onClicked: topicPanel.open = true
            }
            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    logContent = ""
                    messages = []
                    stats = null
                    topicIndices = []
                    searchText = ""
                    searchField.text = ""
                    meetingManager.fetchHtmlContent(meeting.logUrl)
                }
            }
        }

        PushUpMenu {
            MenuItem {
                text: qsTr("Scroll to top")
                onClicked: listView.positionViewAtBeginning()
            }
            MenuItem {
                text: qsTr("Scroll to bottom")
                onClicked: listView.positionViewAtEnd()
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

            // Search field
            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search messages...")
                visible: messages.length > 0

                onTextChanged: {
                    searchText = text
                }

                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            Label {
                x: Theme.horizontalPageMargin
                visible: searchText !== ""
                text: qsTr("%1 of %2 messages").arg(filteredMessages.length).arg(messages.length)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
            }

            // Statistics section
            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: stats !== null

                Item { width: 1; height: Theme.paddingSmall }

                Row {
                    x: Theme.horizontalPageMargin
                    spacing: Theme.paddingLarge

                    Label {
                        text: stats ? qsTr("%1 messages").arg(stats.messageCount) : ""
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryHighlightColor
                    }

                    Label {
                        text: stats ? qsTr("%1 participants").arg(stats.participantCount) : ""
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryHighlightColor
                    }

                    Label {
                        visible: stats && stats.duration !== ""
                        text: stats ? stats.duration : ""
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryHighlightColor
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    visible: stats && stats.topContributor !== ""
                    text: stats ? qsTr("Top: %1 (%2 msgs)").arg(stats.topContributor).arg(stats.topContributorCount) : ""
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.highlightColor
                }
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
            model: filteredMessages

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

    DockedPanel {
        id: topicPanel
        width: parent.width
        height: Math.min(topicListView.contentHeight + Theme.paddingLarge * 2, page.height * 0.6)

        dock: Dock.Bottom
        open: false

        Rectangle {
            anchors.fill: parent
            color: Theme.rgba(Theme.highlightDimmerColor, 0.9)

            Column {
                anchors.fill: parent
                spacing: 0

                PageHeader {
                    title: qsTr("Jump to Topic")
                }

                SilicaListView {
                    id: topicListView
                    width: parent.width
                    height: parent.height - Theme.itemSizeLarge

                    model: topicIndices

                    delegate: ListItem {
                        contentHeight: Theme.itemSizeSmall

                        Label {
                            x: Theme.horizontalPageMargin
                            width: parent.width - 2 * Theme.horizontalPageMargin
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.message
                            font.pixelSize: Theme.fontSizeSmall
                            color: highlighted ? Theme.highlightColor : Theme.primaryColor
                            truncationMode: TruncationMode.Fade
                        }

                        onClicked: {
                            listView.positionViewAtIndex(modelData.index, ListView.Center)
                            topicPanel.open = false
                        }
                    }
                }
            }
        }
    }
}
