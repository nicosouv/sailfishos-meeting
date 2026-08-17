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
    Q_PROPERTY(QString message READ message NOTIFY messageChanged)
    Q_PROPERTY(QString richMessage READ richMessage NOTIFY messageChanged)
    Q_PROPERTY(QString userColor READ userColor CONSTANT)
    Q_PROPERTY(bool isAction READ isAction CONSTANT)
    Q_PROPERTY(bool isTopic READ isTopic CONSTANT)
    Q_PROPERTY(bool isCommand READ isCommand CONSTANT)
    // Meetbot command (info, topic, action...) without the leading '#'
    Q_PROPERTY(QString command READ command CONSTANT)
    // Message without its "#command" and "<nick>" prefixes
    Q_PROPERTY(QString body READ body NOTIFY messageChanged)
    Q_PROPERTY(QString richBody READ richBody NOTIFY messageChanged)
    // Nick quoted by a command, as in "#info <Jolla> answer"
    Q_PROPERTY(QString quotedNick READ quotedNick CONSTANT)
    Q_PROPERTY(bool isJolla READ isJolla CONSTANT)

public:
    explicit IrcMessage(const QString &timestamp, const QString &username,
                       const QString &message, QObject *parent = nullptr);

    QString timestamp() const { return m_timestamp; }
    QString username() const { return m_username; }
    QString message() const { return m_message; }
    QString richMessage() const { return m_richMessage; }
    QString userColor() const { return m_userColor; }
    bool isAction() const { return m_isAction; }
    bool isTopic() const { return m_isTopic; }
    bool isCommand() const { return m_isCommand; }
    QString command() const { return m_command; }
    QString body() const { return m_body; }
    QString richBody() const { return m_richBody; }
    QString quotedNick() const { return m_quotedNick; }
    bool isJolla() const;

    void setIsAction(bool isAction) { m_isAction = isAction; }
    // Meetbot wraps long "#info" quotes over several lines: glue them back
    void appendBody(const QString &text);
    bool continues(const IrcMessage *previous) const;

    static QString generateColorForUsername(const QString &username);

signals:
    void messageChanged();

private:
    QString m_timestamp;
    QString m_username;
    QString m_message;
    QString m_richMessage;
    QString m_userColor;
    QString m_command;
    QString m_body;
    QString m_richBody;
    QString m_quotedNick;
    bool m_isAction;
    bool m_isTopic;
    bool m_isCommand;

    void parseMessageType();
    static QString buildRichMessage(const QString &message);
};

#endif // IRCMESSAGE_H
