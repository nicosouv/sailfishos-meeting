#ifndef MEETING_H
#define MEETING_H

#include <QObject>
#include <QString>
#include <QDateTime>
#include <QStringList>

class Meeting : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString date READ date CONSTANT)
    Q_PROPERTY(QString time READ time CONSTANT)
    Q_PROPERTY(QString title READ title CONSTANT)
    Q_PROPERTY(QString url READ url CONSTANT)
    Q_PROPERTY(QString logUrl READ logUrl CONSTANT)
    Q_PROPERTY(QString filename READ filename CONSTANT)
    Q_PROPERTY(QString month READ month CONSTANT)
    Q_PROPERTY(QString series READ series CONSTANT)
    Q_PROPERTY(QString seriesName READ seriesName CONSTANT)

public:
    explicit Meeting(const QString &filename, QObject *parent = nullptr);

    QString date() const;
    QString time() const;
    QString title() const;
    QString url() const;
    QString logUrl() const;
    QString filename() const;
    QString month() const;
    QString series() const { return m_series; }
    QString seriesName() const;

    QDateTime dateTime() const { return m_dateTime; }

private:
    QString m_filename;
    QDateTime m_dateTime;
    QString m_series;

    void parseFilename();
    QString baseUrl() const;
};

#endif // MEETING_H
