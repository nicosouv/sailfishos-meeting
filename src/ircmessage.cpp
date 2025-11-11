#include "ircmessage.h"
#include <QCryptographicHash>

IrcMessage::IrcMessage(const QString &timestamp, const QString &username,
                       const QString &message, QObject *parent)
    : QObject(parent)
    , m_timestamp(timestamp)
    , m_username(username)
    , m_message(message)
    , m_isAction(false)
    , m_isTopic(false)
    , m_isCommand(false)
{
    m_userColor = generateColorForUsername(username);
    parseMessageType();
}

void IrcMessage::parseMessageType()
{
    // Detect message type
    if (m_message.startsWith("#topic", Qt::CaseInsensitive)) {
        m_isTopic = true;
        m_isCommand = true;
    } else if (m_message.startsWith("#") &&
               (m_message.startsWith("#info") || m_message.startsWith("#link") ||
                m_message.startsWith("#action") || m_message.startsWith("#agreed"))) {
        m_isCommand = true;
    } else if (m_username.isEmpty() && m_message.contains("*")) {
        m_isAction = true;
    }
}

QString IrcMessage::generateColorForUsername(const QString &username)
{
    if (username.isEmpty()) {
        return "#808080"; // Gray for system messages
    }

    // Generate a consistent color for each username using hash
    QByteArray hash = QCryptographicHash::hash(username.toUtf8(), QCryptographicHash::Md5);

    // Use first 3 bytes for RGB
    int r = static_cast<unsigned char>(hash[0]);
    int g = static_cast<unsigned char>(hash[1]);
    int b = static_cast<unsigned char>(hash[2]);

    // Ensure colors are not too dark (minimum brightness)
    int minBrightness = 80;
    if (r < minBrightness) r += minBrightness;
    if (g < minBrightness) g += minBrightness;
    if (b < minBrightness) b += minBrightness;

    // Ensure colors are not too bright (maximum brightness)
    int maxBrightness = 200;
    if (r > maxBrightness) r = maxBrightness;
    if (g > maxBrightness) g = maxBrightness;
    if (b > maxBrightness) b = maxBrightness;

    return QString("#%1%2%3")
        .arg(r, 2, 16, QChar('0'))
        .arg(g, 2, 16, QChar('0'))
        .arg(b, 2, 16, QChar('0'));
}
