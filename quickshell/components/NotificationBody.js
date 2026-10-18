.pragma library

function styled(body) {
    // Accept basic formatting, but keep unknown tags and bare angle brackets
    // readable (compiler output, email addresses, comparisons, etc.).
    const text = (body || "")
        .replace(/<img\b(?:[^"'<>]|"[^"]*"|'[^']*')*>/gi, "")
        .replace(/<\/?a\b(?:[^"'<>]|"[^"]*"|'[^']*')*>/gi, "")
    const formatting = /^(?:<\/?(?:b|i|u|s)\s*>|<br\s*\/?>)$/i
    return text.split(/(<\/?(?:b|i|u|s)\s*>|<br\s*\/?>)/gi).map(part => {
        if (formatting.test(part)) return part
        return part.replace(/&(?!(?:amp|lt|gt|quot|apos|nbsp|#\d+|#x[0-9a-f]+);)/gi, "&amp;")
            .replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }).join("")
}
