#ifndef MEETINGTOPIC_H
#define MEETINGTOPIC_H

#include <QObject>
#include <QString>
#include <QStringList>

class MeetingTopic : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString title READ title CONSTANT)
    Q_PROPERTY(QStringList items READ items CONSTANT)

public:
    explicit MeetingTopic(const QString &title, const QStringList &items,
                         QObject *parent = nullptr);

    QString title() const { return m_title; }
    QStringList items() const { return m_items; }

private:
    QString m_title;
    QStringList m_items;
};

#endif // MEETINGTOPIC_H
