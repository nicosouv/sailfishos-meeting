#include "meetingmanager.h"
#include "ircmessage.h"
#include "meetingtopic.h"
#include "meetingstatistics.h"
#include <QRegularExpression>
#include <QDebug>
#include <QDateTime>
#include <QMap>
#include <QTime>

MeetingManager::MeetingManager(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_settings(new QSettings(this))
    , m_loading(false)
{
}

void MeetingManager::setLoading(bool loading)
{
    if (m_loading != loading) {
        m_loading = loading;
        emit loadingChanged();
    }
}

void MeetingManager::setError(const QString &error)
{
    if (m_error != error) {
        m_error = error;
        emit errorChanged();
    }
}

QVariantList MeetingManager::getAvailableYears()
{
    QVariantList years;
    int currentYear = QDateTime::currentDateTime().date().year();

    // From 2020 to current year
    for (int year = currentYear; year >= 2020; --year) {
        years.append(year);
    }

    return years;
}

void MeetingManager::fetchMeetingsForYear(int year)
{
    setLoading(true);
    setError("");

    QString url = QString("https://irclogs.sailfishos.org/meetings/sailfishos-meeting/%1/").arg(year);

    QNetworkRequest request(url);
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, &MeetingManager::onMeetingListReplyFinished);
}

void MeetingManager::onMeetingListReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;

    setLoading(false);

    if (reply->error() != QNetworkReply::NoError) {
        setError(reply->errorString());
        reply->deleteLater();
        return;
    }

    QString html = QString::fromUtf8(reply->readAll());
    reply->deleteLater();

    QList<Meeting*> meetings = parseMeetingList(html);

    QVariantList meetingVariants;
    for (Meeting *meeting : meetings) {
        meetingVariants.append(QVariant::fromValue(meeting));
    }

    emit meetingsLoaded(meetingVariants);
}

QList<Meeting*> MeetingManager::parseMeetingList(const QString &html)
{
    QList<Meeting*> meetings;

    // Match pattern: href="sailfishos-meeting.2024-12-12-08.01.html"
    QRegularExpression re("href=\"(sailfishos-meeting\\.\\d{4}-\\d{2}-\\d{2}-\\d{2}\\.\\d{2}\\.html)\"");
    QRegularExpressionMatchIterator i = re.globalMatch(html);

    while (i.hasNext()) {
        QRegularExpressionMatch match = i.next();
        QString filename = match.captured(1);

        // Avoid duplicates (.log.html versions)
        if (!filename.contains(".log.html")) {
            Meeting *meeting = new Meeting(filename, this);
            meetings.append(meeting);
        }
    }

    // Sort by date descending (newest first)
    std::sort(meetings.begin(), meetings.end(),
              [](const Meeting *a, const Meeting *b) {
                  return a->dateTime() > b->dateTime();
              });

    return meetings;
}

QString MeetingManager::fetchHtmlContent(const QString &url)
{
    QNetworkRequest request(url);
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, &MeetingManager::onHtmlContentReplyFinished);

    return QString(); // Will emit signal when loaded
}

void MeetingManager::onHtmlContentReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;

    if (reply->error() != QNetworkReply::NoError) {
        setError(reply->errorString());
        reply->deleteLater();
        return;
    }

    QString content = QString::fromUtf8(reply->readAll());
    reply->deleteLater();

    emit htmlContentLoaded(content);
}

QVariantList MeetingManager::parseTopicsFromHtml(const QString &html)
{
    QVariantList topics;

    // Extract topics from ordered list items
    QRegularExpression topicRe("<li><a href=\"#topic-\\d+\">([^<]+)</a>");
    QRegularExpressionMatchIterator i = topicRe.globalMatch(html);

    while (i.hasNext()) {
        QRegularExpressionMatch match = i.next();
        QString topicTitle = match.captured(1);

        // Clean HTML entities
        topicTitle.replace("&nbsp;", " ");
        topicTitle.replace("&lt;", "<");
        topicTitle.replace("&gt;", ">");
        topicTitle.replace("&amp;", "&");

        QStringList items;
        MeetingTopic *topic = new MeetingTopic(topicTitle, items, this);
        topics.append(QVariant::fromValue(topic));
    }

    return topics;
}

QVariantList MeetingManager::parseIrcMessagesFromHtml(const QString &html)
{
    QVariantList messages;

    // Extract text from <pre> tag
    QRegularExpression preRe("<pre>(.*)</pre>", QRegularExpression::DotMatchesEverythingOption);
    QRegularExpressionMatch preMatch = preRe.match(html);

    if (!preMatch.hasMatch()) {
        return messages;
    }

    QString preContent = preMatch.captured(1);

    // Split into lines
    QStringList lines = preContent.split('\n', QString::SkipEmptyParts);

    for (const QString &line : lines) {
        // Parse IRC message format: HH:MM:SS <username> message
        // or: HH:MM:SS * username action
        // or: HH:MM:SS <username> #command

        QString cleanLine = line;
        // Remove HTML tags
        cleanLine.replace(QRegularExpression("<[^>]*>"), "");
        // Decode HTML entities
        cleanLine.replace("&lt;", "<");
        cleanLine.replace("&gt;", ">");
        cleanLine.replace("&amp;", "&");
        cleanLine.replace("&nbsp;", " ");

        // Match timestamp and rest
        QRegularExpression lineRe("^(\\d{2}:\\d{2}:\\d{2})\\s+(.+)$");
        QRegularExpressionMatch lineMatch = lineRe.match(cleanLine);

        if (!lineMatch.hasMatch()) {
            continue;
        }

        QString timestamp = lineMatch.captured(1);
        QString rest = lineMatch.captured(2);

        QString username;
        QString message;

        // Check for action (* username does something)
        if (rest.startsWith("* ")) {
            int spacePos = rest.indexOf(' ', 2);
            if (spacePos > 0) {
                username = rest.mid(2, spacePos - 2);
                message = rest.mid(spacePos + 1);
            }
        }
        // Check for regular message (<username> message)
        else if (rest.startsWith('<')) {
            int endBracket = rest.indexOf('>');
            if (endBracket > 0) {
                username = rest.mid(1, endBracket - 1);
                message = rest.mid(endBracket + 2);
            }
        }
        // System message
        else {
            username = "";
            message = rest;
        }

        IrcMessage *msg = new IrcMessage(timestamp, username, message, this);
        messages.append(QVariant::fromValue(msg));
    }

    return messages;
}

MeetingStatistics* MeetingManager::calculateStatistics(const QVariantList &messages)
{
    MeetingStatistics *stats = new MeetingStatistics(this);

    if (messages.isEmpty()) {
        return stats;
    }

    // Count messages and track participants
    QMap<QString, int> participantCounts;
    int topicCount = 0;
    int actionCount = 0;
    QString firstTimestamp;
    QString lastTimestamp;

    for (const QVariant &var : messages) {
        IrcMessage *msg = qvariant_cast<IrcMessage*>(var);
        if (!msg) continue;

        // Track first and last timestamp
        if (firstTimestamp.isEmpty()) {
            firstTimestamp = msg->timestamp();
        }
        lastTimestamp = msg->timestamp();

        // Count by participant
        if (!msg->username().isEmpty()) {
            participantCounts[msg->username()]++;
        }

        // Count topics
        if (msg->isTopic()) {
            topicCount++;
        }

        // Count actions
        if (msg->isAction()) {
            actionCount++;
        }
    }

    // Set message count
    stats->setMessageCount(messages.count());

    // Set participant count
    stats->setParticipantCount(participantCounts.count());

    // Find top contributor
    QString topContributor;
    int topCount = 0;
    for (auto it = participantCounts.constBegin(); it != participantCounts.constEnd(); ++it) {
        if (it.value() > topCount) {
            topCount = it.value();
            topContributor = it.key();
        }
    }
    stats->setTopContributor(topContributor, topCount);

    // Calculate duration
    if (!firstTimestamp.isEmpty() && !lastTimestamp.isEmpty()) {
        QTime start = QTime::fromString(firstTimestamp, "HH:mm:ss");
        QTime end = QTime::fromString(lastTimestamp, "HH:mm:ss");

        if (start.isValid() && end.isValid()) {
            int seconds = start.secsTo(end);
            int hours = seconds / 3600;
            int minutes = (seconds % 3600) / 60;

            QString duration;
            if (hours > 0) {
                duration = QString("%1h %2m").arg(hours).arg(minutes);
            } else {
                duration = QString("%1m").arg(minutes);
            }
            stats->setDuration(duration);
        }
    }

    stats->setTopicCount(topicCount);
    stats->setActionCount(actionCount);

    return stats;
}

bool MeetingManager::isFavorite(const QString &meetingId) const
{
    QStringList favorites = m_settings->value("favorites").toStringList();
    return favorites.contains(meetingId);
}

void MeetingManager::toggleFavorite(const QString &meetingId)
{
    QStringList favorites = m_settings->value("favorites").toStringList();

    if (favorites.contains(meetingId)) {
        favorites.removeAll(meetingId);
    } else {
        favorites.append(meetingId);
    }

    m_settings->setValue("favorites", favorites);
    emit favoritesChanged();
}

QStringList MeetingManager::getFavorites() const
{
    return m_settings->value("favorites").toStringList();
}

bool MeetingManager::isRead(const QString &meetingId) const
{
    QStringList readMeetings = m_settings->value("readMeetings").toStringList();
    return readMeetings.contains(meetingId);
}

void MeetingManager::markAsRead(const QString &meetingId)
{
    QStringList readMeetings = m_settings->value("readMeetings").toStringList();

    if (!readMeetings.contains(meetingId)) {
        readMeetings.append(meetingId);
        m_settings->setValue("readMeetings", readMeetings);
        emit readStatusChanged();
    }
}

void MeetingManager::fetchNextMeetingDate()
{
    // Get current year's meetings to find the most recent one
    int currentYear = QDateTime::currentDateTime().date().year();
    QString url = QString("https://irclogs.sailfishos.org/meetings/sailfishos-meeting/%1/").arg(currentYear);

    QNetworkRequest request(url);
    QNetworkReply *reply = m_networkManager->get(request);

    // Create a lambda to handle the meeting list for next meeting date
    connect(reply, &QNetworkReply::finished, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            reply->deleteLater();
            return;
        }

        QString html = QString::fromUtf8(reply->readAll());
        reply->deleteLater();

        QList<Meeting*> meetings = parseMeetingList(html);

        if (meetings.isEmpty()) {
            return;
        }

        // Get the most recent meeting (already sorted by date descending)
        Meeting *mostRecent = meetings.first();

        // Fetch the log content of the most recent meeting
        QNetworkRequest logRequest(mostRecent->logUrl());
        QNetworkReply *logReply = m_networkManager->get(logRequest);
        connect(logReply, &QNetworkReply::finished, this, &MeetingManager::onNextMeetingContentReplyFinished);

        // Clean up meetings
        qDeleteAll(meetings);
    });
}

void MeetingManager::onNextMeetingContentReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;

    if (reply->error() != QNetworkReply::NoError) {
        reply->deleteLater();
        return;
    }

    QString content = QString::fromUtf8(reply->readAll());
    reply->deleteLater();

    QString nextMeetingDate = parseNextMeetingFromLog(content);

    if (!nextMeetingDate.isEmpty()) {
        // Also extract the raw ISO date
        QRegularExpression re("#info\\s+Next meeting will be held on.*?(\\d{4}-\\d{2}-\\d{2}T\\d{4}Z)");
        QRegularExpressionMatch match = re.match(content);
        QString rawDate = match.hasMatch() ? match.captured(1) : "";

        m_settings->setValue("nextMeetingDate", nextMeetingDate);
        m_settings->setValue("nextMeetingDateRaw", rawDate);
        emit nextMeetingDateChanged(nextMeetingDate, rawDate);
    }
}

QString MeetingManager::parseNextMeetingFromLog(const QString &html)
{
    // Look for pattern: "#info Next meeting will be held on ... 2025-11-20T1600Z"
    // Also try with different formats
    QRegularExpression re("#info\\s+Next meeting will be held on.*?(\\d{4}-\\d{2}-\\d{2}T\\d{4}Z)");
    QRegularExpressionMatch match = re.match(html);

    if (!match.hasMatch()) {
        qDebug() << "No next meeting date found in log";
        return QString();
    }

    QString dateStr = match.captured(1);
    qDebug() << "Found next meeting date string:" << dateStr;

    // Parse the date format: 2025-11-20T1600Z
    QDateTime meetingDateTime = QDateTime::fromString(dateStr, "yyyy-MM-ddTHHmmZ");
    meetingDateTime.setTimeSpec(Qt::UTC);

    if (!meetingDateTime.isValid()) {
        qDebug() << "Failed to parse date:" << dateStr;
        return QString();
    }

    // Check if the date is in the future
    QDateTime now = QDateTime::currentDateTimeUtc();
    qDebug() << "Meeting datetime:" << meetingDateTime << "Now:" << now;

    if (meetingDateTime > now) {
        // Format for display
        QString formatted = meetingDateTime.toString("dddd d MMMM yyyy - HH:mm") + " UTC";
        qDebug() << "Next meeting formatted:" << formatted;
        return formatted;
    } else {
        qDebug() << "Meeting date is in the past";
    }

    return QString();
}

QString MeetingManager::getNextMeetingDate() const
{
    return m_settings->value("nextMeetingDate").toString();
}
