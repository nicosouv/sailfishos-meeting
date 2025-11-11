import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    SilicaListView {
        id: listView
        anchors.fill: parent

        PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
        }

        header: PageHeader {
            title: qsTr("Sailfish OS Meetings")
        }

        model: meetingManager.getAvailableYears()

        delegate: BackgroundItem {
            id: delegate
            width: listView.width
            height: Theme.itemSizeLarge

            Column {
                anchors.verticalCenter: parent.verticalCenter
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin

                Label {
                    text: modelData
                    font.pixelSize: Theme.fontSizeExtraLarge
                    color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Label {
                    text: qsTr("View meetings from %1").arg(modelData)
                    font.pixelSize: Theme.fontSizeSmall
                    color: delegate.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                }
            }

            onClicked: {
                pageStack.push(Qt.resolvedUrl("MeetingListPage.qml"), { year: modelData })
            }
        }

        VerticalScrollDecorator {}
    }
}
