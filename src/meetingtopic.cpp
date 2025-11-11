#include "meetingtopic.h"

MeetingTopic::MeetingTopic(const QString &title, const QStringList &items,
                           QObject *parent)
    : QObject(parent)
    , m_title(title)
    , m_items(items)
{
}
