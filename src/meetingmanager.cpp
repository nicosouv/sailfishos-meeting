#include "meetingmanager.h"
#include "ircmessage.h"
#include "meetingtopic.h"
#include "meetingstatistics.h"
#include <QRegularExpression>
#include <QDebug>
#include <QDateTime>
#include <QMap>
#include <QTime>
#include <QFile>
#include <QTextStream>
#include <QDesktopServices>
#include <QUrl>
#include <QNetworkDiskCache>
#include <QQmlEngine>
#include <QStandardPaths>
#include <QDir>
#include <algorithm>
#include <functional>

MeetingManager::MeetingManager(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_settings(new QSettings(this))
    , m_loading(false)
{
    // Keep favorites/read status in memory; delegates query them in bindings
    m_favorites = m_settings->value("favorites").toStringList();
    m_readMeetings = m_settings->value("readMeetings").toStringList();

    // Past meeting pages are immutable, cache them on disk
    QNetworkDiskCache *diskCache = new QNetworkDiskCache(this);
    diskCache->setCacheDirectory(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/network");
    m_networkManager->setCache(diskCache);
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

QString MeetingManager::myNick() const
{
    return m_settings->value("myNick").toString();
}

void MeetingManager::setMyNick(const QString &nick)
{
    if (myNick() != nick) {
        m_settings->setValue("myNick", nick);
        emit myNickChanged();
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

void MeetingManager::fetchAvailableYears()
{
    QNetworkRequest request(QUrl("https://irclogs.sailfishos.org/meetings/sailfishos-meeting/"));
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, &MeetingManager::onYearListReplyFinished);
}

void MeetingManager::onYearListReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;

    if (reply->error() != QNetworkReply::NoError) {
        reply->deleteLater();
        return; // Keep the fallback year list
    }

    QString html = QString::fromUtf8(reply->readAll());
    reply->deleteLater();

    // Match year directory links: href="2024/"
    QRegularExpression re("href=\"(\\d{4})/\"");
    QRegularExpressionMatchIterator i = re.globalMatch(html);

    QList<int> years;
    while (i.hasNext()) {
        int year = i.next().captured(1).toInt();
        if (!years.contains(year)) {
            years.append(year);
        }
    }

    if (years.isEmpty()) {
        return;
    }

    std::sort(years.begin(), years.end(), std::greater<int>());

    QVariantList yearList;
    for (int year : years) {
        yearList.append(year);
    }

    emit yearsLoaded(yearList);
}

Meeting* MeetingManager::createMeeting(const QString &filename)
{
    Meeting *meeting = new Meeting(filename);
    QQmlEngine::setObjectOwnership(meeting, QQmlEngine::JavaScriptOwnership);
    return meeting;
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

QNetworkReply* MeetingManager::retryFromCache(QNetworkReply *reply)
{
    // Fall back to the disk cache when the network is unavailable
    QNetworkRequest request = reply->request();
    if (request.attribute(QNetworkRequest::CacheLoadControlAttribute).toInt()
            == QNetworkRequest::AlwaysCache) {
        return nullptr; // Already a cache-only attempt
    }
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysCache);
    return m_networkManager->get(request);
}

void MeetingManager::onMeetingListReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;

    if (reply->error() != QNetworkReply::NoError) {
        QNetworkReply *cached = retryFromCache(reply);
        if (cached) {
            connect(cached, &QNetworkReply::finished, this, &MeetingManager::onMeetingListReplyFinished);
            reply->deleteLater();
            return;
        }
        setLoading(false);
        setError(reply->errorString());
        reply->deleteLater();
        return;
    }

    setLoading(false);

    QString html = QString::fromUtf8(reply->readAll());
    reply->deleteLater();

    QList<Meeting*> meetings = parseMeetingList(html);

    QVariantList meetingVariants;
    for (Meeting *meeting : meetings) {
        // Let the QML engine delete meetings once no page references them
        QQmlEngine::setObjectOwnership(meeting, QQmlEngine::JavaScriptOwnership);
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
            Meeting *meeting = new Meeting(filename);
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

void MeetingManager::fetchHtmlContent(const QString &url)
{
    setLoading(true);
    setError("");

    QNetworkRequest request(url);
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, &MeetingManager::onHtmlContentReplyFinished);
}

void MeetingManager::onHtmlContentReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;

    if (reply->error() != QNetworkReply::NoError) {
        QNetworkReply *cached = retryFromCache(reply);
        if (cached) {
            connect(cached, &QNetworkReply::finished, this, &MeetingManager::onHtmlContentReplyFinished);
            reply->deleteLater();
            return;
        }
        setLoading(false);
        setError(reply->errorString());
        reply->deleteLater();
        return;
    }

    setLoading(false);

    QString url = reply->request().url().toString();
    QString content = QString::fromUtf8(reply->readAll());
    reply->deleteLater();

    emit htmlContentLoaded(url, content);
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
        MeetingTopic *topic = new MeetingTopic(topicTitle, items);
        QQmlEngine::setObjectOwnership(topic, QQmlEngine::JavaScriptOwnership);
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

    QRegularExpression tagRe("<[^>]*>");
    QRegularExpression lineRe("^(\\d{2}:\\d{2}:\\d{2})\\s+(.+)$");

    for (const QString &line : lines) {
        // Parse IRC message format: HH:MM:SS <username> message
        // or: HH:MM:SS * username action
        // or: HH:MM:SS <username> #command

        QString cleanLine = line;
        // Remove HTML tags
        cleanLine.replace(tagRe, "");
        // Decode HTML entities
        cleanLine.replace("&lt;", "<");
        cleanLine.replace("&gt;", ">");
        cleanLine.replace("&amp;", "&");
        cleanLine.replace("&nbsp;", " ");

        // Match timestamp and rest
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

        IrcMessage *msg = new IrcMessage(timestamp, username, message);
        QQmlEngine::setObjectOwnership(msg, QQmlEngine::JavaScriptOwnership);
        messages.append(QVariant::fromValue(msg));
    }

    return messages;
}

MeetingStatistics* MeetingManager::calculateStatistics(const QVariantList &messages)
{
    MeetingStatistics *stats = new MeetingStatistics();
    QQmlEngine::setObjectOwnership(stats, QQmlEngine::JavaScriptOwnership);

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

void MeetingManager::searchYear(int year, const QString &query)
{
    if (m_scanActive) {
        return; // One scan at a time
    }

    m_scanActive = true;
    m_scanQuery = query;
    m_scanResults.clear();
    qDeleteAll(m_scanMeetings);
    m_scanMeetings.clear();
    m_scanIndex = 0;
    setError("");

    QString url = QString("https://irclogs.sailfishos.org/meetings/sailfishos-meeting/%1/").arg(year);
    QNetworkRequest request(url);
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, &MeetingManager::onScanListReplyFinished);
}

void MeetingManager::onScanListReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;

    if (reply->error() != QNetworkReply::NoError) {
        QNetworkReply *cached = retryFromCache(reply);
        if (cached) {
            connect(cached, &QNetworkReply::finished, this, &MeetingManager::onScanListReplyFinished);
            reply->deleteLater();
            return;
        }
        setError(reply->errorString());
        reply->deleteLater();
        m_scanActive = false;
        emit yearScanResults(QVariantList());
        return;
    }

    QString html = QString::fromUtf8(reply->readAll());
    reply->deleteLater();

    m_scanMeetings = parseMeetingList(html);
    emit yearScanProgress(0, m_scanMeetings.count());
    fetchNextScanLog();
}

void MeetingManager::fetchNextScanLog()
{
    if (m_scanIndex >= m_scanMeetings.count()) {
        m_scanActive = false;
        emit yearScanResults(m_scanResults);
        qDeleteAll(m_scanMeetings);
        m_scanMeetings.clear();
        return;
    }

    Meeting *meeting = m_scanMeetings.at(m_scanIndex);
    QNetworkRequest request(QUrl(meeting->logUrl()));
    // Past logs are immutable: serve straight from the disk cache when possible
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::PreferCache);
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, &MeetingManager::onScanLogReplyFinished);
}

void MeetingManager::onScanLogReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;

    if (reply->error() == QNetworkReply::NoError && m_scanIndex < m_scanMeetings.count()) {
        QString html = QString::fromUtf8(reply->readAll());
        scanLogContent(html, m_scanMeetings.at(m_scanIndex));
    }
    reply->deleteLater();

    m_scanIndex++;
    emit yearScanProgress(m_scanIndex, m_scanMeetings.count());
    fetchNextScanLog();
}

void MeetingManager::scanLogContent(const QString &html, Meeting *meeting)
{
    QRegularExpression preRe("<pre>(.*)</pre>", QRegularExpression::DotMatchesEverythingOption);
    QRegularExpressionMatch preMatch = preRe.match(html);
    if (!preMatch.hasMatch()) {
        return;
    }

    QStringList lines = preMatch.captured(1).split('\n', QString::SkipEmptyParts);

    QRegularExpression tagRe("<[^>]*>");
    QRegularExpression lineRe("^(\\d{2}:\\d{2}:\\d{2})\\s+(.+)$");
    const int maxResults = 500;

    for (const QString &line : lines) {
        if (m_scanResults.count() >= maxResults) {
            return;
        }

        QString cleanLine = line;
        cleanLine.replace(tagRe, "");
        cleanLine.replace("&lt;", "<");
        cleanLine.replace("&gt;", ">");
        cleanLine.replace("&amp;", "&");
        cleanLine.replace("&nbsp;", " ");

        QRegularExpressionMatch lineMatch = lineRe.match(cleanLine);
        if (!lineMatch.hasMatch()) {
            continue;
        }

        QString timestamp = lineMatch.captured(1);
        QString rest = lineMatch.captured(2);

        QString username;
        QString message;
        if (rest.startsWith('<')) {
            int endBracket = rest.indexOf('>');
            if (endBracket > 0) {
                username = rest.mid(1, endBracket - 1);
                message = rest.mid(endBracket + 2);
            }
        } else {
            message = rest;
        }

        bool matches;
        if (m_scanQuery.isEmpty()) {
            // Actions mode: collect meeting decisions and assignments
            matches = message.startsWith("#action", Qt::CaseInsensitive)
                    || message.startsWith("#agreed", Qt::CaseInsensitive);
        } else {
            matches = message.contains(m_scanQuery, Qt::CaseInsensitive)
                    || username.contains(m_scanQuery, Qt::CaseInsensitive);
        }

        if (matches) {
            QVariantMap result;
            result["meetingTitle"] = meeting->title();
            result["meetingDate"] = meeting->date();
            result["filename"] = meeting->filename();
            result["timestamp"] = timestamp;
            result["username"] = username;
            result["message"] = message;
            m_scanResults.append(result);
        }
    }
}

bool MeetingManager::isFavorite(const QString &meetingId) const
{
    return m_favorites.contains(meetingId);
}

void MeetingManager::toggleFavorite(const QString &meetingId)
{
    if (m_favorites.removeAll(meetingId) == 0) {
        m_favorites.append(meetingId);
    }

    m_settings->setValue("favorites", m_favorites);
    emit favoritesChanged();
}

QStringList MeetingManager::getFavorites() const
{
    return m_favorites;
}

bool MeetingManager::isRead(const QString &meetingId) const
{
    return m_readMeetings.contains(meetingId);
}

void MeetingManager::markAsRead(const QString &meetingId)
{
    if (!m_readMeetings.contains(meetingId)) {
        m_readMeetings.append(meetingId);
        m_settings->setValue("readMeetings", m_readMeetings);
        emit readStatusChanged();
    }
}

void MeetingManager::fetchNextMeetingDate()
{
    int currentYear = QDateTime::currentDateTime().date().year();

    // Try current year first
    QString url = QString("https://irclogs.sailfishos.org/meetings/sailfishos-meeting/%1/").arg(currentYear);

    QNetworkRequest request(url);
    QNetworkReply *reply = m_networkManager->get(request);

    // Create a lambda to handle the meeting list for next meeting date
    connect(reply, &QNetworkReply::finished, [this, reply, currentYear]() {
        QString html;
        QList<Meeting*> currentYearMeetings;

        if (reply->error() == QNetworkReply::NoError) {
            html = QString::fromUtf8(reply->readAll());
            currentYearMeetings = parseMeetingList(html);
        }
        reply->deleteLater();

        // Also check previous year to handle year boundary and wrong system clock
        int previousYear = currentYear - 1;
        QString prevUrl = QString("https://irclogs.sailfishos.org/meetings/sailfishos-meeting/%1/").arg(previousYear);
        QNetworkRequest prevRequest(prevUrl);
        QNetworkReply *prevReply = m_networkManager->get(prevRequest);

        connect(prevReply, &QNetworkReply::finished, this, [this, prevReply, previousYear, currentYearMeetings]() mutable {
            QList<Meeting*> allMeetings = currentYearMeetings;

            if (prevReply->error() == QNetworkReply::NoError) {
                QString prevHtml = QString::fromUtf8(prevReply->readAll());
                QList<Meeting*> prevYearMeetings = parseMeetingList(prevHtml);
                allMeetings.append(prevYearMeetings);
            }
            prevReply->deleteLater();

            if (allMeetings.isEmpty()) {
                return;
            }

            // Sort all meetings by date descending to get the truly most recent one
            std::sort(allMeetings.begin(), allMeetings.end(),
                      [](const Meeting *a, const Meeting *b) {
                          return a->dateTime() > b->dateTime();
                      });

            // Get the most recent meeting across both years
            Meeting *mostRecent = allMeetings.first();

            fetchLogForNextMeeting(mostRecent);

            // Clean up meetings
            qDeleteAll(allMeetings);
        });
    });
}

void MeetingManager::fetchLogForNextMeeting(Meeting *meeting)
{

    // Fetch the log content of the meeting
    QNetworkRequest logRequest(meeting->logUrl());
    QNetworkReply *logReply = m_networkManager->get(logRequest);
    connect(logReply, &QNetworkReply::finished, this, &MeetingManager::onNextMeetingContentReplyFinished);
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

    QString rawDate;
    QString agendaUrl;
    QString nextMeetingDate = parseNextMeetingFromLog(content, &rawDate, &agendaUrl);

    if (!nextMeetingDate.isEmpty()) {
        m_settings->setValue("nextMeetingDate", nextMeetingDate);
        m_settings->setValue("nextMeetingDateRaw", rawDate);
        m_settings->setValue("nextMeetingAgendaUrl", agendaUrl);
        emit nextMeetingDateChanged(nextMeetingDate, rawDate, agendaUrl);
    } else if (!m_settings->value("nextMeetingDate").toString().isEmpty()) {
        // No upcoming meeting announced: clear the stale stored date
        m_settings->remove("nextMeetingDate");
        m_settings->remove("nextMeetingDateRaw");
        m_settings->remove("nextMeetingAgendaUrl");
        emit nextMeetingDateChanged(QString(), QString(), QString());
    }
}

QString MeetingManager::parseNextMeetingFromLog(const QString &html, QString *rawDate, QString *agendaUrl)
{
    // The meeting thread on the forum hosts the agenda for the next meeting too
    if (agendaUrl) {
        QRegularExpression linkRe("(https://forum\\.sailfishos\\.org/t/[^\\s<\"&]+)");
        QRegularExpressionMatch linkMatch = linkRe.match(html);
        if (linkMatch.hasMatch()) {
            *agendaUrl = linkMatch.captured(1);
        }
    }

    // Look for pattern: "#info Next meeting will be held on ... 2025-11-20T1600Z"
    // Format is: YYYY-MM-DDTHHMM Z (no colon in time)
    // The HTML contains span tags, so we need to account for them: #info </span><span class="cmdline">Next meeting...
    QRegularExpression re("#info\\s*(?:</span>)?(?:<span[^>]*>)?\\s*Next meeting will be held on.*?(\\d{4}-\\d{2}-\\d{2}T\\d{4})Z");
    QRegularExpressionMatch match = re.match(html);

    if (!match.hasMatch()) {
        return QString();
    }

    QString dateStr = match.captured(1);

    // Parse the date format: 2024-11-28T0800 (without Z)
    // Format is yyyy-MM-ddTHHmm
    QDateTime meetingDateTime = QDateTime::fromString(dateStr, "yyyy-MM-ddTHHmm");
    meetingDateTime.setTimeSpec(Qt::UTC);

    if (!meetingDateTime.isValid()) {
        return QString();
    }

    // Check if the date is in the future
    QDateTime now = QDateTime::currentDateTimeUtc();

    if (meetingDateTime > now) {
        if (rawDate) {
            *rawDate = dateStr + "Z";
        }
        // Format for display
        QString formatted = meetingDateTime.toString("dddd d MMMM yyyy") + " - " + meetingDateTime.toString("HH:mm") + " UTC";
        return formatted;
    }

    return QString();
}

QString MeetingManager::getNextMeetingDate() const
{
    return m_settings->value("nextMeetingDate").toString();
}

QString MeetingManager::getNextMeetingAgendaUrl() const
{
    return m_settings->value("nextMeetingAgendaUrl").toString();
}

void MeetingManager::saveIcsFile(const QString &content)
{
    // Write to the app cache dir rather than a predictable world-writable /tmp path
    QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(dir);
    QString path = dir + "/sfos-meeting.ics";

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return;
    }

    QTextStream out(&file);
    out << content;
    file.close();

    // Open the ICS file with the default calendar app
    QUrl fileUrl = QUrl::fromLocalFile(path);
    QDesktopServices::openUrl(fileUrl);
}
