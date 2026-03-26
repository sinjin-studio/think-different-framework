#!/usr/bin/env python3
"""
Convert Think Different Framework markdown presentations to cinematic HTML.

Parses the presentation.md, converts content to HTML fragments,
and injects them into template.html.

Usage: python3 md-to-html.py input.md output.html [template.html]
"""

import sys
import re
import os
import html


def parse_markdown(text):
    """Parse the presentation markdown into metadata, lines, and typed sections."""
    metadata = {}
    the_lines = []
    sections = {}

    # Parse header metadata
    for match in re.finditer(r'>\s*\*\*(\w[\w\s]*):\*\*\s*(.+)', text):
        key = match.group(1).strip().lower()
        metadata[key] = match.group(2).strip()

    # Parse The Line section
    line_section = re.search(r'## The Line\s*\n(.*?)(?=\n---|\n## )', text, re.DOTALL)
    if line_section:
        line_text = line_section.group(1).strip()
        for line in line_text.split('\n'):
            line = line.strip()
            if not line:
                continue
            line = re.sub(r'^\d+\.\s*', '', line)
            line = line.strip('"\'')
            if line:
                the_lines.append(line)

    # Split by ## headers to find typed sections
    type_sections = re.split(r'\n## (The Experiment|Insight|Creative Brief|Manifesto)\s*\n', text)
    i = 1
    while i < len(type_sections) - 1:
        section_type = type_sections[i].strip().lower()
        section_content = type_sections[i + 1].strip()
        if section_type == 'creative brief':
            section_type = 'brief'
        elif section_type == 'the experiment':
            section_type = 'experiment'
        # Trim content at next --- or ## boundary
        section_content = re.split(r'\n---\s*$', section_content, maxsplit=1, flags=re.MULTILINE)[0].strip()
        sections[section_type] = section_content
        i += 2

    # Fallback: if no ## typed sections found, look for bold-labeled subsections directly
    # This handles the original format (pre-output-overhaul) where content is just
    # **The Provocation**, **The Landscape**, etc. without ## Insight wrapper
    if not sections:
        # Find content after the metadata/header block (after first ---)
        content_match = re.search(r'\n---\s*\n(.*?)(?:\n---\s*\n<p|$)', text, re.DOTALL)
        if content_match:
            raw_content = content_match.group(1).strip()
            # Strip any ## The Line section that was already parsed
            raw_content = re.sub(r'## The Line\s*\n.*?(?=\n\*\*|\Z)', '', raw_content, flags=re.DOTALL).strip()
            if raw_content:
                sections['insight'] = raw_content

    return metadata, the_lines, sections


def parse_subsections(text):
    """Parse bold-labeled subsections from content."""
    subsections = []
    pattern = r'\*\*([^*]+)\*\*\s*\n(.*?)(?=\n\*\*[^*]+\*\*|\Z)'
    for match in re.finditer(pattern, text, re.DOTALL):
        title = match.group(1).strip()
        body = match.group(2).strip()
        if body:
            subsections.append((title, body))
    if not subsections:
        subsections.append(('', text))
    return subsections


def md_to_html_paragraphs(text, css_class='para-reveal text-lg leading-relaxed mb-6'):
    """Convert markdown paragraphs to HTML <p> tags."""
    paragraphs = text.split('\n\n')
    result = []
    for para in paragraphs:
        para = para.strip()
        if not para or para.startswith('---') or para.startswith('> **"'):
            continue
        # Skip SVG blocks - handled separately
        if para.strip().startswith('<svg'):
            continue
        # Handle bold text
        para = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', para)
        # Handle italic
        para = re.sub(r'\*(.+?)\*', r'<em>\1</em>', para)
        result.append(f'<p class="{css_class}">{para}</p>')
    return '\n'.join(result)


def extract_svgs(text):
    """Extract SVG blocks from content text."""
    svgs = re.findall(r'(<svg[\s\S]*?</svg>)', text)
    return svgs


def build_diagrams_html(svgs):
    """Wrap extracted SVGs in diagram containers for animation."""
    if not svgs:
        return ''
    result = []
    for i, svg in enumerate(svgs):
        # Skip oversized SVGs (> 10KB)
        if len(svg) > 10240:
            continue
        result.append(f'<div class="diagram-container" data-diagram="{i}">{svg}</div>')
    return '\n'.join(result)


def build_lines_html(lines):
    """Build HTML for The Line section with word-reveal spans."""
    if not lines:
        return ''

    result = []
    for i, line in enumerate(lines):
        words = line.split()
        word_spans = ' '.join(
            f'<span class="word-reveal">{html.escape(w)}</span>'
            for w in words
        )
        mt = ' mt-8' if i > 0 else ''
        result.append(f'<div class="line-container{mt}">{word_spans}</div>')

    return '\n'.join(result)


def build_insight_html(content):
    """Build HTML for insight article with section panels."""
    if not content:
        return ''

    # Extract any SVGs before processing subsections
    svgs = extract_svgs(content)

    subsections = parse_subsections(content)
    panels = []

    for title, body in subsections:
        # Special treatment for The Insight subsection
        extra_class = ''
        if title.lower() == 'the insight':
            extra_class = ' text-xl text-center'

        title_html = f'<h3 class="subsection-title">{html.escape(title)}</h3>' if title else ''
        body_html = md_to_html_paragraphs(body, f'para-reveal text-lg leading-relaxed mb-6{extra_class}')

        panels.append(f'''<div class="section-panel">
  <div class="max-w-3xl mx-auto">
    {title_html}
    {body_html}
  </div>
</div>''')

    # Append diagrams at the end of insight section
    if svgs:
        diagrams_html = build_diagrams_html(svgs)
        if diagrams_html:
            panels.append(f'''<div class="section-panel">
  <div class="max-w-4xl mx-auto px-8 text-center">
    <h3 class="subsection-title">How It Connects</h3>
    {diagrams_html}
  </div>
</div>''')

    return '\n'.join(panels)


def build_brief_html(content):
    """Build HTML for creative brief with cards."""
    if not content:
        return ''

    # Extract any SVGs before processing subsections
    svgs = extract_svgs(content)

    subsections = parse_subsections(content)
    cards = []

    for title, body in subsections:
        # The Proposition gets special treatment
        if title.lower() == 'the proposition':
            # Extract the core proposition sentence
            cards.append(f'<div class="proposition-block">{html.escape(body.strip())}</div>')
        else:
            title_html = f'<h3 class="text-sinjin-green font-bold text-xl mb-3">{html.escape(title)}</h3>' if title else ''
            body_html = md_to_html_paragraphs(body, 'text-sinjin-text leading-relaxed')
            cards.append(f'''<div class="brief-card">
  {title_html}
  {body_html}
</div>''')

    # Append diagrams at the end of brief section
    if svgs:
        diagrams_html = build_diagrams_html(svgs)
        if diagrams_html:
            cards.append(f'''<div class="mt-12 text-center">
    {diagrams_html}
</div>''')

    return '\n'.join(cards)


def build_experiment_html(content):
    """Build HTML for experiment section - hypothesis, experiment, success signal."""
    if not content:
        return ''

    paragraphs = content.split('\n\n')
    result = []

    for para in paragraphs:
        para = para.strip()
        if not para:
            continue
        # Handle bold
        para = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', para)
        para = re.sub(r'\*(.+?)\*', r'<em>\1</em>', para)
        result.append(f'<p class="para-reveal text-lg leading-relaxed mb-6">{para}</p>')

    return '\n'.join(result)


def build_manifesto_html(content):
    """Build HTML for manifesto with pinning paragraphs."""
    if not content:
        return ''

    # Split into paragraphs, preserving bold markers
    paragraphs = content.split('\n\n')
    result = []

    for para in paragraphs:
        para = para.strip()
        if not para:
            continue
        # Skip SVG blocks
        if para.strip().startswith('<svg'):
            continue
        # Handle bold
        para = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', para)
        para = re.sub(r'\*(.+?)\*', r'<em>\1</em>', para)
        result.append(f'<div class="manifesto-para">{para}</div>')

    return '\n'.join(result)


def inject_into_template(template, replacements):
    """Replace {{KEY}} placeholders in template with content."""
    result = template
    for key, value in replacements.items():
        placeholder = '{{' + key + '}}'
        result = result.replace(placeholder, value)

    # Handle brand lockup visibility
    brand = replacements.get('BRAND_NAME', '').strip()
    if not brand:
        # Remove the brand lockup entirely when no brand
        result = re.sub(
            r'<div class="brand-lockup"[^>]*>.*?</div>\s*</div>',
            '', result, flags=re.DOTALL
        )

    # Hide empty sections by removing their containers if content is empty
    # Experiment section
    if not replacements.get('EXPERIMENT_CONTENT', '').strip():
        result = re.sub(
            r'<section data-section="experiment".*?</section>',
            '', result, flags=re.DOTALL
        )
    # Brief section
    if not replacements.get('BRIEF_CONTENT', '').strip():
        result = re.sub(
            r'<section data-section="brief".*?</section>',
            '', result, flags=re.DOTALL
        )
        # Also remove the divider before brief
        result = re.sub(
            r'<!-- -- Divider -- -->\s*<div class="section-divider"></div>\s*<!-- -- Creative Brief',
            '<!-- -- Creative Brief',
            result, flags=re.DOTALL
        )
    # Manifesto section
    if not replacements.get('MANIFESTO_CONTENT', '').strip():
        result = re.sub(
            r'<section data-section="manifesto".*?</section>',
            '', result, flags=re.DOTALL
        )
    # Insight section
    if not replacements.get('INSIGHT_CONTENT', '').strip():
        result = re.sub(
            r'<div data-section="insight".*?</div>',
            '', result, flags=re.DOTALL
        )

    # Clean up orphaned section dividers (dividers next to removed sections)
    # Remove consecutive dividers
    result = re.sub(
        r'(<div class="section-divider"></div>\s*){2,}',
        '<div class="section-divider"></div>\n',
        result
    )
    # Remove divider right before footer if no content after it
    result = re.sub(
        r'<div class="section-divider"></div>\s*\n\s*<!-- -- Footer',
        '\n  <!-- -- Footer',
        result
    )

    return result


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} input.md output.html [template.html]", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    # Template path: explicit arg, or look relative to this script
    if len(sys.argv) >= 4:
        template_path = sys.argv[3]
    else:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        template_path = os.path.join(script_dir, 'template.html')

    if not os.path.exists(input_path):
        print(f"Error: input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(template_path):
        print(f"Error: template not found: {template_path}", file=sys.stderr)
        print("Build the template first: cd report/html-template && npm run export", file=sys.stderr)
        sys.exit(1)

    with open(input_path, 'r') as f:
        md_text = f.read()

    with open(template_path, 'r') as f:
        template = f.read()

    metadata, the_lines, sections = parse_markdown(md_text)

    replacements = {
        'SEED_TOPIC': html.escape(metadata.get('seed', 'Think Different')),
        'BRAND_NAME': html.escape(metadata.get('brand', '')),
        'DATE': html.escape(metadata.get('date', '')),
        'WORD_COUNT': html.escape(metadata.get('words', '')),
        'SOURCE_INFO': html.escape(metadata.get('source', '')),
        'THE_LINES': build_lines_html(the_lines),
        'EXPERIMENT_CONTENT': build_experiment_html(sections.get('experiment', '')),
        'INSIGHT_CONTENT': build_insight_html(sections.get('insight', '')),
        'BRIEF_CONTENT': build_brief_html(sections.get('brief', '')),
        'MANIFESTO_CONTENT': build_manifesto_html(sections.get('manifesto', '')),
    }

    result = inject_into_template(template, replacements)

    with open(output_path, 'w') as f:
        f.write(result)

    print(f"  Created: {output_path}")


if __name__ == '__main__':
    main()
