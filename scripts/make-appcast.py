#!/usr/bin/env python3
"""Writes build/appcast.xml, the Sparkle update feed for one release.

    scripts/make-appcast.py --version 1.1.0 --build 42 --tag v1.1.0 \
        --signature 'sparkle:edSignature="..." length="..."' [--notes docs/RELEASE_NOTES.md]

The signature string is what Sparkle's `sign_update` prints for the DMG. The feed is
published as a release asset, so SUFeedURL (releases/latest/download/appcast.xml)
always points at the newest release.
"""
import argparse
import html
import re
from email.utils import formatdate

REPO = "https://github.com/taqionvibe/dialed"


def markdown_to_html(text: str) -> str:
    """Just enough Markdown for release notes: headings, bullets, bold, code, links."""
    def inline(s: str) -> str:
        s = html.escape(s, quote=False)
        s = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)
        s = re.sub(r"`(.+?)`", r"<code>\1</code>", s)
        s = re.sub(r"\[(.+?)\]\((https?://[^)]+)\)", r'<a href="\2">\1</a>', s)
        return s

    out, in_list = [], False
    for line in text.splitlines():
        line = line.rstrip()
        bullet = re.match(r"^\s*[-*] (.*)", line)
        if bullet:
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(bullet.group(1))}</li>")
            continue
        if in_list:
            out.append("</ul>")
            in_list = False
        heading = re.match(r"^(#{1,6}) (.*)", line)
        if heading:
            level = min(len(heading.group(1)) + 1, 6)
            out.append(f"<h{level}>{inline(heading.group(2))}</h{level}>")
        elif line:
            out.append(f"<p>{inline(line)}</p>")
    if in_list:
        out.append("</ul>")
    return "\n".join(out)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--version", required=True)
    p.add_argument("--build", required=True)
    p.add_argument("--tag", required=True)
    p.add_argument("--signature", required=True)
    p.add_argument("--notes", default="docs/RELEASE_NOTES.md")
    p.add_argument("--min-system", default="14.0")
    p.add_argument("--url", help="DMG URL (defaults to the GitHub release asset)")
    p.add_argument("--out", default="build/appcast.xml")
    a = p.parse_args()

    sig = re.search(r'sparkle:edSignature="([^"]+)"', a.signature)
    length = re.search(r'length="(\d+)"', a.signature)
    if not sig or not length:
        raise SystemExit(f"Unexpected sign_update output: {a.signature!r}")

    url = a.url or f"{REPO}/releases/download/{a.tag}/Dialed.dmg"
    with open(a.notes, encoding="utf-8") as f:
        notes = markdown_to_html(f.read())

    xml = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Dialed</title>
    <link>{REPO}</link>
    <description>Dialed updates</description>
    <language>en</language>
    <item>
      <title>Dialed {html.escape(a.version)}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{html.escape(a.build)}</sparkle:version>
      <sparkle:shortVersionString>{html.escape(a.version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{html.escape(a.min_system)}</sparkle:minimumSystemVersion>
      <description><![CDATA[{notes}]]></description>
      <enclosure url="{html.escape(url)}" type="application/octet-stream" sparkle:edSignature="{sig.group(1)}" length="{length.group(1)}"/>
    </item>
  </channel>
</rss>
"""
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"Wrote {a.out} for {a.version} (build {a.build})")


if __name__ == "__main__":
    main()
