#include "meetingstatistics.h"

MeetingStatistics::MeetingStatistics(QObject *parent)
    : QObject(parent)
    , m_messageCount(0)
    , m_participantCount(0)
    , m_topContributorCount(0)
    , m_topicCount(0)
    , m_actionCount(0)
{
}
