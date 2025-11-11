#ifndef IRCMESSAGE_H
#define IRCMESSAGE_H

#include <QObject>
#include <QString>
#include <QColor>

class IrcMessage : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString timestamp READ timestamp CONSTANT)
    Q_PROPERTY(QString username READ username CONSTANT)
    Q_PROPERTY(QString message READ message CONSTANT)
    Q_PROPERTY(QString userColor READ userColor CONSTANT)
    Q_PROPERTY(bool isAction READ isAction CONSTANT)
    Q_PROPERTY(bool isTopic READ isTopic CONSTANT)
    Q_PROPERTY(bool isCommand READ isCommand CONSTANT)

public:
    explicit IrcMessage(const QString &timestamp, const QString &username,
                       const QString &message, QObject *parent = nullptr);

    QString timestamp() const { return m_timestamp; }
    QString username() const { return m_username; }
    QString message() const { return m_message; }
    QString userColor() const { return m_userColor; }
    bool isAction() const { return m_isAction; }
    bool isTopic() const { return m_isTopic; }
    bool isCommand() const { return m_isCommand; }

    static QString generateColorForUsername(const QString &username);

private:
    QString m_timestamp;
    QString m_username;
    QString m_message;
    QString m_userColor;
    bool m_isAction;
    bool m_isTopic;
    bool m_isCommand;

    void parseMessageType();
};

#endif // IRCMESSAGE_H
