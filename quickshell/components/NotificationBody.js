.pragma library

function escapeText(text) {
    return text.replace(/&(?!(?:amp|lt|gt|quot|apos|nbsp|#\d+|#x[0-9a-f]+);)/gi, "&amp;")
        .replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

function safeLink(url) {
    return /^(https?:\/\/|mailto:)/i.test(url) && !/[\s<>"']/.test(url)
}

function styled(body) {
    // Keep basic formatting and explicit web/mail links, without remote images.
    const text = (body || "").replace(/<img\b(?:[^"'<>]|"[^"]*"|'[^']*')*>/gi, "")
    const formatting = /^(?:<\/?(?:b|i|u|s)\s*>|<br\s*\/?>)$/i
    let linked = false
    return text.split(/(<\/?(?:b|i|u|s)\s*>|<br\s*\/?>|<\/?a\b(?:[^"'<>]|"[^"]*"|'[^']*')*>)/gi).map(part => {
        if (formatting.test(part)) return part
        if (/^<a\b/i.test(part)) {
            const match = part.match(/\bhref\s*=\s*(?:"([^"]*)"|'([^']*)')/i)
            const url = match ? (match[1] || match[2] || "") : ""
            const close = linked ? "</a>" : ""
            linked = safeLink(url)
            return close + (linked ? '<a href="' + escapeText(url) + '">' : "")
        }
        if (/^<\/a\b/i.test(part)) {
            const close = linked ? "</a>" : ""
            linked = false
            return close
        }
        return escapeText(part)
    }).join("") + (linked ? "</a>" : "")
}
