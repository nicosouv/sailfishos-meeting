#ifndef MEETINGMANAGER_H
#define MEETINGMANAGER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QList>
#include "meeting.h"

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

signals:
    void meetingsLoaded(QVariantList meetings);
    void loadingChanged();
    void errorChanged();
    void htmlContentLoaded(QString content);

private slots:
    void onMeetingListReplyFinished();
    void onHtmlContentReplyFinished();

private:
    QNetworkAccessManager *m_networkManager;
    bool m_loading;
    QString m_error;

    void setLoading(bool loading);
    void setError(const QString &error);
    QList<Meeting*> parseMeetingList(const QString &html);
};

#endif // MEETINGMANAGER_H
