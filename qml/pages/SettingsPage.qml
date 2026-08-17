import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

Page {
    id: page

    allowedOrientations: Orientation.All

    // Fake messages used by the live previews
    readonly property var sampleCommand: ({
        command: "info",
        isCommand: true,
        isTopic: false,
        isAction: false,
        quotedNick: "Jolla",
        isJolla: true,
        username: "rainemak",
        timestamp: "16:06:50",
        body: "",
        richBody: qsTr("Rust update should be doable, contributions welcome."),
        message: "",
        richMessage: ""
    })

    readonly property var sampleTopic: ({
        command: "topic",
        isCommand: true,
        isTopic: true,
        isAction: false,
        quotedNick: "",
        isJolla: false,
        username: "rainemak",
        timestamp: "16:05:00",
        body: "",
        richBody: qsTr("General discussion (15 min)"),
        message: "",
        richMessage: ""
    })

    readonly property var sampleQuestion: ({
        command: "",
        isCommand: false,
        isTopic: false,
        isAction: false,
        quotedNick: "",
        isJolla: false,
        username: "b100dian",
        timestamp: "16:06:38",
        body: "",
        richBody: "",
        message: "",
        richMessage: qsTr("Are there any plans to update Rust?")
    })

    readonly property var sampleAnswer: ({
        command: "",
        isCommand: false,
        isTopic: false,
        isAction: false,
        quotedNick: "",
        isJolla: false,
        username: "rainemak",
        timestamp: "16:07:04",
        body: "",
        richBody: "",
        message: "",
        richMessage: qsTr("Let's see how far it goes, we already have Go in good shape.")
    })

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Settings")
            }

            TextField {
                width: parent.width
                label: qsTr("My nick")
                placeholderText: qsTr("Your IRC nickname")
                text: meetingManager.myNick
                description: qsTr("Messages mentioning this nick are highlighted in meeting logs")

                onTextChanged: meetingManager.myNick = text

                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            SectionHeader {
                text: qsTr("Meeting notes")
            }

            ComboBox {
                width: parent.width
                label: qsTr("Style")
                description: qsTr("How #info, #topic, #action and other meeting commands are shown")
                currentIndex: meetingManager.commandStyle

                menu: ContextMenu {
                    MenuItem { text: qsTr("Cards") }
                    MenuItem { text: qsTr("Banners") }
                    MenuItem { text: qsTr("Compact") }
                    MenuItem { text: qsTr("Quotes") }
                }

                onCurrentIndexChanged: meetingManager.commandStyle = currentIndex
            }

            CommandMessage {
                width: parent.width
                message: page.sampleTopic
                style: meetingManager.commandStyle
            }

            CommandMessage {
                width: parent.width
                message: page.sampleCommand
                style: meetingManager.commandStyle
            }

            SectionHeader {
                text: qsTr("Conversation")
            }

            ComboBox {
                width: parent.width
                label: qsTr("Style")
                description: qsTr("How the discussion between participants is shown")
                currentIndex: meetingManager.chatStyle

                menu: ContextMenu {
                    MenuItem { text: qsTr("Avatars") }
                    MenuItem { text: qsTr("Bubbles") }
                    MenuItem { text: qsTr("Compact") }
                    MenuItem { text: qsTr("Columns") }
                }

                onCurrentIndexChanged: meetingManager.chatStyle = currentIndex
            }

            ChatMessage {
                width: parent.width
                message: page.sampleQuestion
                style: meetingManager.chatStyle
            }

            ChatMessage {
                width: parent.width
                message: page.sampleAnswer
                style: meetingManager.chatStyle
            }
        }

        VerticalScrollDecorator {}
    }
}
