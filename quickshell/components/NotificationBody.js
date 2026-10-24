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
            // Consume whole attributes so href inside data-href or a quoted
            // title cannot be mistaken for the destination.
            const attributes = /([^\s=<>"'`/]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g
            let match
            let url = ""
            while ((match = attributes.exec(part.slice(2, -1))) !== null) {
                if (match[1].toLowerCase() !== "href") continue
                url = match[2] || match[3] || match[4] || ""
                break
            }
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
