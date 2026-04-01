#!/usr/bin/env python3
"""Generate a D3 force-directed session diagram from log.jsonl.

Usage:
    python3 report/session-diagram.py <session-dir>/log.jsonl [output.html]

Reads conductor decisions, lens dispatches, mechanism interventions, skips,
and user questions from the verbose log. Outputs a self-contained HTML file
with an embedded D3 visualization of the session's thinking process.
"""

import json
import sys
import os
from pathlib import Path


def parse_log(log_path):
    """Parse log.jsonl into structured session events."""
    events = []
    with open(log_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                events.append(entry)
            except json.JSONDecodeError:
                continue
    return events


def extract_session_graph(events):
    """Extract nodes and links from log events for D3 visualization."""
    nodes = []
    links = []
    node_ids = set()
    prev_node_id = None
    turn = 0

    for event in events:
        caller = event.get("caller", "unknown")
        response = event.get("response", "")
        call_type = event.get("type", "")
        ts = event.get("ts", "")

        # Determine node type and label
        if caller == "conductor":
            # Parse conductor decision
            reasoning = ""
            next_lens = ""
            instruction = ""
            mechanism_after = ""
            try:
                decision = json.loads(response)
                reasoning = decision.get("reasoning", "")
                next_lens = decision.get("next_lens", "")
                instruction = decision.get("instruction", "")
                mechanism_after = decision.get("mechanism_after", "")
            except (json.JSONDecodeError, TypeError):
                pass

            turn += 1
            node_id = f"conductor_{turn}"
            nodes.append({
                "id": node_id,
                "type": "conductor",
                "label": f"Conductor #{turn}",
                "reasoning": reasoning,
                "next_lens": next_lens,
                "instruction": instruction[:200],
                "mechanism_after": mechanism_after,
                "ts": ts,
                "turn": turn
            })
            node_ids.add(node_id)

            if prev_node_id and prev_node_id in node_ids:
                links.append({
                    "source": prev_node_id,
                    "target": node_id,
                    "type": "sequence"
                })
            prev_node_id = node_id

        elif caller.startswith("lens:"):
            lens_key = caller.replace("lens:", "")
            is_skip = "SKIP:" in response[:100]
            node_id = f"lens_{lens_key}_{turn}"
            label = f"{lens_key}" + (" (skip)" if is_skip else "")
            nodes.append({
                "id": node_id,
                "type": "skip" if is_skip else "lens",
                "label": label,
                "lens": lens_key,
                "response_excerpt": response[:300],
                "ts": ts,
                "turn": turn
            })
            node_ids.add(node_id)

            if prev_node_id and prev_node_id in node_ids:
                links.append({
                    "source": prev_node_id,
                    "target": node_id,
                    "type": "dispatch"
                })
            prev_node_id = node_id

        elif caller.startswith("mechanism:"):
            mech_name = caller.replace("mechanism:", "")
            node_id = f"mechanism_{mech_name}_{turn}"
            # Try to extract recommendation
            recommendation = ""
            try:
                mech_data = json.loads(response)
                recommendation = mech_data.get("recommendation", "")
            except (json.JSONDecodeError, TypeError):
                pass

            nodes.append({
                "id": node_id,
                "type": "mechanism",
                "label": mech_name,
                "recommendation": recommendation,
                "response_excerpt": response[:300],
                "ts": ts,
                "turn": turn
            })
            node_ids.add(node_id)

            if prev_node_id and prev_node_id in node_ids:
                links.append({
                    "source": prev_node_id,
                    "target": node_id,
                    "type": "mechanism"
                })
            prev_node_id = node_id

    return nodes, links


def generate_html(nodes, links, title="Session Diagram"):
    """Generate self-contained HTML with D3 force-directed graph."""

    graph_data = json.dumps({"nodes": nodes, "links": links}, indent=2)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ background: #181818; color: #e0e0e0; font-family: 'Literata', Georgia, serif; overflow: hidden; }}
  svg {{ width: 100vw; height: 100vh; }}
  .tooltip {{
    position: absolute;
    background: #282828;
    border: 1px solid #444;
    border-radius: 6px;
    padding: 12px 16px;
    font-size: 13px;
    max-width: 400px;
    pointer-events: none;
    opacity: 0;
    transition: opacity 0.15s;
    line-height: 1.5;
    z-index: 10;
  }}
  .tooltip .label {{ font-weight: bold; color: #169B62; margin-bottom: 4px; }}
  .tooltip .reasoning {{ color: #ccc; font-style: italic; }}
  .tooltip .detail {{ color: #aaa; margin-top: 6px; font-size: 12px; }}
  .legend {{
    position: absolute;
    top: 16px;
    left: 16px;
    background: #222;
    border: 1px solid #444;
    border-radius: 6px;
    padding: 12px 16px;
    font-size: 12px;
    z-index: 5;
  }}
  .legend-item {{
    display: flex;
    align-items: center;
    margin-bottom: 6px;
  }}
  .legend-dot {{
    width: 12px;
    height: 12px;
    border-radius: 50%;
    margin-right: 8px;
    flex-shrink: 0;
  }}
  h1 {{
    position: absolute;
    top: 16px;
    right: 16px;
    font-size: 14px;
    color: #666;
    font-weight: normal;
  }}
</style>
</head>
<body>
<div class="legend">
  <div class="legend-item"><div class="legend-dot" style="background:#169B62"></div>Conductor decision</div>
  <div class="legend-item"><div class="legend-dot" style="background:#FF8200"></div>Lens response</div>
  <div class="legend-item"><div class="legend-dot" style="background:#666"></div>Skipped lens</div>
  <div class="legend-item"><div class="legend-dot" style="background:#E84855"></div>Mechanism</div>
  <div class="legend-item"><div class="legend-dot" style="background:#4ECDC4"></div>User question</div>
</div>
<h1>{title}</h1>
<div class="tooltip" id="tooltip"></div>
<svg id="graph"></svg>

<script src="https://d3js.org/d3.v7.min.js"></script>
<script>
const data = {graph_data};

const width = window.innerWidth;
const height = window.innerHeight;

const colorMap = {{
  conductor: '#169B62',
  lens: '#FF8200',
  skip: '#666',
  mechanism: '#E84855',
  user_question: '#4ECDC4'
}};

const sizeMap = {{
  conductor: 8,
  lens: 12,
  skip: 6,
  mechanism: 10,
  user_question: 10
}};

const svg = d3.select('#graph');
const tooltip = d3.select('#tooltip');

// Create arrow markers
svg.append('defs').selectAll('marker')
  .data(['sequence', 'dispatch', 'mechanism'])
  .join('marker')
    .attr('id', d => `arrow-${{d}}`)
    .attr('viewBox', '0 -5 10 10')
    .attr('refX', 20)
    .attr('refY', 0)
    .attr('markerWidth', 6)
    .attr('markerHeight', 6)
    .attr('orient', 'auto')
  .append('path')
    .attr('d', 'M0,-5L10,0L0,5')
    .attr('fill', '#555');

const simulation = d3.forceSimulation(data.nodes)
  .force('link', d3.forceLink(data.links).id(d => d.id).distance(60))
  .force('charge', d3.forceManyBody().strength(-200))
  .force('center', d3.forceCenter(width / 2, height / 2))
  .force('x', d3.forceX(d => {{
    // Arrange left to right by turn number
    const maxTurn = Math.max(...data.nodes.map(n => n.turn || 0));
    const t = (d.turn || 0) / Math.max(maxTurn, 1);
    return 100 + t * (width - 200);
  }}).strength(0.3))
  .force('y', d3.forceY(height / 2).strength(0.05))
  .force('collision', d3.forceCollide().radius(d => sizeMap[d.type] + 4));

const link = svg.append('g')
  .selectAll('line')
  .data(data.links)
  .join('line')
    .attr('stroke', '#444')
    .attr('stroke-width', 1.5)
    .attr('stroke-dasharray', d => d.type === 'mechanism' ? '4,3' : 'none')
    .attr('marker-end', d => `url(#arrow-${{d.type}})`);

const node = svg.append('g')
  .selectAll('circle')
  .data(data.nodes)
  .join('circle')
    .attr('r', d => sizeMap[d.type])
    .attr('fill', d => colorMap[d.type])
    .attr('stroke', '#181818')
    .attr('stroke-width', 1.5)
    .attr('cursor', 'pointer')
    .call(d3.drag()
      .on('start', dragstarted)
      .on('drag', dragged)
      .on('end', dragended));

const labels = svg.append('g')
  .selectAll('text')
  .data(data.nodes)
  .join('text')
    .text(d => d.label)
    .attr('font-size', 10)
    .attr('fill', '#999')
    .attr('text-anchor', 'middle')
    .attr('dy', d => sizeMap[d.type] + 14)
    .style('pointer-events', 'none');

// Turn numbers on conductor nodes
const turnLabels = svg.append('g')
  .selectAll('text')
  .data(data.nodes.filter(d => d.type === 'conductor'))
  .join('text')
    .text(d => d.turn)
    .attr('font-size', 9)
    .attr('fill', '#181818')
    .attr('text-anchor', 'middle')
    .attr('dy', 3)
    .attr('font-weight', 'bold')
    .style('pointer-events', 'none');

node.on('mouseover', (event, d) => {{
  let html = `<div class="label">${{d.label}}</div>`;
  if (d.reasoning) html += `<div class="reasoning">${{d.reasoning}}</div>`;
  if (d.next_lens) html += `<div class="detail">Next: ${{d.next_lens}}</div>`;
  if (d.instruction) html += `<div class="detail">Instruction: ${{d.instruction}}</div>`;
  if (d.mechanism_after) html += `<div class="detail">Mechanism after: ${{d.mechanism_after}}</div>`;
  if (d.recommendation) html += `<div class="detail">Recommendation: ${{d.recommendation}}</div>`;
  if (d.response_excerpt) html += `<div class="detail">${{d.response_excerpt.substring(0, 200)}}...</div>`;
  if (d.ts) html += `<div class="detail" style="color:#666">${{d.ts}}</div>`;

  tooltip.html(html)
    .style('left', (event.pageX + 16) + 'px')
    .style('top', (event.pageY - 16) + 'px')
    .style('opacity', 1);
}})
.on('mouseout', () => {{
  tooltip.style('opacity', 0);
}});

simulation.on('tick', () => {{
  link
    .attr('x1', d => d.source.x)
    .attr('y1', d => d.source.y)
    .attr('x2', d => d.target.x)
    .attr('y2', d => d.target.y);
  node
    .attr('cx', d => d.x)
    .attr('cy', d => d.y);
  labels
    .attr('x', d => d.x)
    .attr('y', d => d.y);
  turnLabels
    .attr('x', d => d.x)
    .attr('y', d => d.y);
}});

function dragstarted(event) {{
  if (!event.active) simulation.alphaTarget(0.3).restart();
  event.subject.fx = event.subject.x;
  event.subject.fy = event.subject.y;
}}

function dragged(event) {{
  event.subject.fx = event.x;
  event.subject.fy = event.y;
}}

function dragended(event) {{
  if (!event.active) simulation.alphaTarget(0);
  event.subject.fx = null;
  event.subject.fy = null;
}}

// Zoom
const zoom = d3.zoom()
  .scaleExtent([0.3, 4])
  .on('zoom', (event) => {{
    svg.selectAll('g').attr('transform', event.transform);
  }});
svg.call(zoom);
</script>
</body>
</html>"""


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 session-diagram.py <log.jsonl> [output.html]")
        sys.exit(1)

    log_path = sys.argv[1]
    if not os.path.exists(log_path):
        print(f"Error: {log_path} not found")
        sys.exit(1)

    # Default output path: same directory as log, named diagram.html
    if len(sys.argv) >= 3:
        output_path = sys.argv[2]
    else:
        output_path = os.path.join(os.path.dirname(log_path), "diagram.html")

    events = parse_log(log_path)
    if not events:
        print("No events found in log")
        sys.exit(1)

    nodes, links = extract_session_graph(events)
    title = f"Session - {os.path.basename(os.path.dirname(log_path))}"
    html = generate_html(nodes, links, title)

    with open(output_path, "w") as f:
        f.write(html)

    print(f"Session diagram: {output_path}")
    print(f"  {len(nodes)} nodes, {len(links)} links")


if __name__ == "__main__":
    main()
