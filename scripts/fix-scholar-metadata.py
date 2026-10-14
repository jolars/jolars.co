#!/usr/bin/env python3
"""Correct Quarto's citation titles and omit shared bibliography metadata."""

from html import escape
from html.parser import HTMLParser
import os
from pathlib import Path
import re


class ScholarParser(HTMLParser):
    def __init__(self, content):
        super().__init__(convert_charrefs=False)
        self.content = content
        self.line_offsets = [0]
        for match in re.finditer('\n', content):
            self.line_offsets.append(match.end())
        self.in_head = False
        self.title = None
        self.tags = []

    def handle_starttag(self, tag, attrs):
        if tag == 'head':
            self.in_head = True
        if tag != 'meta' or not self.in_head:
            return
        attrs = dict(attrs)
        if attrs.get('property') == 'og:title':
            self.title = attrs.get('content')
        name = attrs.get('name')
        if name in ('citation_title', 'citation_reference'):
            line, column = self.getpos()
            start = self.line_offsets[line - 1] + column
            original = self.get_starttag_text()
            self.tags.append((start, start + len(original), name))

    def handle_endtag(self, tag):
        if tag == 'head':
            self.in_head = False

    def result(self):
        content = self.content
        for start, end, name in reversed(self.tags):
            if name == 'citation_reference':
                # Quarto includes every shared bibliography entry, even when
                # the post never cites it. These optional tags misstate citations.
                replacement = ''
                if content[end:end + 2] == '\r\n':
                    end += 2
                elif content[end:end + 1] == '\n':
                    end += 1
            elif self.title is not None:
                # Open Graph uses the rendered title without Quarto's repeated
                # escaping of apostrophes in the citation metadata.
                replacement = (
                    '<meta name="citation_title" '
                    f'content="{escape(self.title, quote=True)}">'
                )
            else:
                continue
            content = content[:start] + replacement + content[end:]
        return content


def fix_scholar_metadata(output):
    changed = 0
    for page in (output / 'blog').rglob('*.html'):
        with page.open(encoding='utf-8', newline='') as source:
            original = source.read()
        parser = ScholarParser(original)
        parser.feed(original)
        parser.close()
        content = parser.result()
        if content != original:
            with page.open('w', encoding='utf-8', newline='') as output_file:
                output_file.write(content)
            changed += 1
    print(f'Scholar: corrected blog metadata in {changed} pages.')


if __name__ == '__main__':
    fix_scholar_metadata(Path(os.environ.get('QUARTO_PROJECT_OUTPUT_DIR', '_site')))
