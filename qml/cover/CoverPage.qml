/*
  Copyright (C) 2013 Jolla Ltd.
  Contact: Thomas Perl <thomas.perl@jollamobile.com>
  All rights reserved.

  You may use this file under the terms of BSD license as follows:

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Jolla Ltd nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    property string nextMeetingDate: meetingManager.getNextMeetingDate()

    Connections {
        target: meetingManager
        onNextMeetingDateChanged: {
            nextMeetingDate = date
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingMedium

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("SFOS Meetings")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            visible: nextMeetingDate !== ""

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Next Meeting")
                font.pixelSize: Theme.fontSizeExtraSmall
                font.bold: true
                color: Theme.highlightColor
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (nextMeetingDate === "") return ""
                    // Parse format: "Thursday 20 November 2025 - 16:00 UTC"
                    var parts = nextMeetingDate.split(" - ")
                    if (parts.length === 2) {
                        var dateParts = parts[0].split(" ")
                        // Return: "20 Nov 2025"
                        if (dateParts.length >= 3) {
                            return dateParts[1] + " " + dateParts[2].substring(0, 3) + " " + dateParts[3]
                        }
                    }
                    return nextMeetingDate
                }
                font.pixelSize: Theme.fontSizeMedium
                font.bold: true
                color: Theme.primaryColor
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.parent.width
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (nextMeetingDate === "") return ""
                    var parts = nextMeetingDate.split(" - ")
                    if (parts.length === 2) {
                        return parts[1] // "16:00 UTC"
                    }
                    return ""
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: nextMeetingDate === ""
            text: qsTr("No upcoming meeting")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
        }
    }
}

