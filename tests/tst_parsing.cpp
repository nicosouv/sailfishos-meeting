#include <QtTest>
#include <QVariantMap>

#include "meetingmanager.h"
#include "meeting.h"
#include "ircmessage.h"

// Excerpts of real meetbot pages, trimmed to what each test needs
static const char *LogHtml =
    "<html><body><pre>"
    "<a name=\"l-1\"></a><span class=\"tm\">16:00:26</span><span class=\"nk\"> &lt;rainemak&gt;</span>"
    " <span class=\"cmd\">#startmeeting </span><span class=\"cmdline\">Sailfish OS meeting</span>\n"
    "<a name=\"l-2\"></a><span class=\"tm\">16:00:30 </span><span class=\"nka\">* nephros</span>"
    " <span class=\"ac\">waves</span>\n"
    "<a name=\"l-3\"></a><span class=\"tm\">16:01:00</span><span class=\"nk\"> &lt;rainemak&gt;</span>"
    " <span class=\"topic\">#topic </span><span class=\"topicline\">General discussion</span>\n"
    "<a name=\"l-4\"></a><span class=\"tm\">16:06:38</span><span class=\"nk\"> &lt;rainemak&gt;</span>"
    " <span class=\"cmd\">#info </span><span class=\"cmdline\">&lt;b100dian&gt; client, I do not think I would be able to do that with two</span>\n"
    "<a name=\"l-5\"></a><span class=\"tm\">16:06:40</span><span class=\"nk\"> &lt;rainemak&gt;</span>"
    " <span class=\"cmd\">#info </span><span class=\"cmdline\">&lt;b100dian&gt; more languages + runtimes &amp; devtools and do that in a</span>\n"
    "<a name=\"l-6\"></a><span class=\"tm\">16:06:42</span><span class=\"nk\"> &lt;rainemak&gt;</span>"
    " <span class=\"cmd\">#info </span><span class=\"cmdline\">&lt;b100dian&gt; sustainable way.</span>\n"
    "<a name=\"l-7\"></a><span class=\"tm\">16:06:44</span><span class=\"nk\"> &lt;rainemak&gt;</span>"
    " <span class=\"cmd\">#info </span><span class=\"cmdline\">&lt;b100dian&gt; Are there any plans to make these available?</span>\n"
    "<a name=\"l-8\"></a><span class=\"tm\">16:07:00</span><span class=\"nk\"> &lt;Nico&gt;</span>"
    " see https://example.org/x for #sailfishos details\n"
    "<a name=\"l-9\"></a><span class=\"tm\">17:41:15</span><span class=\"nk\"> &lt;rainemak&gt;</span>"
    " <span class=\"cmd\">#info </span><span class=\"cmdline\">Next something (meeting / newsletter) will be held on Thursday 13th August 2099 at 04:00pm UTC: 2099-08-13T1600Z</span>\n"
    "</pre></body></html>";

static const char *SummaryHtml =
    "<html><body>"
    "<span class=\"details\">Meeting started by rainemak at 16:00:26 UTC</span>"
    "<h3>Meeting summary</h3>\n<ol>\n"
    "<li><b class=\"TOPIC\">General discussion</b> <span class=\"details\">(<a"
    " href='sailfishos-meeting.log.html#l-3'>rainemak</a>, 16:01:00)</span>\n"
    "<ol type=\"a\">\n"
    "  <li><span class=\"INFO\">Rust update should be doable</span> <span class=\"details\">(<a\n"
    "    href=\"sailfishos-meeting.log.html#l-42\">rainemak</a>,\n    16:06:50)</span></li>\n"
    "  <li><a href=\"https://forum.sailfishos.org/t/30378\">https://forum.sailfishos.org/t/30378</a>\n"
    "    <span class=\"details\">(<a href=\"sailfishos-meeting.log.html#l-5\">rainemak</a>, 16:00:26)</span></li>\n"
    "</ol>\n<br></li>\n</ol>\n"
    "Meeting ended at 17:43:12 UTC"
    "<h3>Action items</h3>\n<ol>\n  <li>Community task board</li>\n"
    "  <li>Jolla to update charging cables</li>\n</ol>\n"
    "<h3>People present (lines said)</h3>\n<ol>\n  <li>rainemak (291)</li>\n"
    "  <li>CLMA31[m] (25)</li>\n</ol>\n"
    "</body></html>";

class TestParsing : public QObject
{
    Q_OBJECT

private slots:
    void meetingFilename_data();
    void meetingFilename();
    void logMessages();
    void wrappedInfoIsMerged();
    void deliberateBreakIsKept();
    void commandDetection();
    void nextMeetingWording_data();
    void nextMeetingWording();
    void summaryEntries();
    void summaryActionsAndPeople();

private:
    MeetingManager m_manager;
};

void TestParsing::meetingFilename_data()
{
    QTest::addColumn<QString>("filename");
    QTest::addColumn<QString>("series");
    QTest::addColumn<QString>("logUrl");

    QTest::newRow("sailfishos")
            << "sailfishos-meeting.2026-07-16-16.00.html"
            << "sailfishos-meeting"
            << "https://irclogs.sailfishos.org/meetings/sailfishos-meeting/2026/sailfishos-meeting.2026-07-16-16.00.log.html";
    QTest::newRow("mer")
            << "mer-meeting.2019-01-10-09.00.html"
            << "mer-meeting"
            << "https://irclogs.sailfishos.org/meetings/mer-meeting/2019/mer-meeting.2019-01-10-09.00.log.html";
}

void TestParsing::meetingFilename()
{
    QFETCH(QString, filename);
    QFETCH(QString, series);
    QFETCH(QString, logUrl);

    Meeting meeting(filename);
    QCOMPARE(meeting.series(), series);
    QCOMPARE(meeting.logUrl(), logUrl);
}

void TestParsing::logMessages()
{
    QVariantList messages = m_manager.parseIrcMessagesFromHtml(QString::fromUtf8(LogHtml));

    // The four wrapped "#info <b100dian>" lines collapse into one entry
    QCOMPARE(messages.count(), 6);

    IrcMessage *first = qvariant_cast<IrcMessage*>(messages.at(0));
    QCOMPARE(first->command(), QString("startmeeting"));
    QCOMPARE(first->username(), QString("rainemak"));
    QCOMPARE(first->logLine(), 1);

    IrcMessage *action = qvariant_cast<IrcMessage*>(messages.at(1));
    QVERIFY(action->isAction());
    QCOMPARE(action->username(), QString("nephros"));
    QCOMPARE(action->message(), QString("waves"));

    IrcMessage *topic = qvariant_cast<IrcMessage*>(messages.at(2));
    QVERIFY(topic->isTopic());
    QCOMPARE(topic->body(), QString("General discussion"));

    // A channel name is not a command, and markup is escaped
    IrcMessage *plain = qvariant_cast<IrcMessage*>(messages.at(4));
    QVERIFY(!plain->isCommand());
    QCOMPARE(plain->command(), QString());
    QVERIFY(plain->richMessage().contains("<a href=\"https://example.org/x\">"));
}

void TestParsing::wrappedInfoIsMerged()
{
    QVariantList messages = m_manager.parseIrcMessagesFromHtml(QString::fromUtf8(LogHtml));
    IrcMessage *quote = qvariant_cast<IrcMessage*>(messages.at(3));

    QCOMPARE(quote->quotedNick(), QString("b100dian"));
    QCOMPARE(quote->timestamp(), QString("16:06:38"));

    // Lines cut mid sentence are glued back with a space
    QVERIFY(quote->body().startsWith("client, I do not think I would be able to do that with two more languages"));
    QVERIFY(!quote->body().contains("#info"));
}

void TestParsing::deliberateBreakIsKept()
{
    QVariantList messages = m_manager.parseIrcMessagesFromHtml(QString::fromUtf8(LogHtml));
    IrcMessage *quote = qvariant_cast<IrcMessage*>(messages.at(3));

    // "sustainable way." ended a paragraph: the next line keeps its own line
    QStringList paragraphs = quote->body().split('\n');
    QCOMPARE(paragraphs.count(), 2);
    QVERIFY(paragraphs.at(0).endsWith("sustainable way."));
    QCOMPARE(paragraphs.at(1), QString("Are there any plans to make these available?"));
    QVERIFY(quote->richBody().contains("<br>"));
}

void TestParsing::commandDetection()
{
    IrcMessage jolla("16:00:00", "rainemak", "#info <Jolla> we will look into it");
    QVERIFY(jolla.isCommand());
    QVERIFY(jolla.isJolla());
    QCOMPARE(jolla.command(), QString("info"));
    QCOMPARE(jolla.body(), QString("we will look into it"));

    IrcMessage channel("16:00:00", "nephros", "#sailfishos is the channel");
    QVERIFY(!channel.isCommand());
    QCOMPARE(channel.body(), QString("#sailfishos is the channel"));

    IrcMessage agreed("16:00:00", "rainemak", "#agreed ship it");
    QCOMPARE(agreed.command(), QString("agreed"));
    QVERIFY(!agreed.isTopic());
}

void TestParsing::nextMeetingWording_data()
{
    QTest::addColumn<QString>("line");
    QTest::addColumn<bool>("found");

    QTest::newRow("classic")
            << "#info Next meeting will be held on Thursday 4th December 2099 at 04:00pm UTC: 2099-12-04T1600Z" << true;
    QTest::newRow("newsletter")
            << "#info Next something (meeting / newsletter) will be held on Thursday 13th August 2099 at 04:00pm UTC: 2099-08-13T1600Z" << true;
    QTest::newRow("past")
            << "#info Next meeting will be held on 2000-01-01 at 04:00pm UTC: 2000-01-01T1600Z" << false;
    QTest::newRow("no date")
            << "#info Next meeting will be announced on the forum" << false;
}

void TestParsing::nextMeetingWording()
{
    QFETCH(QString, line);
    QFETCH(bool, found);

    QString raw;
    QString parsed = m_manager.parseNextMeetingFromLog(line, &raw);
    QCOMPARE(!parsed.isEmpty(), found);
    if (found) {
        QVERIFY(raw.endsWith("Z"));
    }
}

void TestParsing::summaryEntries()
{
    QVariantMap summary = m_manager.parseSummaryFromHtml(QString::fromUtf8(SummaryHtml));

    QCOMPARE(summary.value("chair").toString(), QString("rainemak"));
    QCOMPARE(summary.value("started").toString(), QString("16:00:26"));
    QCOMPARE(summary.value("ended").toString(), QString("17:43:12"));

    QVariantList entries = summary.value("entries").toList();
    QCOMPARE(entries.count(), 3);

    QVariantMap topic = entries.at(0).toMap();
    QCOMPARE(topic.value("type").toString(), QString("TOPIC"));
    QCOMPARE(topic.value("text").toString(), QString("General discussion"));
    QCOMPARE(topic.value("line").toInt(), 3);

    // Details spans are wrapped over several lines in the published pages
    QVariantMap info = entries.at(1).toMap();
    QCOMPARE(info.value("type").toString(), QString("INFO"));
    QCOMPARE(info.value("line").toInt(), 42);
    QCOMPARE(info.value("time").toString(), QString("16:06:50"));

    QVariantMap link = entries.at(2).toMap();
    QCOMPARE(link.value("type").toString(), QString("LINK"));
    QCOMPARE(link.value("text").toString(), QString("https://forum.sailfishos.org/t/30378"));
}

void TestParsing::summaryActionsAndPeople()
{
    QVariantMap summary = m_manager.parseSummaryFromHtml(QString::fromUtf8(SummaryHtml));

    QStringList actions = summary.value("actions").toStringList();
    QCOMPARE(actions.count(), 2);
    QCOMPARE(actions.first(), QString("Community task board"));

    QVariantList people = summary.value("people").toList();
    QCOMPARE(people.count(), 2);
    QCOMPARE(people.first().toMap().value("nick").toString(), QString("rainemak"));
    QCOMPARE(people.first().toMap().value("lines").toInt(), 291);
    // Nicks can hold brackets
    QCOMPARE(people.last().toMap().value("nick").toString(), QString("CLMA31[m]"));
}

QTEST_GUILESS_MAIN(TestParsing)
#include "tst_parsing.moc"
