#include "meetingmanager.h"
#include "ircmessage.h"
#include "meetingstatistics.h"
#include "meetingsources.h"
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
#include <QDirIterator>
#include <QFileInfo>
#include <algorithm>
#include <functional>

#ifndef APP_VERSION
#define APP_VERSION "dev"
#endif

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

QString MeetingManager::watchedNicks() const
{
    return m_settings->value("watchedNicks").toString();
}

void MeetingManager::setWatchedNicks(const QString &nicks)
{
    if (watchedNicks() != nicks) {
        m_settings->setValue("watchedNicks", nicks);
        emit watchedNicksChanged();
    }
}

QString MeetingManager::appVersion() const
{
    return QStringLiteral(APP_VERSION);
}

int MeetingManager::commandStyle() const
{
    return m_settings->value("commandStyle", 0).toInt();
}

void MeetingManager::setCommandStyle(int style)
{
    if (commandStyle() != style) {
        m_settings->setValue("commandStyle", style);
        emit commandStyleChanged();
    }
}

int MeetingManager::chatStyle() const
{
    return m_settings->value("chatStyle", 0).toInt();
}

void MeetingManager::setChatStyle(int style)
{
    if (chatStyle() != style) {
        m_settings->setValue("chatStyle", style);
        emit chatStyleChanged();
    }
}

QVariantList MeetingManager::getAvailableYears()
{
    QVariantList years;
    int currentYear = QDateTime::currentDateTime().date().year();

    // Sailfish OS meetings since 2020, Mer meetings before that
    for (int year = currentYear; year >= MeetingSources::MerFirstYear; --year) {
        years.append(year);
    }

    return years;
}

void MeetingManager::fetchAvailableYears()
{
    QStringList urls;
    urls << MeetingSources::BaseUrl + "/" + MeetingSources::SailfishOs + "/"
         << MeetingSources::BaseUrl + "/" + MeetingSources::Mer + "/";

    fetchIndexes(urls, [this](const QString &html, const QString &error) {
        Q_UNUSED(error)

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
            return; // Keep the fallback year list
        }

        std::sort(years.begin(), years.end(), std::greater<int>());

        QVariantList yearList;
        for (int year : years) {
            yearList.append(year);
        }

        emit yearsLoaded(yearList);
    });
}

void MeetingManager::fetchIndexes(const QStringList &urls,
                                  const std::function<void(const QString &, const QString &)> &callback)
{
    if (urls.isEmpty()) {
        callback(QString(), QString());
        return;
    }

    IndexFetch *fetch = new IndexFetch;
    fetch->pending = urls.count();
    fetch->callback = callback;

    for (const QString &url : urls) {
        QNetworkRequest request((QUrl(url)));
        QNetworkReply *reply = m_networkManager->get(request);
        connect(reply, &QNetworkReply::finished, this, [this, reply, fetch]() {
            handleIndexReply(reply, fetch);
        });
    }
}

void MeetingManager::fetchYearIndexes(int year,
                                      const std::function<void(const QString &, const QString &)> &callback)
{
    QStringList urls;
    for (const QString &series : MeetingSources::seriesForYear(year)) {
        urls << MeetingSources::yearIndexUrl(series, year);
    }
    fetchIndexes(urls, callback);
}

void MeetingManager::handleIndexReply(QNetworkReply *reply, IndexFetch *fetch)
{
    if (reply->error() != QNetworkReply::NoError) {
        QNetworkReply *cached = retryFromCache(reply);
        if (cached) {
            connect(cached, &QNetworkReply::finished, this, [this, cached, fetch]() {
                handleIndexReply(cached, fetch);
            });
            reply->deleteLater();
            return;
        }
        fetch->error = reply->errorString();
    } else {
        fetch->html += QString::fromUtf8(reply->readAll());
    }
    reply->deleteLater();

    if (--fetch->pending > 0) {
        return; // Wait for the other series
    }

    // One series missing for a given year is expected: only report an error
    // when nothing at all could be fetched
    fetch->callback(fetch->html, fetch->html.isEmpty() ? fetch->error : QString());
    delete fetch;
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

    fetchYearIndexes(year, [this](const QString &html, const QString &error) {
        setLoading(false);

        if (!error.isEmpty()) {
            setError(error);
            return;
        }

        QVariantList meetingVariants;
        for (Meeting *meeting : parseMeetingList(html)) {
            // Let the QML engine delete meetings once no page references them
            QQmlEngine::setObjectOwnership(meeting, QQmlEngine::JavaScriptOwnership);
            meetingVariants.append(QVariant::fromValue(meeting));
        }

        emit meetingsLoaded(meetingVariants);
    });
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

QList<Meeting*> MeetingManager::parseMeetingList(const QString &html)
{
    QList<Meeting*> meetings;

    // Match pattern: href="sailfishos-meeting.2024-12-12-08.01.html"
    //            or: href="mer-meeting.2019-01-10-09.00.html"
    QRegularExpression re("href=\"((?:sailfishos-meeting|mer-meeting)\\.\\d{4}-\\d{2}-\\d{2}-\\d{2}\\.\\d{2}\\.html)\"");
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

static QString plainText(const QString &html)
{
    QString text = html;
    text.remove(QRegularExpression("<[^>]*>"));
    text.replace("&nbsp;", " ");
    text.replace("&lt;", "<");
    text.replace("&gt;", ">");
    text.replace("&quot;", "\"");
    text.replace("&#39;", "'");
    text.replace("&amp;", "&");
    return text.simplified();
}

static QStringList orderedListItems(const QString &html, const QString &heading)
{
    QStringList items;

    QRegularExpression sectionRe("<h3>" + heading + "</h3>\\s*<ol>(.*?)</ol>",
                                 QRegularExpression::DotMatchesEverythingOption);
    QRegularExpressionMatch section = sectionRe.match(html);
    if (!section.hasMatch()) {
        return items;
    }

    QRegularExpression itemRe("<li>(.*?)</li>", QRegularExpression::DotMatchesEverythingOption);
    QRegularExpressionMatchIterator i = itemRe.globalMatch(section.captured(1));
    while (i.hasNext()) {
        QString item = plainText(i.next().captured(1));
        // Meetbot writes "(none)" when a section is empty
        if (!item.isEmpty() && item != "(none)") {
            items.append(item);
        }
    }

    return items;
}

QVariantMap MeetingManager::parseSummaryFromHtml(const QString &rawHtml)
{
    QVariantMap summary;

    // The published pages wrap their markup over several lines, even in the
    // middle of a tag: collapse whitespace before matching anything
    QString html = rawHtml;
    html.replace(QRegularExpression("\\s+"), " ");

    QRegularExpression startedRe("Meeting started by (\\S+) at ([\\d:]+) UTC");
    QRegularExpressionMatch started = startedRe.match(html);
    summary["chair"] = started.hasMatch() ? started.captured(1) : QString();
    summary["started"] = started.hasMatch() ? started.captured(2) : QString();

    QRegularExpression endedRe("Meeting ended at ([\\d:]+) UTC");
    QRegularExpressionMatch ended = endedRe.match(html);
    summary["ended"] = ended.hasMatch() ? ended.captured(1) : QString();

    // Every summary entry ends with its author and a link back to the log line:
    // <li>...<span class="details">(<a href="...#l-42">nick</a>, 16:00:26)</span>
    QString body = html.section("<h3>Meeting summary</h3>", 1).section("<h3>", 0, 0);
    QRegularExpression entryRe("<li>(.*?)<span class=\"details\">\\("
                               "<a href=['\"][^'\"]*#l-(\\d+)['\"]>([^<]*)</a>,\\s*([\\d:]+)\\)</span>",
                               QRegularExpression::DotMatchesEverythingOption);
    QRegularExpression typeRe("<(?:b|span) class=\"([A-Z]+)\">(.*?)</(?:b|span)>",
                              QRegularExpression::DotMatchesEverythingOption);

    QVariantList entries;
    QRegularExpressionMatchIterator i = entryRe.globalMatch(body);
    while (i.hasNext()) {
        QRegularExpressionMatch match = i.next();
        QString content = match.captured(1);

        QVariantMap entry;
        QRegularExpressionMatch typed = typeRe.match(content);
        if (typed.hasMatch()) {
            entry["type"] = typed.captured(1);
            entry["text"] = plainText(typed.captured(2));
        } else {
            // A bare link, logged with #link
            entry["type"] = QStringLiteral("LINK");
            entry["text"] = plainText(content);
        }

        if (entry["text"].toString().isEmpty()) {
            continue;
        }

        entry["line"] = match.captured(2).toInt();
        entry["nick"] = match.captured(3);
        entry["time"] = match.captured(4);
        entries.append(entry);
    }
    summary["entries"] = entries;

    summary["actions"] = orderedListItems(html, "Action items");

    // "People present (lines said)" holds "nick (42)" entries
    QVariantList people;
    QRegularExpression personRe("^(.*)\\s+\\((\\d+)\\)$");
    for (const QString &item : orderedListItems(html, "People present \\(lines said\\)")) {
        QRegularExpressionMatch person = personRe.match(item);
        if (!person.hasMatch()) {
            continue;
        }
        QVariantMap entry;
        entry["nick"] = person.captured(1);
        entry["lines"] = person.captured(2).toInt();
        people.append(entry);
    }
    summary["people"] = people;

    return summary;
}

QString MeetingManager::storageSize() const
{
    qint64 bytes = 0;

    QStringList dirs;
    dirs << QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    dirs << QFileInfo(m_settings->fileName()).absolutePath();

    QStringList visited;
    for (const QString &dir : dirs) {
        if (dir.isEmpty() || visited.contains(dir) || !QDir(dir).exists()) {
            continue;
        }
        visited.append(dir);

        QDirIterator it(dir, QDir::Files | QDir::NoSymLinks, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            bytes += it.fileInfo().size();
        }
    }

    if (bytes < 1024) {
        return QString("%1 B").arg(bytes);
    }
    if (bytes < 1024 * 1024) {
        return QString("%1 kB").arg(bytes / 1024.0, 0, 'f', 1);
    }
    return QString("%1 MB").arg(bytes / (1024.0 * 1024.0), 0, 'f', 1);
}

void MeetingManager::clearCache()
{
    if (QAbstractNetworkCache *cache = m_networkManager->cache()) {
        cache->clear();
    }
    emit storageSizeChanged();
}

void MeetingManager::clearHistory()
{
    m_favorites.clear();
    m_readMeetings.clear();
    m_settings->remove("favorites");
    m_settings->remove("readMeetings");
    m_settings->sync();

    emit favoritesChanged();
    emit readStatusChanged();
    emit storageSizeChanged();
}

QVariantList MeetingManager::parseIrcMessagesFromHtml(const QString &html)
{
    QVariantList messages;
    QList<IrcMessage*> parsed;

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
    // Each line carries its own anchor: <a name="l-42"></a>
    QRegularExpression anchorRe("<a name=\"l-(\\d+)\"");

    for (const QString &line : lines) {
        // Parse IRC message format: HH:MM:SS <username> message
        // or: HH:MM:SS * username action
        // or: HH:MM:SS <username> #command

        QRegularExpressionMatch anchor = anchorRe.match(line);
        int logLine = anchor.hasMatch() ? anchor.captured(1).toInt() : 0;

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
        bool isAction = false;

        // Check for action (* username does something)
        if (rest.startsWith("* ")) {
            int spacePos = rest.indexOf(' ', 2);
            if (spacePos > 0) {
                username = rest.mid(2, spacePos - 2);
                message = rest.mid(spacePos + 1);
                isAction = true;
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
        msg->setIsAction(isAction);
        msg->setLogLine(logLine);

        // Meetbot wraps a quoted answer over several "#info <nick> ..." lines:
        // show them as a single readable paragraph
        if (!parsed.isEmpty() && msg->continues(parsed.last())) {
            parsed.last()->appendBody(msg->body());
            delete msg;
            continue;
        }

        parsed.append(msg);
    }

    for (IrcMessage *msg : parsed) {
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
    m_scanResultCount = 0;
    m_scanTruncated = false;
    qDeleteAll(m_scanMeetings);
    m_scanMeetings.clear();
    m_scanNextIndex = 0;
    m_scanDone = 0;
    m_scanPending = 0;
    setError("");

    fetchYearIndexes(year, [this](const QString &html, const QString &error) {
        if (!m_scanActive) {
            return; // Cancelled while the index was loading
        }

        if (!error.isEmpty()) {
            setError(error);
            finishScan();
            return;
        }

        m_scanMeetings = parseMeetingList(html);
        emit yearScanProgress(0, m_scanMeetings.count());
        fetchMoreScanLogs();
    });
}

void MeetingManager::cancelScan()
{
    if (!m_scanActive) {
        return;
    }

    m_scanActive = false;
    for (QNetworkReply *reply : m_scanReplies) {
        reply->abort();
    }
    m_scanReplies.clear();
    m_scanPending = 0;
    m_scanNextIndex = m_scanMeetings.count();

    finishScan();
}

void MeetingManager::fetchMoreScanLogs()
{
    // A year holds a couple of dozen logs: fetch a few at a time so a scan
    // over a whole year does not take a minute on a phone connection
    static const int MaxParallelScans = 4;

    while (m_scanActive
           && m_scanPending < MaxParallelScans
           && m_scanNextIndex < m_scanMeetings.count()) {
        const int index = m_scanNextIndex++;

        QNetworkRequest request(QUrl(m_scanMeetings.at(index)->logUrl()));
        // Past logs are immutable: serve straight from the disk cache when possible
        request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::PreferCache);

        QNetworkReply *reply = m_networkManager->get(request);
        m_scanReplies.append(reply);
        m_scanPending++;

        connect(reply, &QNetworkReply::finished, this, [this, reply, index]() {
            onScanLogFinished(reply, index);
        });
    }

    if (m_scanPending == 0) {
        finishScan();
    }
}

void MeetingManager::onScanLogFinished(QNetworkReply *reply, int index)
{
    m_scanReplies.removeAll(reply);
    m_scanPending--;

    if (m_scanActive && reply->error() == QNetworkReply::NoError) {
        scanLogContent(QString::fromUtf8(reply->readAll()), m_scanMeetings.at(index), index);
    }
    reply->deleteLater();

    if (!m_scanActive) {
        return; // Cancelled: finishScan() already reported what we had
    }

    m_scanDone++;
    emit yearScanProgress(m_scanDone, m_scanMeetings.count());
    fetchMoreScanLogs();
}

void MeetingManager::finishScan()
{
    m_scanActive = false;

    // Logs come back out of order, restore the meeting order (newest first)
    QVariantList results;
    for (auto it = m_scanResults.constBegin(); it != m_scanResults.constEnd(); ++it) {
        results.append(it.value());
    }

    emit yearScanResults(results, m_scanTruncated);

    m_scanResults.clear();
    qDeleteAll(m_scanMeetings);
    m_scanMeetings.clear();
}

void MeetingManager::scanLogContent(const QString &html, Meeting *meeting, int index)
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
        if (m_scanResultCount >= maxResults) {
            m_scanTruncated = true;
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
            m_scanResults[index].append(result);
            m_scanResultCount++;
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

    fetchYearIndexes(currentYear, [this, currentYear](const QString &html, const QString &) {
        QList<Meeting*> currentYearMeetings = parseMeetingList(html);

        // Also check previous year to handle year boundary and wrong system clock
        fetchYearIndexes(currentYear - 1, [this, currentYearMeetings](const QString &prevHtml, const QString &) {
            QList<Meeting*> allMeetings = currentYearMeetings;
            allMeetings.append(parseMeetingList(prevHtml));

            if (allMeetings.isEmpty()) {
                return;
            }

            // Sort all meetings by date descending to get the truly most recent one
            std::sort(allMeetings.begin(), allMeetings.end(),
                      [](const Meeting *a, const Meeting *b) {
                          return a->dateTime() > b->dateTime();
                      });

            fetchLogForNextMeeting(allMeetings.first());

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

    // The announcement always ends with a machine readable stamp such as
    // "2025-11-20T1600Z", but its wording varies a lot:
    //   "#info Next meeting will be held on ..."
    //   "#info Next something (meeting / newsletter) will be held on ..."
    // so only anchor on "Next ... held on" and fall back to any stamp found.
    QRegularExpression announcedRe("Next\\b[^\\n]{0,200}?held on[^\\n]{0,200}?(\\d{4}-\\d{2}-\\d{2}T\\d{4})Z",
                                   QRegularExpression::CaseInsensitiveOption);
    QRegularExpression anyStampRe("(\\d{4}-\\d{2}-\\d{2}T\\d{4})Z");

    QString dateStr = lastFutureStamp(announcedRe.globalMatch(html));
    if (dateStr.isEmpty()) {
        dateStr = lastFutureStamp(anyStampRe.globalMatch(html));
    }

    if (dateStr.isEmpty()) {
        return QString();
    }

    QDateTime meetingDateTime = QDateTime::fromString(dateStr, "yyyy-MM-ddTHHmm");
    meetingDateTime.setTimeSpec(Qt::UTC);

    if (rawDate) {
        *rawDate = dateStr + "Z";
    }

    return meetingDateTime.toString("dddd d MMMM yyyy") + " - "
            + meetingDateTime.toString("HH:mm") + " UTC";
}

QString MeetingManager::lastFutureStamp(QRegularExpressionMatchIterator matches)
{
    // A log can mention several dates; keep the last upcoming one
    QDateTime now = QDateTime::currentDateTimeUtc();
    QString stamp;

    while (matches.hasNext()) {
        QString candidate = matches.next().captured(1);
        QDateTime dateTime = QDateTime::fromString(candidate, "yyyy-MM-ddTHHmm");
        dateTime.setTimeSpec(Qt::UTC);

        if (dateTime.isValid() && dateTime > now) {
            stamp = candidate;
        }
    }

    return stamp;
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
