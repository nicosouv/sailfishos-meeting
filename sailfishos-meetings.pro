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

QT += network qml

# Single source of truth for the version: the RPM spec, which the CI patches
APP_VERSION = $$system(sed -n 's/^Version:[[:space:]]*//p' $$PWD/rpm/sailfishos-meetings.spec)
isEmpty(APP_VERSION): APP_VERSION = dev
DEFINES += APP_VERSION=\\\"$$APP_VERSION\\\"

SOURCES += src/sailfishos-meetings.cpp \
    src/meetingmanager.cpp \
    src/meeting.cpp \
    src/ircmessage.cpp \
    src/meetingstatistics.cpp

HEADERS += \
    src/meetingmanager.h \
    src/meeting.h \
    src/meetingsources.h \
    src/ircmessage.h \
    src/meetingstatistics.h

OTHER_FILES += qml/sailfishos-meetings.qml \
    qml/cover/CoverPage.qml \
    qml/pages/YearSelectionPage.qml \
    qml/pages/MeetingListPage.qml \
    qml/pages/MeetingSummaryPage.qml \
    qml/pages/MeetingLogPage.qml \
    qml/pages/AboutPage.qml \
    qml/pages/SettingsPage.qml \
    qml/pages/YearScanPage.qml \
    qml/components/UserAvatar.qml \
    qml/components/UserColorManager.qml \
    qml/components/ChatMessage.qml \
    qml/components/CommandMessage.qml \
    qml/components/TextMarkup.js \
    qml/components/qmldir \
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
TRANSLATIONS += translations/sailfishos-meetings-de.ts \
    translations/sailfishos-meetings-fr.ts

DISTFILES += \
    rpm/sailfishos-meetings.changes \
    tests/tst_parsing.pro \
    tests/tst_parsing.cpp
