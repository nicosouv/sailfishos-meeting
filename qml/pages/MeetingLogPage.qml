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
        meetingManager.markAsRead(meeting.filename)
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

                property bool showHeader: {
                    if (index === 0) return true
                    if (modelData.username === "") return true
                    if (modelData.isTopic) return true

                    var prevMsg = filteredMessages[index - 1]
                    return prevMsg.username !== modelData.username
                }

                property int leftMargin: Theme.horizontalPageMargin
                property int avatarWidth: Theme.iconSizeSmall + Theme.paddingSmall
                property int textLeftPosition: leftMargin + avatarWidth + Theme.paddingMedium

                height: modelData.isCommand ? infoHeader.height :
                        messageContent.y + messageContent.height + Theme.paddingMedium

                // Command/Header style
                Item {
                    id: infoHeader
                    visible: modelData.isCommand
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    height: infoContent.height + Theme.paddingMedium * 2

                    Row {
                        id: infoContent
                        x: Theme.horizontalPageMargin
                        y: Theme.paddingMedium
                        width: parent.width - Theme.horizontalPageMargin * 2
                        spacing: Theme.paddingMedium

                        // Icône selon le type
                        Image {
                            id: commandIcon
                            width: Theme.iconSizeSmall
                            height: Theme.iconSizeSmall
                            source: {
                                var msg = modelData.message.toLowerCase()
                                if (msg.startsWith("#topic")) return "image://theme/icon-m-events"
                                if (msg.startsWith("#info")) return "image://theme/icon-m-about"
                                if (msg.startsWith("#link")) return "image://theme/icon-m-link"
                                if (msg.startsWith("#action")) return "image://theme/icon-m-add"
                                if (msg.startsWith("#agreed")) return "image://theme/icon-m-accept"
                                return "image://theme/icon-m-note"
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            width: parent.width - commandIcon.width - Theme.paddingMedium
                            text: modelData.message
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            color: Theme.primaryColor
                            wrapMode: Text.Wrap
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Ligne de séparation en bas
                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: 1
                        color: Theme.secondaryColor
                        opacity: 0.2
                    }
                }

                // Background pour messages normaux
                Rectangle {
                    anchors.fill: parent
                    visible: !modelData.isCommand
                    color: modelData.isTopic ? Theme.rgba(Theme.highlightBackgroundColor, 0.1) : "transparent"
                }

                // Avatar (toujours à la même position)
                UserAvatar {
                    id: avatar
                    x: leftMargin
                    y: Theme.paddingMedium
                    username: modelData.username
                    visible: !modelData.isCommand && modelData.username !== "" && showHeader
                }

                // Contenu du message (toujours à la même position X)
                Column {
                    id: messageContent
                    visible: !modelData.isCommand
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
                            text: modelData.message
                            font.pixelSize: Theme.fontSizeSmall
                            font.italic: modelData.isAction
                            color: modelData.isTopic ? Theme.highlightColor : Theme.primaryColor
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
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
                        text: modelData.timestamp + " - " + modelData.message
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.italic: true
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
