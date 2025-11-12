import QtQuick 2.0
import Sailfish.Silica 1.0
import org.nemomobile.calendar 1.0
import Nemo.Notifications 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    property string nextMeetingDate: meetingManager.getNextMeetingDate()
    property string nextMeetingDateRaw: ""

    Component.onCompleted: {
        meetingManager.fetchNextMeetingDate()
    }

    Connections {
        target: meetingManager
        onNextMeetingDateChanged: {
            nextMeetingDate = date
            nextMeetingDateRaw = rawDate
        }
    }

    function addToCalendar() {
        if (nextMeetingDateRaw === "") {
            return
        }

        var event = Calendar.createNewEvent()
        event.displayLabel = "Sailfish OS Community Meeting"
        event.description = "Monthly community meeting to discuss Sailfish OS development and topics"
        event.location = "IRC: #sailfishos-meeting on libera.chat"

        // Parse the ISO date format: 2025-11-20T1600Z
        var dateTime = new Date(nextMeetingDateRaw)
        event.startTime = dateTime

        // Meeting usually lasts 1 hour
        var endTime = new Date(dateTime.getTime() + 60 * 60 * 1000)
        event.endTime = endTime

        event.calendarUid = Calendar.defaultNotebook
        event.save()

        // Show confirmation
        calendarNotification.publish()
    }

    Notification {
        id: calendarNotification
        appName: "SFOS Meetings"
        summary: qsTr("Added to calendar")
        body: qsTr("The next meeting has been added to your calendar")
    }

    SilicaListView {
        id: listView
        anchors.fill: parent

        PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
        }

        header: Column {
            width: parent.width

            PageHeader {
                title: qsTr("Sailfish OS Meetings")
            }

            Item {
                width: parent.width
                height: nextMeetingDate !== "" ? nextMeetingBanner.height : 0
                visible: nextMeetingDate !== ""

                Rectangle {
                    id: nextMeetingBanner
                    width: parent.width
                    height: nextMeetingColumn.height + Theme.paddingLarge * 2
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.2)

                    Column {
                        id: nextMeetingColumn
                        x: Theme.horizontalPageMargin
                        y: Theme.paddingLarge
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        spacing: Theme.paddingSmall

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium

                            Label {
                                text: qsTr("Next Meeting")
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: Theme.highlightColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Button {
                                text: qsTr("Add to Calendar")
                                preferredWidth: Theme.buttonWidthSmall
                                onClicked: addToCalendar()
                            }
                        }

                        Label {
                            text: nextMeetingDate
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primaryColor
                            wrapMode: Text.Wrap
                            width: parent.width
                        }
                    }
                }
            }
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
