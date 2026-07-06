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
            if (filterUser !== "" && msg.username !== filterUser) {
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

                property bool showHeader: {
                    if (index === 0) return true
                    if (modelData.username === "") return true
                    if (modelData.isTopic) return true

                    var prevMsg = filteredMessages[index - 1]
                    return prevMsg.username !== modelData.username
                }

                property bool isSection: {
                    var msg = modelData.message || ""
                    return msg.indexOf("#") === 0
                }

                property int leftMargin: Theme.horizontalPageMargin
                property int avatarWidth: Theme.iconSizeSmall + Theme.paddingSmall
                property int textLeftPosition: leftMargin + avatarWidth + Theme.paddingMedium

                property bool mentionsMe: {
                    var nick = meetingManager.myNick
                    if (nick === "" || !modelData.message) return false
                    return modelData.message.toLowerCase().indexOf(nick.toLowerCase()) !== -1
                }

                height: isSection ? sectionHeader.height : (messageContent.y + messageContent.height + Theme.paddingMedium)

                // Section/Header style (tous les messages commençant par #)
                Column {
                    id: sectionHeader
                    visible: isSection
                    width: parent.width
                    spacing: 0

                    // Ligne de séparation en haut
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.secondaryColor
                        opacity: 0.15
                    }

                    Row {
                        id: sectionContent
                        x: Theme.horizontalPageMargin
                        width: parent.width - Theme.horizontalPageMargin * 2
                        height: Math.max(sectionIcon.height, sectionLabel.height) + Theme.paddingMedium * 2
                        spacing: Theme.paddingMedium

                        // Icône selon le type
                        Image {
                            id: sectionIcon
                            width: Theme.iconSizeSmall
                            height: Theme.iconSizeSmall
                            y: Theme.paddingMedium
                            source: {
                                var msg = modelData.message.toLowerCase()
                                if (msg.indexOf("#topic") === 0) return "image://theme/icon-m-events"
                                if (msg.indexOf("#info") === 0) return "image://theme/icon-m-about"
                                if (msg.indexOf("#link") === 0) return "image://theme/icon-m-link"
                                if (msg.indexOf("#action") === 0) return "image://theme/icon-m-add"
                                if (msg.indexOf("#agreed") === 0) return "image://theme/icon-m-accept"
                                return "image://theme/icon-m-note"
                            }
                        }

                        Label {
                            id: sectionLabel
                            width: parent.width - sectionIcon.width - Theme.paddingMedium
                            y: Theme.paddingMedium
                            text: modelData.richMessage
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            color: Theme.primaryColor
                            linkColor: Theme.highlightColor
                            wrapMode: Text.Wrap
                            textFormat: Text.StyledText
                            onLinkActivated: Qt.openUrlExternally(link)
                        }
                    }

                    // Ligne de séparation en bas
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.secondaryColor
                        opacity: 0.15
                    }
                }

                // Background pour messages normaux
                Rectangle {
                    anchors.fill: parent
                    visible: !isSection
                    color: {
                        if (modelData.isTopic) return Theme.rgba(Theme.highlightBackgroundColor, 0.1)
                        if (mentionsMe) return Theme.rgba(Theme.highlightColor, 0.15)
                        return "transparent"
                    }
                }

                // Avatar (toujours à la même position)
                UserAvatar {
                    id: avatar
                    x: leftMargin
                    y: Theme.paddingMedium
                    username: modelData.username
                    visible: !isSection && modelData.username !== "" && showHeader

                    MouseArea {
                        anchors.fill: parent
                        onClicked: toggleUserFilter(modelData.username)
                    }
                }

                // Contenu du message (toujours à la même position X)
                Column {
                    id: messageContent
                    visible: !isSection
                    x: textLeftPosition
                    y: Theme.paddingMedium
                    width: parent.width - textLeftPosition - Theme.horizontalPageMargin
                    spacing: 0

                    // Username et timestamp (seulement si showHeader)
                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium
                        visible: modelData.username !== "" && showHeader

                        Label {
                            text: modelData.username
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: avatar.userColor

                            MouseArea {
                                anchors.fill: parent
                                onClicked: toggleUserFilter(modelData.username)
                            }
                        }

                        Label {
                            text: modelData.timestamp
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                            anchors.baseline: parent.children[0].baseline
                        }
                    }

                    // Spacer entre username et message
                    Item {
                        width: 1
                        height: (modelData.username !== "" && showHeader) ? Theme.paddingSmall : 0
                    }

                    // Message avec timestamp groupé
                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium
                        visible: modelData.username !== ""

                        Label {
                            width: parent.width - (groupedTimestamp.visible ? groupedTimestamp.width + Theme.paddingMedium : 0)
                            text: modelData.richMessage
                            font.pixelSize: Theme.fontSizeSmall
                            font.italic: modelData.isAction
                            color: modelData.isTopic ? Theme.highlightColor : Theme.primaryColor
                            linkColor: Theme.highlightColor
                            wrapMode: Text.Wrap
                            textFormat: Text.StyledText
                            onLinkActivated: Qt.openUrlExternally(link)
                        }

                        Label {
                            id: groupedTimestamp
                            visible: !showHeader
                            text: modelData.timestamp
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.secondaryColor
                            opacity: 0.6
                            anchors.baseline: parent.children[0].baseline
                        }
                    }

                    // Messages système (sans username)
                    Label {
                        visible: modelData.username === ""
                        width: parent.width
                        text: modelData.timestamp + " - " + modelData.richMessage
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        linkColor: Theme.highlightColor
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        font.italic: true
                        onLinkActivated: Qt.openUrlExternally(link)
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
