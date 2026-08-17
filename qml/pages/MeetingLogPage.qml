import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.sailfishos.meetings 1.0
import "../components"

Page {
    id: page

    property var meeting
    property string logContent: ""
    property var messages: []
    property var stats: null
    property var topicIndices: ([])
    property bool isFavorite: false
    property string searchText: ""
    property string filterUser: ""
    property var filteredMessages: messages

    allowedOrientations: Orientation.All

    function filterMessages() {
        if (searchText === "" && filterUser === "") {
            filteredMessages = messages
            return
        }
        var filtered = []
        var searchLower = searchText.toLowerCase()
        for (var i = 0; i < messages.length; i++) {
            var msg = messages[i]
            // A nick can also appear as the author quoted by "#info <nick>"
            if (filterUser !== "" && msg.username !== filterUser && msg.quotedNick !== filterUser) {
                continue
            }
            if (searchLower !== "" &&
                msg.message.toLowerCase().indexOf(searchLower) === -1 &&
                msg.username.toLowerCase().indexOf(searchLower) === -1) {
                continue
            }
            filtered.push(msg)
        }
        filteredMessages = filtered
    }

    function toggleUserFilter(name) {
        filterUser = (filterUser === name) ? "" : name
    }

    Component.onCompleted: {
        meetingManager.fetchHtmlContent(meeting.logUrl)
        meetingManager.markAsRead(meeting.filename)
        isFavorite = meetingManager.isFavorite(meeting.filename)
    }

    Connections {
        target: meetingManager
        onHtmlContentLoaded: {
            if (url !== meeting.logUrl) return
            logContent = content
            messages = meetingManager.parseIrcMessagesFromHtml(content)
            stats = meetingManager.calculateStatistics(messages)

            // Build topic indices
            var topics = []
            for (var i = 0; i < messages.length; i++) {
                if (messages[i].isTopic) {
                    topics.push({
                        index: i,
                        message: messages[i].body
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

    onFilterUserChanged: {
        filterMessages()
    }

    // Avoid rebuilding the whole list on every keystroke
    Timer {
        id: searchDebounce
        interval: 300
        onTriggered: searchText = searchField.text
    }

    SilicaFlickable {
        anchors.fill: parent

        PullDownMenu {
            MenuItem {
                text: isFavorite ? qsTr("Remove from favorites") : qsTr("Add to favorites")
                onClicked: meetingManager.toggleFavorite(meeting.filename)
            }
            MenuItem {
                text: qsTr("Copy link")
                onClicked: Clipboard.text = meeting.url
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
                    filterUser = ""
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
                text: meeting.seriesName + " — " + meeting.date + " - " + meeting.time
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                truncationMode: TruncationMode.Fade
            }

            // Search field
            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search messages...")
                visible: messages.length > 0

                onTextChanged: {
                    searchDebounce.restart()
                }

                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            Label {
                x: Theme.horizontalPageMargin
                visible: searchText !== "" || filterUser !== ""
                text: qsTr("%1 of %2 messages").arg(filteredMessages.length).arg(messages.length)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: filterUser !== ""
                text: qsTr("Messages from %1 — tap to clear").arg(filterUser)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.highlightColor
                truncationMode: TruncationMode.Fade

                MouseArea {
                    anchors.fill: parent
                    onClicked: filterUser = ""
                }
            }

            // Statistics, kept on a single line to leave room for reading
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: stats !== null
                text: {
                    if (!stats) return ""
                    var parts = [qsTr("%1 messages").arg(stats.messageCount),
                                 qsTr("%1 participants").arg(stats.participantCount)]
                    if (stats.duration !== "") {
                        parts.push(stats.duration)
                    }
                    if (stats.topContributor !== "") {
                        parts.push(qsTr("top %1").arg(stats.topContributor))
                    }
                    return parts.join(" · ")
                }
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                truncationMode: TruncationMode.Fade
            }

            Item { width: 1; height: Theme.paddingSmall }

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
                id: delegateItem
                width: listView.width
                height: isCommand ? commandMessage.height : chatMessage.height

                property bool isCommand: modelData.isCommand

                property bool showHeader: {
                    if (index === 0) return true
                    if (modelData.username === "") return true

                    var prevMsg = filteredMessages[index - 1]
                    return prevMsg.username !== modelData.username || prevMsg.isCommand
                }

                property bool mentionsMe: {
                    var nick = meetingManager.myNick
                    if (nick === "" || !modelData.message) return false
                    return modelData.message.toLowerCase().indexOf(nick.toLowerCase()) !== -1
                }

                CommandMessage {
                    id: commandMessage
                    width: parent.width
                    visible: delegateItem.isCommand
                    message: delegateItem.isCommand ? modelData : null
                    style: meetingManager.commandStyle
                    onNickClicked: toggleUserFilter(name)
                }

                ChatMessage {
                    id: chatMessage
                    width: parent.width
                    visible: !delegateItem.isCommand
                    message: delegateItem.isCommand ? null : modelData
                    style: meetingManager.chatStyle
                    showHeader: delegateItem.showHeader
                    mentionsMe: delegateItem.mentionsMe
                    onNickClicked: toggleUserFilter(name)
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
                            textFormat: Text.PlainText
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
