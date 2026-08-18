#ifndef MEETINGMANAGER_H
#define MEETINGMANAGER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QList>
#include <QSettings>
#include <QRegularExpression>
#include <functional>
#include "meeting.h"
#include "meetingstatistics.h"

class MeetingManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString myNick READ myNick WRITE setMyNick NOTIFY myNickChanged)
    Q_PROPERTY(QString watchedNicks READ watchedNicks WRITE setWatchedNicks NOTIFY watchedNicksChanged)
    Q_PROPERTY(int commandStyle READ commandStyle WRITE setCommandStyle NOTIFY commandStyleChanged)
    Q_PROPERTY(int chatStyle READ chatStyle WRITE setChatStyle NOTIFY chatStyleChanged)
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)

public:
    explicit MeetingManager(QObject *parent = nullptr);

    bool loading() const { return m_loading; }
    QString error() const { return m_error; }
    QString myNick() const;
    void setMyNick(const QString &nick);
    QString watchedNicks() const;
    void setWatchedNicks(const QString &nicks);
    int commandStyle() const;
    void setCommandStyle(int style);
    int chatStyle() const;
    void setChatStyle(int style);
    QString appVersion() const;

    Q_INVOKABLE void fetchMeetingsForYear(int year);
    Q_INVOKABLE void fetchHtmlContent(const QString &url);
    Q_INVOKABLE QVariantList getAvailableYears();
    Q_INVOKABLE void fetchAvailableYears();
    Q_INVOKABLE void searchYear(int year, const QString &query);
    Q_INVOKABLE void cancelScan();
    Q_INVOKABLE Meeting* createMeeting(const QString &filename);
    Q_INVOKABLE QVariantMap parseSummaryFromHtml(const QString &rawHtml);
    Q_INVOKABLE QVariantList parseIrcMessagesFromHtml(const QString &html);
    Q_INVOKABLE QString storageSize() const;
    Q_INVOKABLE void clearCache();
    Q_INVOKABLE void clearHistory();
    Q_INVOKABLE MeetingStatistics* calculateStatistics(const QVariantList &messages);
    Q_INVOKABLE bool isFavorite(const QString &meetingId) const;
    Q_INVOKABLE void toggleFavorite(const QString &meetingId);
    Q_INVOKABLE QStringList getFavorites() const;
    Q_INVOKABLE bool isRead(const QString &meetingId) const;
    Q_INVOKABLE void markAsRead(const QString &meetingId);
    Q_INVOKABLE void fetchNextMeetingDate();
    Q_INVOKABLE QString getNextMeetingDate() const;
    Q_INVOKABLE QString getNextMeetingDateRaw() const;
    Q_INVOKABLE QString getNextMeetingAgendaUrl() const;
    Q_INVOKABLE void saveIcsFile(const QString &content);

    // Public so the parser tests can exercise it without the network
    QString parseNextMeetingFromLog(const QString &html, QString *rawDate = nullptr,
                                    QString *agendaUrl = nullptr);

signals:
    void meetingsLoaded(QVariantList meetings);
    void loadingChanged();
    void errorChanged();
    void htmlContentLoaded(QString url, QString content);
    void favoritesChanged();
    void readStatusChanged();
    void myNickChanged();
    void watchedNicksChanged();
    void commandStyleChanged();
    void chatStyleChanged();
    void storageSizeChanged();
    void yearsLoaded(QVariantList yearList);
    void yearScanProgress(int done, int total);
    void yearScanResults(QVariantList results, bool truncated);
    void nextMeetingDateChanged(QString date, QString rawDate, QString agendaUrl);

private slots:
    void onHtmlContentReplyFinished();
    void onNextMeetingContentReplyFinished();

private:
    // Collects the directory listings of every log series in parallel
    struct IndexFetch {
        int pending;
        QString html;
        QString error;
        std::function<void(const QString &, const QString &)> callback;
    };

    QNetworkAccessManager *m_networkManager;
    QSettings *m_settings;
    bool m_loading;
    QString m_error;
    QStringList m_favorites;
    QStringList m_readMeetings;

    // Year scan (global search / action items) state. Logs are fetched a few
    // at a time, results are kept per meeting so the order stays stable.
    bool m_scanActive = false;
    QString m_scanQuery;
    QList<Meeting*> m_scanMeetings;
    int m_scanNextIndex = 0;
    int m_scanDone = 0;
    int m_scanPending = 0;
    int m_scanResultCount = 0;
    bool m_scanTruncated = false;
    QMap<int, QVariantList> m_scanResults;
    QList<QNetworkReply*> m_scanReplies;

    void setLoading(bool loading);
    void setError(const QString &error);
    QList<Meeting*> parseMeetingList(const QString &html);
    static QString lastFutureStamp(QRegularExpressionMatchIterator matches);
    void fetchLogForNextMeeting(Meeting *meeting);
    QNetworkReply* retryFromCache(QNetworkReply *reply);
    void fetchIndexes(const QStringList &urls,
                      const std::function<void(const QString &, const QString &)> &callback);
    void fetchYearIndexes(int year,
                          const std::function<void(const QString &, const QString &)> &callback);
    void handleIndexReply(QNetworkReply *reply, IndexFetch *fetch);
    void fetchMoreScanLogs();
    void onScanLogFinished(QNetworkReply *reply, int index);
    void finishScan();
    void scanLogContent(const QString &html, Meeting *meeting, int index);
};

#endif // MEETINGMANAGER_H
