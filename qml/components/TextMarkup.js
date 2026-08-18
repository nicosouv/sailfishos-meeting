.pragma library

// Rich text produced by the parser is already escaped and may hold <a> tags:
// only the text between tags may be marked, never the markup itself.
function escapeHtml(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

function markMatches(richText, term, color) {
    if (!richText || !term) {
        return richText
    }

    var needle = escapeHtml(term).toLowerCase()
    if (needle === "") {
        return richText
    }

    var out = ""
    var segments = richText.split(/(<[^>]*>)/)

    for (var i = 0; i < segments.length; i++) {
        var segment = segments[i]

        if (segment.charAt(0) === "<") {
            out += segment // a tag, leave it alone
            continue
        }

        var lower = segment.toLowerCase()
        var from = 0
        while (true) {
            var at = lower.indexOf(needle, from)
            if (at === -1) {
                out += segment.substring(from)
                break
            }
            out += segment.substring(from, at)
                 + "<font color=\"" + color + "\"><b>"
                 + segment.substr(at, needle.length)
                 + "</b></font>"
            from = at + needle.length
        }
    }

    return out
}
