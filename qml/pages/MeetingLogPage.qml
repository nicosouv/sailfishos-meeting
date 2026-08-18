import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.sailfishos.meetings 1.0
import "../components"

Page {
    id: page

    property var meeting
    // Meetings of the same year, to walk from one to the next
    property var siblings: []
    property int siblingIndex: -1
    // Log line to scroll to, set when coming from the summary
    property int jumpToLine: 0

    property string logContent: ""
    property var messages: []
    property var stats: null
    property var topicIndices: ([])
    property bool isFavorite: false
    property string searchText: ""
    property string filterUser: ""
    property bool notesOnly: false
    property var filteredMessages: messages

    allowedOrientations: Orientation.All

    function filterMessages() {
        if (searchText === "" && filterUser === "" && !notesOnly) {
            filteredMessages = messages
            return
        }
        var filtered = []
        var searchLower = searchText.toLowerCase()
        for (var i = 0; i < messages.length; i++) {
            var msg = messages[i]
            if (notesOnly && !msg.isCommand) {
                continue
            }
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

    // My nick plus the nicks explicitly followed, as whole words only so that
    // "Nico" does not light up every "Nicolas"
    property var highlightedNicks: {
        var nicks = []
        var all = (meetingManager.myNick + "," + meetingManager.watchedNicks).split(",")
        for (var i = 0; i < all.length; i++) {
            var nick = all[i].trim().toLowerCase()
            if (nick !== "") nicks.push(nick)
        }
        return nicks
    }

    function mentions(text) {
        if (highlightedNicks.length === 0 || !text) return false
        var words = text.toLowerCase().split(/[^a-z0-9_\[\]{}\\^`|-]+/)
        for (var i = 0; i < words.length; i++) {
            if (highlightedNicks.indexOf(words[i]) !== -1) return true
        }
        return false
    }

    function messageLink(message) {
        return message.logLine > 0 ? meeting.logUrl + "#l-" + message.logLine : meeting.logUrl
    }

    // Jump to the log line an entry of the summary points at
    function scrollToLine(line) {
        if (line <= 0) return
        for (var i = 0; i < filteredMessages.length; i++) {
            if (filteredMessages[i].logLine >= line) {
                listView.positionViewAtIndex(i, ListView.Beginning)
                return
            }
        }
    }

    function openSibling(offset) {
        var next = siblingIndex + offset
        if (next < 0 || next >= siblings.length) return
        pageStack.replace(Qt.resolvedUrl("MeetingLogPage.qml"), {
            meeting: siblings[next],
            siblings: siblings,
            siblingIndex: next
        })
    }

    function reload() {
        logContent = ""
        messages = []
        stats = null
        topicIndices = []
        searchText = ""
        searchField.text = ""
        filterUser = ""
        notesOnly = false
        meetingManager.fetchHtmlContent(meeting.logUrl)
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
            scrollToLine(jumpToLine)
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

    onNotesOnlyChanged: {
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
                text: qsTr("Meeting summary")
                onClicked: pageStack.push(Qt.resolvedUrl("MeetingSummaryPage.qml"), { meeting: meeting })
            }
            MenuItem {
                text: notesOnly ? qsTr("Show whole conversation") : qsTr("Show meeting notes only")
                onClicked: notesOnly = !notesOnly
            }
            MenuItem {
                text: qsTr("Topics") + " (" + topicIndices.length + ")"
                visible: topicIndices.length > 0
                onClicked: topicPanel.open = true
            }
            MenuItem {
                text: qsTr("Older meeting")
                visible: siblingIndex >= 0 && siblingIndex < siblings.length - 1
                onClicked: openSibling(1)
            }
            MenuItem {
                text: qsTr("Newer meeting")
                visible: siblingIndex > 0
                onClicked: openSibling(-1)
            }
            MenuItem {
                text: qsTr("Refresh")
                onClicked: reload()
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
                running: logContent === "" && messages.length === 0 && meetingManager.error === ""
                size: BusyIndicatorSize.Large
            }

            Column {
                width: parent.width
                spacing: Theme.paddingMedium
                visible: meetingManager.error !== "" && messages.length === 0

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
                    onClicked: reload()
                }
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

            delegate: ListItem {
                id: delegateItem
                width: listView.width
                contentHeight: isCommand ? commandMessage.height : chatMessage.height
                _backgroundColor: "transparent"

                property bool isCommand: modelData.isCommand

                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("Copy link to this line")
                        onClicked: Clipboard.text = messageLink(modelData)
                    }
                    MenuItem {
                        text: qsTr("Copy text")
                        onClicked: Clipboard.text = modelData.message
                    }
                    MenuItem {
                        text: modelData.username !== "" && filterUser !== modelData.username
                              ? qsTr("Only %1").arg(modelData.username)
                              : qsTr("Clear filter")
                        onClicked: toggleUserFilter(modelData.username)
                    }
                }

                property bool showHeader: {
                    if (index === 0) return true
                    if (modelData.username === "") return true

                    var prevMsg = filteredMessages[index - 1]
                    return prevMsg.username !== modelData.username || prevMsg.isCommand
                }

                property bool mentionsMe: page.mentions(modelData.message)

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

            ViewPlaceholder {
                enabled: messages.length > 0 && filteredMessages.length === 0
                text: notesOnly ? qsTr("No meeting notes in this log") : qsTr("No message matches")
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
