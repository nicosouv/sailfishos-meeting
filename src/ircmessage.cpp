#include "ircmessage.h"
#include <QCryptographicHash>
#include <QRegularExpression>

// Quotes pasted into meetbot come pre-wrapped around 60 to 75 characters.
// Lines shorter than the minimum are always deliberate breaks, and lines
// longer than the maximum are stretched by an unbreakable URL: neither tells
// us anything about the wrap width of the block.
static const int MinimumWrapWidth = 55;
static const int MaximumWrapWidth = 90;

// Commands understood by meetbot; anything else starting with '#' is just text
// (a channel name for instance)
static const QStringList &knownCommands()
{
    static const QStringList commands = QStringList()
            << "topic" << "subtopic" << "info" << "link" << "action" << "agreed"
            << "accepted" << "rejected" << "idea" << "help" << "halp" << "nick"
            << "chair" << "unchair" << "undo" << "save" << "commands"
            << "startmeeting" << "endmeeting" << "meetingname" << "meetingtopic"
            << "lurk" << "unlurk" << "restrictlogs";
    return commands;
}

IrcMessage::IrcMessage(const QString &timestamp, const QString &username,
                       const QString &message, QObject *parent)
    : QObject(parent)
    , m_timestamp(timestamp)
    , m_username(username)
    , m_message(message)
    , m_isAction(false)
    , m_isTopic(false)
    , m_isCommand(false)
    , m_lastLineLength(0)
    , m_maxLineLength(0)
{
    m_userColor = generateColorForUsername(username);
    m_richMessage = buildRichMessage(message);
    parseMessageType();
    m_richBody = buildRichMessage(m_body);
    rememberLine(m_body);
}

void IrcMessage::rememberLine(const QString &line)
{
    m_lastLineLength = line.length();
    if (m_lastLineLength <= MaximumWrapWidth) {
        m_maxLineLength = qMax(m_maxLineLength, m_lastLineLength);
    }
}

QString IrcMessage::buildRichMessage(const QString &message)
{
    // Escape markup so IRC content cannot inject tags into StyledText labels,
    // then turn plain URLs into clickable links
    QString escaped = message.toHtmlEscaped();
    QRegularExpression urlRe("((?:https?|ftp)://[^\\s<]+)");
    escaped.replace(urlRe, "<a href=\"\\1\">\\1</a>");
    // StyledText collapses whitespace, keep the paragraph breaks visible
    escaped.replace(QChar('\n'), QStringLiteral("<br>"));
    return escaped;
}

void IrcMessage::parseMessageType()
{
    m_body = m_message;

    if (!m_message.startsWith('#')) {
        return;
    }

    // Split "#command rest of the line"
    int space = m_message.indexOf(QRegularExpression("\\s"));
    QString command = (space > 0 ? m_message.mid(1, space - 1) : m_message.mid(1)).toLower();

    if (!knownCommands().contains(command)) {
        return;
    }

    m_command = command;
    m_isCommand = true;
    m_isTopic = (command == "topic" || command == "subtopic");
    m_body = space > 0 ? m_message.mid(space + 1).trimmed() : QString();

    // A command often quotes somebody else: "#info <Jolla> the answer is..."
    QRegularExpression nickRe("^<([A-Za-z0-9_\\[\\]{}\\\\^`|-]{1,32})>\\s*");
    QRegularExpressionMatch nickMatch = nickRe.match(m_body);
    if (nickMatch.hasMatch()) {
        m_quotedNick = nickMatch.captured(1);
        m_body = m_body.mid(nickMatch.capturedLength()).trimmed();

        // A quote pasted into meetbot sometimes repeats its own marker in the
        // middle of a line: drop those leftovers
        QRegularExpression repeatRe("\\s*#" + m_command + "\\s+<"
                                    + QRegularExpression::escape(m_quotedNick) + ">\\s*",
                                    QRegularExpression::CaseInsensitiveOption);
        m_body.replace(repeatRe, " ");
    }
}

bool IrcMessage::isJolla() const
{
    return m_quotedNick.compare("Jolla", Qt::CaseInsensitive) == 0;
}

bool IrcMessage::continues(const IrcMessage *previous) const
{
    // Meetbot hard-wraps quoted answers, repeating "#info <nick>" on every
    // line. Only glue those back: plain commands stay separate entries.
    return previous
            && !m_quotedNick.isEmpty()
            && m_isCommand
            && previous->isCommand()
            && m_command == previous->command()
            && m_username == previous->username()
            && m_quotedNick.compare(previous->quotedNick(), Qt::CaseInsensitive) == 0;
}

void IrcMessage::appendBody(const QString &text)
{
    if (text.isEmpty()) {
        // An empty "#info <nick>" line separates two paragraphs: remember it
        // so the next line starts on its own line
        m_lastLineLength = 0;
        return;
    }

    if (m_body.isEmpty()) {
        m_body = text;
        m_message = m_message.isEmpty() ? text : m_message + " " + text;
    } else {
        // When the previous line stopped early enough for the next word to
        // have fit, the author broke the line on purpose: keep that break
        // instead of gluing the two paragraphs together.
        const int wrapWidth = qBound(MinimumWrapWidth, m_maxLineLength, MaximumWrapWidth);
        const QString firstWord = text.section(' ', 0, 0);
        const bool wrapped = m_lastLineLength + 1 + firstWord.length() > wrapWidth;
        const QString separator = wrapped ? QStringLiteral(" ") : QStringLiteral("\n");

        m_body += separator + text;
        m_message += separator + text;
    }

    rememberLine(text);
    m_richBody = buildRichMessage(m_body);
    m_richMessage = buildRichMessage(m_message);
    emit messageChanged();
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
