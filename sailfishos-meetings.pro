# NOTICE:
#
# Application name defined in TARGET has a corresponding QML filename.
# If name defined in TARGET is changed, the following needs to be done
# to match new name:
#   - corresponding QML filename must be changed
#   - desktop icon filename must be changed
#   - desktop filename must be changed
#   - icon definition filename in desktop file must be changed
#   - translation filenames have to be changed

# The name of your application
TARGET = sailfishos-meetings

CONFIG += sailfishapp

QT += network

SOURCES += src/sailfishos-meetings.cpp \
    src/meetingmanager.cpp \
    src/meeting.cpp \
    src/ircmessage.cpp \
    src/meetingtopic.cpp \
    src/meetingstatistics.cpp

HEADERS += \
    src/meetingmanager.h \
    src/meeting.h \
    src/ircmessage.h \
    src/meetingtopic.h \
    src/meetingstatistics.h

OTHER_FILES += qml/sailfishos-meetings.qml \
    qml/cover/CoverPage.qml \
    qml/pages/YearSelectionPage.qml \
    qml/pages/MeetingListPage.qml \
    qml/pages/MeetingSummaryPage.qml \
    qml/pages/MeetingLogPage.qml \
    qml/pages/AboutPage.qml \
    rpm/sailfishos-meetings.spec \
    rpm/sailfishos-meetings.yaml \
    translations/*.ts \
    sailfishos-meetings.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 256x256

# to disable building translations every time, comment out the
# following CONFIG line
CONFIG += sailfishapp_i18n

# German translation is enabled as an example. If you aren't
# planning to localize your app, remember to comment out the
# following TRANSLATIONS line. And also do not forget to
# modify the localized app name in the the .desktop file.
TRANSLATIONS += translations/sailfishos-meetings-de.ts

DISTFILES += \
    rpm/sailfishos-meetings.changes
