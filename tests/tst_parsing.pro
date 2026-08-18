# Host tests for the log and summary parsers. Built and run by the CI on a
# plain Qt 5 (no Sailfish SDK needed): qmake tests/tst_parsing.pro && make && ./tst_parsing
TEMPLATE = app
TARGET = tst_parsing
CONFIG += testcase console c++11
CONFIG -= app_bundle

# QtGui is needed for QDesktopServices, the tests still run headless
QT += testlib network qml gui

INCLUDEPATH += $$PWD/../src

SOURCES += tst_parsing.cpp \
    $$PWD/../src/meetingmanager.cpp \
    $$PWD/../src/meeting.cpp \
    $$PWD/../src/ircmessage.cpp \
    $$PWD/../src/meetingstatistics.cpp

HEADERS += \
    $$PWD/../src/meetingmanager.h \
    $$PWD/../src/meeting.h \
    $$PWD/../src/meetingsources.h \
    $$PWD/../src/ircmessage.h \
    $$PWD/../src/meetingstatistics.h
