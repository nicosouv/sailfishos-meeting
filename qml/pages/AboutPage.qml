import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("About")
            }

            // App icon and name
            Column {
                width: parent.width
                spacing: Theme.paddingMedium

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "image://theme/icon-l-browser"
                    width: Theme.iconSizeLarge
                    height: Theme.iconSizeLarge
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "SFOS Meetings"
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    color: Theme.highlightColor
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "v1.5.0"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                }
            }

            Item { width: 1; height: Theme.paddingLarge }

            // Made with love
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Made with ❤️ for Sailfish OS"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.highlightColor
            }

            Item { width: 1; height: Theme.paddingLarge }

            // Description
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Browse and explore Sailfish OS community meeting logs with a beautiful native interface. Search through discussions, mark favorites, and navigate topics with ease.")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
                horizontalAlignment: Text.AlignHCenter
            }

            Item { width: 1; height: Theme.paddingLarge }

            // Features
            SectionHeader {
                text: qsTr("Features")
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                Repeater {
                    model: [
                        qsTr("• Browse meetings from 2020 to present"),
                        qsTr("• Slack-style message display with avatars"),
                        qsTr("• Track read/unread meetings"),
                        qsTr("• Next meeting date and calendar integration"),
                        qsTr("• Quick topic navigation"),
                        qsTr("• Search messages and participants"),
                        qsTr("• Mark favorite meetings"),
                        qsTr("• Meeting statistics and insights")
                    ]

                    Label {
                        x: Theme.horizontalPageMargin * 2
                        width: parent.width - 4 * Theme.horizontalPageMargin
                        text: modelData
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }

            // Credits
            SectionHeader {
                text: qsTr("Credits")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Meeting logs provided by the Sailfish OS community at irclogs.sailfishos.org")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
            }

            Item { width: 1; height: Theme.paddingMedium }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Built with Qt and Sailfish Silica")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
            }

            Item { width: 1; height: Theme.paddingLarge }

            // GitHub link
            BackgroundItem {
                width: parent.width
                height: githubColumn.height

                Column {
                    id: githubColumn
                    width: parent.width
                    spacing: Theme.paddingSmall

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "🔗 github.com/nicosouv/sailfishos-meeting"
                        font.pixelSize: Theme.fontSizeSmall
                        color: highlighted ? Theme.highlightColor : Theme.primaryColor
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Tap to open in browser")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    }
                }

                onClicked: Qt.openUrlExternally("https://github.com/nicosouv/sailfishos-meeting")
            }

            Item { width: 1; height: Theme.paddingLarge }

            // License
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Licensed under BSD-3-Clause")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
            }

            Item { width: 1; height: Theme.paddingLarge * 2 }
        }

        VerticalScrollDecorator {}
    }
}
