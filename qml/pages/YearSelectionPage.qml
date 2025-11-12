import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    property string nextMeetingDate: ""
    property string nextMeetingDateRaw: ""

    Component.onCompleted: {
        // Load saved date first
        nextMeetingDate = meetingManager.getNextMeetingDate()
        console.log("Loaded saved next meeting date:", nextMeetingDate)

        // Always fetch fresh data to check for new meetings
        // This ensures we always have the most recent meeting's next date
        console.log("Fetching fresh next meeting date...")
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
            console.log("No raw date available")
            return
        }

        console.log("Adding to calendar with date:", nextMeetingDateRaw)

        // Parse the ISO date format: 2024-11-28T0800Z
        // Need to insert colon in time: 2024-11-28T08:00Z
        var formattedDate = nextMeetingDateRaw.replace(/T(\d{2})(\d{2})Z/, "T$1:$2Z")
        console.log("Formatted date for parsing:", formattedDate)

        var dateTime = new Date(formattedDate)
        console.log("Parsed datetime:", dateTime)

        // Format for iCalendar format (YYYYMMDDTHHMMSSZ)
        var year = dateTime.getUTCFullYear()
        var month = ("0" + (dateTime.getUTCMonth() + 1)).slice(-2)
        var day = ("0" + dateTime.getUTCDate()).slice(-2)
        var hours = ("0" + dateTime.getUTCHours()).slice(-2)
        var minutes = ("0" + dateTime.getUTCMinutes()).slice(-2)
        var startTimeFormatted = year + month + day + "T" + hours + minutes + "00Z"

        // End time (1 hour later)
        var endTime = new Date(dateTime.getTime() + 60 * 60 * 1000)
        var endYear = endTime.getUTCFullYear()
        var endMonth = ("0" + (endTime.getUTCMonth() + 1)).slice(-2)
        var endDay = ("0" + endTime.getUTCDate()).slice(-2)
        var endHours = ("0" + endTime.getUTCHours()).slice(-2)
        var endMinutes = ("0" + endTime.getUTCMinutes()).slice(-2)
        var endTimeFormatted = endYear + endMonth + endDay + "T" + endHours + endMinutes + "00Z"

        // Create webcal URL to open in calendar app
        var title = encodeURIComponent("Sailfish OS Community Meeting")
        var description = encodeURIComponent("Monthly community meeting to discuss Sailfish OS development and topics")
        var location = encodeURIComponent("IRC: #sailfishos-meeting on libera.chat")

        // Create an ICS file content
        var icsContent = "BEGIN:VCALENDAR\n" +
                        "VERSION:2.0\n" +
                        "PRODID:-//SFOS Meetings//EN\n" +
                        "BEGIN:VEVENT\n" +
                        "UID:" + Date.now() + "@sailfishos-meetings\n" +
                        "DTSTAMP:" + startTimeFormatted + "\n" +
                        "DTSTART:" + startTimeFormatted + "\n" +
                        "DTEND:" + endTimeFormatted + "\n" +
                        "SUMMARY:Sailfish OS Community Meeting\n" +
                        "DESCRIPTION:Monthly community meeting to discuss Sailfish OS development and topics\n" +
                        "LOCATION:IRC: #sailfishos-meeting on libera.chat\n" +
                        "END:VEVENT\n" +
                        "END:VCALENDAR"

        // Save to temp file and open with calendar
        var tempPath = "/tmp/sfos-meeting.ics"
        console.log("Creating ICS file at:", tempPath)

        // Use Qt.openUrlExternally with file:// to open the ICS file
        meetingManager.saveIcsFile(tempPath, icsContent)
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
