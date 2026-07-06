#ifndef MEETINGMANAGER_H
#define MEETINGMANAGER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QList>
#include <QSettings>
#include "meeting.h"
#include "meetingstatistics.h"

class MeetingManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString myNick READ myNick WRITE setMyNick NOTIFY myNickChanged)

public:
    explicit MeetingManager(QObject *parent = nullptr);

    bool loading() const { return m_loading; }
    QString error() const { return m_error; }
    QString myNick() const;
    void setMyNick(const QString &nick);

    Q_INVOKABLE void fetchMeetingsForYear(int year);
    Q_INVOKABLE void fetchHtmlContent(const QString &url);
    Q_INVOKABLE QVariantList getAvailableYears();
    Q_INVOKABLE void fetchAvailableYears();
    Q_INVOKABLE void searchYear(int year, const QString &query);
    Q_INVOKABLE Meeting* createMeeting(const QString &filename);
    Q_INVOKABLE QVariantList parseTopicsFromHtml(const QString &html);
    Q_INVOKABLE QVariantList parseIrcMessagesFromHtml(const QString &html);
    Q_INVOKABLE MeetingStatistics* calculateStatistics(const QVariantList &messages);
    Q_INVOKABLE bool isFavorite(const QString &meetingId) const;
    Q_INVOKABLE void toggleFavorite(const QString &meetingId);
    Q_INVOKABLE QStringList getFavorites() const;
    Q_INVOKABLE bool isRead(const QString &meetingId) const;
    Q_INVOKABLE void markAsRead(const QString &meetingId);
    Q_INVOKABLE void fetchNextMeetingDate();
    Q_INVOKABLE QString getNextMeetingDate() const;
    Q_INVOKABLE QString getNextMeetingAgendaUrl() const;
    Q_INVOKABLE void saveIcsFile(const QString &content);

signals:
    void meetingsLoaded(QVariantList meetings);
    void loadingChanged();
    void errorChanged();
    void htmlContentLoaded(QString url, QString content);
    void favoritesChanged();
    void readStatusChanged();
    void myNickChanged();
    void yearsLoaded(QVariantList yearList);
    void yearScanProgress(int done, int total);
    void yearScanResults(QVariantList results);
    void nextMeetingDateChanged(QString date, QString rawDate, QString agendaUrl);

private slots:
    void onMeetingListReplyFinished();
    void onHtmlContentReplyFinished();
    void onNextMeetingContentReplyFinished();
    void onYearListReplyFinished();
    void onScanListReplyFinished();
    void onScanLogReplyFinished();

private:
    QNetworkAccessManager *m_networkManager;
    QSettings *m_settings;
    bool m_loading;
    QString m_error;
    QStringList m_favorites;
    QStringList m_readMeetings;

    // Year scan (global search / action items) state
    bool m_scanActive = false;
    QString m_scanQuery;
    QList<Meeting*> m_scanMeetings;
    int m_scanIndex = 0;
    QVariantList m_scanResults;

    void setLoading(bool loading);
    void setError(const QString &error);
    QList<Meeting*> parseMeetingList(const QString &html);
    QString parseNextMeetingFromLog(const QString &html, QString *rawDate = nullptr, QString *agendaUrl = nullptr);
    void fetchLogForNextMeeting(Meeting *meeting);
    QNetworkReply* retryFromCache(QNetworkReply *reply);
    void fetchNextScanLog();
    void scanLogContent(const QString &html, Meeting *meeting);
};

#endif // MEETINGMANAGER_H
