import Foundation

public enum MarkdownPage {
    public static let messageHandlerName = "noteCraft"
    public static let resourceScheme = "notecraft"
    public static let resourceHost = "file"

    /// The address under which the preview serves the local file at `url`.
    public static func resourceAddress(for url: URL) -> String {
        var components = URLComponents()
        components.scheme = resourceScheme
        components.host = resourceHost
        components.path = url.standardizedFileURL.path
        return components.string ?? "\(resourceScheme)://\(resourceHost)"
    }

    /// The local file a preview resource address refers to.
    public static func fileURL(forResourceAddress url: URL) -> URL? {
        guard url.scheme == resourceScheme, url.host == resourceHost, !url.path.isEmpty else { return nil }
        return URL(fileURLWithPath: url.path)
    }

    /// The live preview page; only the script with `nonce` runs, and internet images load only when `allowsExternalImages` is set.
    public static func previewHTML(body: String, css: String, nonce: String, allowsExternalImages: Bool) -> String {
        let images = "\(resourceScheme): data:" + (allowsExternalImages ? " https: http:" : "")
        let policy = "default-src 'none'; img-src \(images); style-src 'unsafe-inline'; script-src 'nonce-\(nonce)'"
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="\(policy)">
        <style id="theme">\(css)</style>
        </head>
        <body>
        <article id="content">\(body)</article>
        <script nonce="\(nonce)">\(previewScript)</script>
        </body>
        </html>
        """
    }

    /// A self-contained HTML document for export.
    public static func exportHTML(title: String, body: String, css: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(HTMLEntities.escape(title))</title>
        <style>\(css)</style>
        </head>
        <body>
        <article id="content">\(body)</article>
        </body>
        </html>
        """
    }

    static let previewScript = """
    (() => {
      const post = (message) => window.webkit.messageHandlers.\(messageHandlerName).postMessage(message);
      const content = document.getElementById('content');
      let ignoreScrollUntil = 0;
      const blocks = () => Array.from(content.querySelectorAll('[data-line]')).map((element) => ({
        line: Number(element.dataset.line),
        top: element.getBoundingClientRect().top + window.scrollY
      })).filter((block) => block.line > 0);
      const lineAtTop = () => {
        const list = blocks();
        const top = window.scrollY;
        if (list.length === 0 || top <= 0) { return 1; }
        let previous = { line: 1, top: 0 };
        for (const block of list) {
          if (block.top > top) {
            const span = block.top - previous.top;
            const fraction = span > 0 ? (top - previous.top) / span : 0;
            return previous.line + fraction * (block.line - previous.line);
          }
          if (block.line >= previous.line) { previous = block; }
        }
        return previous.line;
      };
      const offsetOfLine = (line) => {
        const list = blocks();
        let previous = { line: 1, top: 0 };
        for (const block of list) {
          if (block.line > line) {
            const span = block.line - previous.line;
            const fraction = span > 0 ? (line - previous.line) / span : 0;
            return previous.top + fraction * (block.top - previous.top);
          }
          if (block.line >= previous.line) { previous = block; }
        }
        return previous.top;
      };
      window.NoteCraft = {
        update(html) { content.innerHTML = html; },
        setStyle(css) { document.getElementById('theme').textContent = css; },
        scrollToLine(line) {
          ignoreScrollUntil = Date.now() + 200;
          window.scrollTo(0, Math.max(0, offsetOfLine(line)));
        },
        lineAtTop
      };
      document.addEventListener('click', (event) => {
        const box = event.target.closest('input[data-task-line]');
        if (box) {
          event.preventDefault();
          post({ type: 'task', line: Number(box.dataset.taskLine) });
          return;
        }
        const link = event.target.closest('a[href]');
        if (!link) { return; }
        event.preventDefault();
        const href = link.getAttribute('href');
        if (href.startsWith('#')) {
          const target = document.getElementById(decodeURIComponent(href.slice(1)));
          if (target) { target.scrollIntoView(); }
          return;
        }
        post({ type: 'link', href });
      });
      document.addEventListener('dblclick', (event) => {
        const block = event.target.closest('[data-line]');
        if (block) { post({ type: 'reveal', line: Number(block.dataset.line) }); }
      });
      window.addEventListener('scroll', () => {
        if (Date.now() < ignoreScrollUntil) { return; }
        post({ type: 'scroll', line: lineAtTop() });
      }, { passive: true });
    })();
    """
}
