#ifndef MEETINGSTATISTICS_H
#define MEETINGSTATISTICS_H

#include <QObject>
#include <QString>

class MeetingStatistics : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int messageCount READ messageCount CONSTANT)
    Q_PROPERTY(int participantCount READ participantCount CONSTANT)
    Q_PROPERTY(QString topContributor READ topContributor CONSTANT)
    Q_PROPERTY(int topContributorCount READ topContributorCount CONSTANT)
    Q_PROPERTY(QString duration READ duration CONSTANT)
    Q_PROPERTY(int topicCount READ topicCount CONSTANT)
    Q_PROPERTY(int actionCount READ actionCount CONSTANT)

public:
    explicit MeetingStatistics(QObject *parent = nullptr);

    int messageCount() const { return m_messageCount; }
    int participantCount() const { return m_participantCount; }
    QString topContributor() const { return m_topContributor; }
    int topContributorCount() const { return m_topContributorCount; }
    QString duration() const { return m_duration; }
    int topicCount() const { return m_topicCount; }
    int actionCount() const { return m_actionCount; }

    void setMessageCount(int count) { m_messageCount = count; }
    void setParticipantCount(int count) { m_participantCount = count; }
    void setTopContributor(const QString &name, int count) {
        m_topContributor = name;
        m_topContributorCount = count;
    }
    void setDuration(const QString &duration) { m_duration = duration; }
    void setTopicCount(int count) { m_topicCount = count; }
    void setActionCount(int count) { m_actionCount = count; }

private:
    int m_messageCount;
    int m_participantCount;
    QString m_topContributor;
    int m_topContributorCount;
    QString m_duration;
    int m_topicCount;
    int m_actionCount;
};

#endif // MEETINGSTATISTICS_H
