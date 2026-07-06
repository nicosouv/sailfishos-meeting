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
        }

        VerticalScrollDecorator {}
    }
}
