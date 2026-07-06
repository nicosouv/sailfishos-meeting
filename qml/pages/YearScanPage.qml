import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property int year
    property bool actionsMode: false
    property var scanResults: []
    property bool scanning: false
    property bool scanned: false
    property int progressDone: 0
    property int progressTotal: 0

    allowedOrientations: Orientation.All

    function startScan(query) {
        if (scanning) return
        scanning = true
        scanned = false
        scanResults = []
        progressDone = 0
        progressTotal = 0
        meetingManager.searchYear(year, query)
    }

    Component.onCompleted: {
        if (actionsMode) {
            startScan("")
        }
    }

    Connections {
        target: meetingManager
        onYearScanProgress: {
            progressDone = done
            progressTotal = total
        }
        onYearScanResults: {
            scanResults = results
            scanning = false
            scanned = true
        }
    }

    SilicaFlickable {
        anchors.fill: parent

        Column {
            id: headerColumn
            width: parent.width

            PageHeader {
                title: actionsMode ? qsTr("Actions %1").arg(year) : qsTr("Search %1").arg(year)
            }

            SearchField {
                id: searchField
                width: parent.width
                visible: !actionsMode
                placeholderText: qsTr("Search all meetings...")
                enabled: !scanning

                EnterKey.iconSource: "image://theme/icon-m-search"
                EnterKey.onClicked: {
                    focus = false
                    if (text.length >= 2) {
                        startScan(text)
                    }
                }
            }

            ProgressBar {
                width: parent.width
                visible: scanning
                minimumValue: 0
                maximumValue: progressTotal > 0 ? progressTotal : 1
                value: progressDone
                label: qsTr("Scanning meeting %1 of %2").arg(progressDone).arg(progressTotal)
            }

            Label {
                x: Theme.horizontalPageMargin
                visible: scanned && scanResults.length > 0
                text: qsTr("%n result(s)", "", scanResults.length)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
            }

            Item { width: 1; height: Theme.paddingMedium }
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
            model: scanResults

            section.property: "meetingDate"
            section.delegate: SectionHeader {
                text: section
            }

            delegate: ListItem {
                id: resultItem
                contentHeight: resultColumn.height + Theme.paddingMedium * 2

                Column {
                    id: resultColumn
                    x: Theme.horizontalPageMargin
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    spacing: Theme.paddingSmall

                    Row {
                        spacing: Theme.paddingMedium

                        Label {
                            text: modelData.username !== "" ? modelData.username : qsTr("system")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: true
                            color: resultItem.highlighted ? Theme.highlightColor : Theme.secondaryHighlightColor
                        }

                        Label {
                            text: modelData.timestamp
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }
                    }

                    Label {
                        width: parent.width
                        text: modelData.message
                        textFormat: Text.PlainText
                        font.pixelSize: Theme.fontSizeSmall
                        color: resultItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        truncationMode: TruncationMode.Fade
                    }
                }

                onClicked: {
                    pageStack.push(Qt.resolvedUrl("MeetingLogPage.qml"), {
                        meeting: meetingManager.createMeeting(modelData.filename)
                    })
                }
            }

            ViewPlaceholder {
                enabled: !scanning && scanResults.length === 0
                text: {
                    if (actionsMode) {
                        return scanned ? qsTr("No action items found") : ""
                    }
                    return scanned ? qsTr("No results") : qsTr("Search across all meetings of %1").arg(year)
                }
                hintText: (!actionsMode && !scanned) ? qsTr("Enter a word or a nickname") : ""
            }

            VerticalScrollDecorator {}
        }
    }
}
