#include "meeting.h"
#include "meetingsources.h"
#include <QRegularExpression>
#include <QDebug>

Meeting::Meeting(const QString &filename, QObject *parent)
    : QObject(parent)
    , m_filename(filename)
    , m_series(MeetingSources::SailfishOs)
{
    parseFilename();
}

void Meeting::parseFilename()
{
    // Parse pattern: sailfishos-meeting.2024-12-12-08.01.html
    //            or: mer-meeting.2019-01-10-09.00.html
    QRegularExpression re("(sailfishos-meeting|mer-meeting)\\.(\\d{4})-(\\d{2})-(\\d{2})-(\\d{2})\\.(\\d{2})");
    QRegularExpressionMatch match = re.match(m_filename);

    if (match.hasMatch()) {
        m_series = match.captured(1);
        int year = match.captured(2).toInt();
        int month = match.captured(3).toInt();
        int day = match.captured(4).toInt();
        int hour = match.captured(5).toInt();
        int minute = match.captured(6).toInt();

        m_dateTime = QDateTime(QDate(year, month, day), QTime(hour, minute), Qt::UTC);
    } else {
        qWarning() << "Failed to parse meeting filename:" << m_filename;
    }
}

QString Meeting::baseUrl() const
{
    return QString("%1/%2").arg(MeetingSources::BaseUrl).arg(m_series);
}

QString Meeting::date() const
{
    return m_dateTime.date().toString("dd MMMM yyyy");
}

QString Meeting::time() const
{
    return m_dateTime.time().toString("HH:mm") + " UTC";
}

QString Meeting::seriesName() const
{
    return m_series == MeetingSources::Mer ? QStringLiteral("Mer") : QStringLiteral("Sailfish OS");
}

QString Meeting::title() const
{
    return QString("%1 Meeting - %2").arg(seriesName()).arg(date());
}

QString Meeting::url() const
{
    int year = m_dateTime.date().year();
    QString baseFilename = m_filename;
    baseFilename.replace(".log.html", ".html");
    return QString("%1/%2/%3").arg(baseUrl()).arg(year).arg(baseFilename);
}

QString Meeting::logUrl() const
{
    int year = m_dateTime.date().year();
    QString logFilename = m_filename;
    if (!logFilename.contains(".log.html")) {
        logFilename.replace(".html", ".log.html");
    }
    return QString("%1/%2/%3").arg(baseUrl()).arg(year).arg(logFilename);
}

QString Meeting::filename() const
{
    return m_filename;
}

QString Meeting::month() const
{
    return m_dateTime.date().toString("MMMM yyyy");
}
