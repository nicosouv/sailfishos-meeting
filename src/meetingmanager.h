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

public:
    explicit MeetingManager(QObject *parent = nullptr);

    bool loading() const { return m_loading; }
    QString error() const { return m_error; }

    Q_INVOKABLE void fetchMeetingsForYear(int year);
    Q_INVOKABLE QString fetchHtmlContent(const QString &url);
    Q_INVOKABLE QVariantList getAvailableYears();
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
    Q_INVOKABLE void saveIcsFile(const QString &path, const QString &content);

signals:
    void meetingsLoaded(QVariantList meetings);
    void loadingChanged();
    void errorChanged();
    void htmlContentLoaded(QString content);
    void favoritesChanged();
    void readStatusChanged();
    void nextMeetingDateChanged(QString date, QString rawDate);

private slots:
    void onMeetingListReplyFinished();
    void onHtmlContentReplyFinished();
    void onNextMeetingContentReplyFinished();

private:
    QNetworkAccessManager *m_networkManager;
    QSettings *m_settings;
    bool m_loading;
    QString m_error;

    void setLoading(bool loading);
    void setError(const QString &error);
    QList<Meeting*> parseMeetingList(const QString &html);
    QString parseNextMeetingFromLog(const QString &html);
    void fetchLogForNextMeeting(Meeting *meeting);
};

#endif // MEETINGMANAGER_H
