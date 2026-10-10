#!/usr/bin/env python3
"""Correct accessibility semantics in Quarto's generated HTML."""

from html.parser import HTMLParser
import os
from pathlib import Path
import re


class AccessibilityParser(HTMLParser):
    def __init__(self, content):
        super().__init__(convert_charrefs=False)
        self.content = content
        self.line_offsets = [0]
        for match in re.finditer('\n', content):
            self.line_offsets.append(match.end())
        self.replacements = []
        self.in_main = False
        self.section_level = 1
        self.listing_heading = None

    def replace(self, original, replacement):
        if original != replacement:
            line, column = self.getpos()
            start = self.line_offsets[line - 1] + column
            self.replacements.append((start, start + len(original), replacement))

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        classes = attrs.get('class', '').split()
        original = self.get_starttag_text()
        replacement = original
        if tag == 'main':
            self.in_main = True

        # These standalone elements are a disclosure button and a citation,
        # rather than a menu and a member of a bibliography list.
        if ((tag == 'button' and 'navbar-toggler' in classes
             and attrs.get('role') == 'menu')
                or ('quarto-appendix-citeas' in classes
                    and attrs.get('role') == 'listitem')):
            replacement = re.sub(r'\srole=("[^"]*"|\'[^\']*\')', '', replacement)

        # Pandoc makes code lines untabbable, so the scrolling container must
        # receive focus for readers to scroll it with the arrow keys.
        if tag == 'div' and 'sourceCode' in classes and 'tabindex' not in attrs:
            replacement = replacement[:-1] + ' tabindex="0">'

        # Long category lists can scroll even when the sidebar has no links.
        if attrs.get('id') == 'quarto-margin-sidebar' and 'tabindex' not in attrs:
            replacement = replacement[:-1] + ' tabindex="0">'

        category_title = 'quarto-listing-category-title' in classes
        if (self.in_main or category_title) and re.fullmatch(r'h[1-6]', tag):
            if 'listing-title' in classes or category_title:
                level = 2 if category_title else min(self.section_level + 1, 6)
                heading = f'h{level}'
                self.listing_heading = (tag, heading)
                if heading != tag:
                    replacement = replacement.replace(f'<{tag}', f'<{heading}', 1)
                    # Bootstrap's heading classes retain the original visual size.
                    replacement = re.sub(
                        r'(\bclass=["\'])', rf'\g<1>{tag} ', replacement, count=1)
            else:
                self.section_level = int(tag[1])
        self.replace(original, replacement)

    def handle_endtag(self, tag):
        if self.listing_heading and tag == self.listing_heading[0]:
            self.replace(f'</{tag}>', f'</{self.listing_heading[1]}>')
            self.listing_heading = None
        if tag == 'main':
            self.in_main = False

    def result(self):
        content = self.content
        # Replacing only affected tags preserves scripts, entities, and all
        # other generated content byte for byte.
        for start, end, replacement in reversed(self.replacements):
            content = content[:start] + replacement + content[end:]
        return content


def fix_accessibility(output):
    changed = 0
    for page in output.rglob('*.html'):
        original = page.read_text()
        parser = AccessibilityParser(original)
        parser.feed(original)
        content = parser.result()
        if content != original:
            page.write_text(content)
            changed += 1
    print(f'Accessibility: corrected generated markup in {changed} pages.')


if __name__ == '__main__':
    fix_accessibility(Path(os.environ.get('QUARTO_PROJECT_OUTPUT_DIR', '_site')))
