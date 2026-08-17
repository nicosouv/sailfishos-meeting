#ifndef MEETINGSOURCES_H
#define MEETINGSOURCES_H

#include <QString>
#include <QStringList>

// The logs live in two directories: the Mer project meetings (2011 up to
// February 2020) and the Sailfish OS community meetings that took over in
// March 2020. Both share the same layout and file naming scheme.
namespace MeetingSources {

static const QString BaseUrl = QStringLiteral("https://irclogs.sailfishos.org/meetings");
static const QString Mer = QStringLiteral("mer-meeting");
static const QString SailfishOs = QStringLiteral("sailfishos-meeting");

static const int MerFirstYear = 2011;
static const int MerLastYear = 2020;
static const int SailfishOsFirstYear = 2020;

// Series that can hold meetings for the given year, newest first
inline QStringList seriesForYear(int year)
{
    QStringList series;
    if (year >= SailfishOsFirstYear) {
        series.append(SailfishOs);
    }
    if (year >= MerFirstYear && year <= MerLastYear) {
        series.append(Mer);
    }
    return series;
}

inline QString yearIndexUrl(const QString &series, int year)
{
    return QString("%1/%2/%3/").arg(BaseUrl).arg(series).arg(year);
}

}

#endif // MEETINGSOURCES_H
