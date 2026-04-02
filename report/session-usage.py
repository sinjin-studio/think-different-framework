#!/usr/bin/env python3
"""Generate token usage and cost report from log.jsonl.

Usage:
    python3 report/session-usage.py <session-dir>/log.jsonl [output.html]

Reads API call logs with usage data and produces a self-contained HTML file
with Chart.js visualizations showing token usage, cost, and cache efficiency.
"""

import json
import sys
import os
from collections import defaultdict
from datetime import datetime


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


def categorize_caller(caller):
    """Map caller string to a display category."""
    if caller.startswith("conductor"):
        # Distinguish phase1/phase2 if present, otherwise just "conductor"
        if "phase1" in caller or "pre" in caller:
            return "conductor:phase1"
        elif "phase2" in caller or "post" in caller:
            return "conductor:phase2"
        return "conductor"
    elif caller.startswith("lens:"):
        return "lens"
    elif caller.startswith("mechanism:"):
        return "mechanism"
    elif caller.startswith("seed:") or caller.startswith("provoke") or caller.startswith("fracture") or caller.startswith("tune") or caller.startswith("appraise"):
        return "seed"
    elif caller.startswith("gather"):
        return "gather"
    elif caller.startswith("report") or caller.startswith("generate") or caller.startswith("line") or caller.startswith("distil") or caller.startswith("asset") or caller.startswith("brief") or caller.startswith("manifesto") or caller.startswith("insight") or caller.startswith("monologue"):
        return "report"
    elif caller.startswith("review") or caller.startswith("prosecut") or caller.startswith("defense") or caller.startswith("verdict"):
        return "review"
    elif caller.startswith("ground") or caller.startswith("verif"):
        return "ground"
    else:
        return "other"


CATEGORY_COLORS = {
    "conductor:phase1": "#169B62",   # green - pre-lens routing
    "conductor:phase2": "#0D7A4A",   # darker green - post-lens reaction
    "conductor": "#12B86A",          # bright green - generic conductor
    "lens": "#FF8200",               # orange
    "mechanism": "#E84855",          # red
    "seed": "#4ECDC4",               # teal
    "gather": "#9B59B6",             # purple
    "report": "#F39C12",             # amber
    "review": "#E74C3C",             # crimson
    "ground": "#3498DB",             # blue
    "other": "#95A5A6",              # grey
}


def extract_usage_data(events):
    """Extract usage data from log events."""
    calls = []
    for i, event in enumerate(events):
        usage = event.get("usage", {})
        caller = event.get("caller", "unknown")
        call_type = event.get("type", "")

        # Skip non-API entries (wait_enter, wait_success, etc.)
        if call_type not in ("claude_call", "claude_call_json"):
            continue

        category = categorize_caller(caller)
        calls.append({
            "index": len(calls),
            "caller": caller,
            "category": category,
            "type": call_type,
            "ts": event.get("ts", ""),
            "input_tokens": usage.get("input_tokens", 0),
            "output_tokens": usage.get("output_tokens", 0),
            "cache_creation": usage.get("cache_creation_input_tokens", 0),
            "cache_read": usage.get("cache_read_input_tokens", 0),
            "cost_usd": usage.get("cost_usd", 0),
            "duration_ms": usage.get("duration_ms", 0),
            "has_usage": bool(usage),
        })

    return calls


def compute_stats(calls):
    """Compute summary statistics."""
    if not calls:
        return {}

    total_cost = sum(c["cost_usd"] for c in calls)
    total_input = sum(c["input_tokens"] for c in calls)
    total_output = sum(c["output_tokens"] for c in calls)
    total_cache_creation = sum(c["cache_creation"] for c in calls)
    total_cache_read = sum(c["cache_read"] for c in calls)
    total_duration = sum(c["duration_ms"] for c in calls)
    has_usage = any(c["has_usage"] for c in calls)

    # Cache hit rate
    total_cacheable = total_cache_read + total_cache_creation + total_input
    cache_hit_rate = (total_cache_read / total_cacheable * 100) if total_cacheable > 0 else 0

    # Conductor overhead
    conductor_cost = sum(c["cost_usd"] for c in calls if c["category"].startswith("conductor"))
    conductor_pct = (conductor_cost / total_cost * 100) if total_cost > 0 else 0

    # Cost by category
    cost_by_category = defaultdict(float)
    for c in calls:
        cost_by_category[c["category"]] += c["cost_usd"]

    # Session wall clock
    timestamps = [c["ts"] for c in calls if c["ts"]]
    wall_clock_mins = 0
    if len(timestamps) >= 2:
        try:
            t0 = datetime.fromisoformat(timestamps[0])
            t1 = datetime.fromisoformat(timestamps[-1])
            wall_clock_mins = (t1 - t0).total_seconds() / 60
        except (ValueError, TypeError):
            pass

    return {
        "total_calls": len(calls),
        "total_cost": total_cost,
        "total_input": total_input,
        "total_output": total_output,
        "total_cache_creation": total_cache_creation,
        "total_cache_read": total_cache_read,
        "total_duration": total_duration,
        "cache_hit_rate": cache_hit_rate,
        "conductor_cost": conductor_cost,
        "conductor_pct": conductor_pct,
        "cost_by_category": dict(cost_by_category),
        "wall_clock_mins": wall_clock_mins,
        "has_usage": has_usage,
        "avg_cost": total_cost / len(calls) if calls else 0,
        "avg_duration": total_duration / len(calls) if calls else 0,
    }


def identify_turns(calls):
    """Group calls into turns (conductor-pre + lens + conductor-post)."""
    turns = []
    current_turn = []
    for c in calls:
        current_turn.append(c["index"])
        # A turn boundary: after a lens call when the next call is conductor
        if c["category"] == "lens":
            # Look ahead - if next is conductor or mechanism, this turn ends
            turns.append(current_turn)
            current_turn = []
    if current_turn:
        turns.append(current_turn)
    return turns


def generate_html(calls, stats, title="Usage Report"):
    """Generate self-contained HTML with Chart.js visualizations."""

    calls_json = json.dumps(calls)
    stats_json = json.dumps(stats)
    colors_json = json.dumps(CATEGORY_COLORS)
    turns_json = json.dumps(identify_turns(calls))

    no_data_msg = ""
    if not stats.get("has_usage"):
        no_data_msg = """
        <div style="background:#2a1a00;border:1px solid #FF8200;border-radius:8px;padding:16px 24px;margin-bottom:24px;color:#FF8200;font-size:14px;">
            This log was recorded before usage tracking was enabled. Token and cost data is not available.
            Re-run the session to capture usage data.
        </div>"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    background: #181818;
    color: #e0e0e0;
    font-family: 'Literata', Georgia, serif;
    padding: 24px;
    max-width: 1400px;
    margin: 0 auto;
  }}
  h1 {{
    font-size: 20px;
    color: #169B62;
    margin-bottom: 8px;
  }}
  h2 {{
    font-size: 15px;
    color: #999;
    font-weight: normal;
    margin-bottom: 24px;
  }}
  h3 {{
    font-size: 14px;
    color: #ccc;
    margin-bottom: 12px;
  }}

  /* Summary stats */
  .stats-grid {{
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
    gap: 12px;
    margin-bottom: 32px;
  }}
  .stat-card {{
    background: #222;
    border: 1px solid #333;
    border-radius: 8px;
    padding: 16px;
  }}
  .stat-value {{
    font-size: 22px;
    font-weight: bold;
    color: #FF8200;
  }}
  .stat-value.green {{ color: #169B62; }}
  .stat-value.red {{ color: #E84855; }}
  .stat-label {{
    font-size: 11px;
    color: #888;
    margin-top: 4px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }}

  /* Chart cards */
  .charts-grid {{
    display: grid;
    grid-template-columns: 1fr;
    gap: 24px;
  }}
  .charts-row {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 24px;
  }}
  @media (max-width: 900px) {{
    .charts-row {{ grid-template-columns: 1fr; }}
  }}
  .chart-card {{
    background: #222;
    border: 1px solid #333;
    border-radius: 8px;
    padding: 20px;
  }}
  .chart-card.full-width {{
    grid-column: 1 / -1;
  }}
  canvas {{
    width: 100% !important;
  }}

  /* Legend for turn grouping */
  .turn-legend {{
    font-size: 11px;
    color: #666;
    margin-top: 4px;
  }}
</style>
</head>
<body>
<h1>Token Usage Report</h1>
<h2>{title}</h2>
{no_data_msg}

<!-- Summary Stats -->
<div class="stats-grid" id="stats-grid"></div>

<!-- Primary: Cost timeline -->
<div class="charts-grid">
  <div class="chart-card">
    <h3>Cost per call (USD) - sequential timeline</h3>
    <div class="turn-legend">Alternating background bands show turn grouping (conductor + lens + conductor)</div>
    <canvas id="costTimeline" height="100"></canvas>
  </div>
</div>

<!-- Supporting charts -->
<div class="charts-row" style="margin-top:24px">
  <div class="chart-card">
    <h3>Token breakdown per call</h3>
    <canvas id="tokenBreakdown" height="120"></canvas>
  </div>
  <div class="chart-card">
    <h3>Cost by caller category</h3>
    <canvas id="costByCategory" height="120"></canvas>
  </div>
</div>

<div class="charts-row" style="margin-top:24px">
  <div class="chart-card">
    <h3>Cumulative cost (USD)</h3>
    <canvas id="cumulativeCost" height="120"></canvas>
  </div>
  <div class="chart-card">
    <h3>Top 10 most expensive calls</h3>
    <canvas id="topCalls" height="120"></canvas>
  </div>
</div>

<div class="charts-row" style="margin-top:24px">
  <div class="chart-card">
    <h3>Cache efficiency</h3>
    <canvas id="cacheEfficiency" height="120"></canvas>
  </div>
  <div class="chart-card">
    <h3>Duration per call (ms)</h3>
    <canvas id="durationChart" height="120"></canvas>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
<script>
const calls = {calls_json};
const stats = {stats_json};
const categoryColors = {colors_json};
const turns = {turns_json};

// Chart.js defaults
Chart.defaults.color = '#999';
Chart.defaults.borderColor = '#333';
Chart.defaults.font.family = "'Literata', Georgia, serif";
Chart.defaults.font.size = 11;

// Helpers
function formatCost(v) {{ return '$' + v.toFixed(4); }}
function formatTokens(v) {{ return v.toLocaleString(); }}
function getCategoryColor(cat) {{ return categoryColors[cat] || '#95A5A6'; }}

// Summary stats
const statsGrid = document.getElementById('stats-grid');
const statItems = [
  {{ value: stats.total_calls, label: 'Total API calls', cls: '' }},
  {{ value: '$' + stats.total_cost.toFixed(4), label: 'Total cost (USD)', cls: 'green' }},
  {{ value: formatTokens(stats.total_input), label: 'Input tokens', cls: '' }},
  {{ value: formatTokens(stats.total_output), label: 'Output tokens', cls: '' }},
  {{ value: formatTokens(stats.total_cache_read), label: 'Cache read tokens', cls: 'green' }},
  {{ value: formatTokens(stats.total_cache_creation), label: 'Cache creation tokens', cls: '' }},
  {{ value: stats.cache_hit_rate.toFixed(1) + '%', label: 'Cache hit rate', cls: stats.cache_hit_rate > 50 ? 'green' : 'red' }},
  {{ value: stats.conductor_pct.toFixed(1) + '%', label: 'Conductor overhead', cls: stats.conductor_pct > 40 ? 'red' : '' }},
  {{ value: (stats.total_duration / 1000).toFixed(1) + 's', label: 'Total API time', cls: '' }},
  {{ value: stats.wall_clock_mins.toFixed(1) + 'm', label: 'Wall clock time', cls: '' }},
];
statItems.forEach(s => {{
  const card = document.createElement('div');
  card.className = 'stat-card';
  card.innerHTML = `<div class="stat-value ${{s.cls}}">${{s.value}}</div><div class="stat-label">${{s.label}}</div>`;
  statsGrid.appendChild(card);
}});

// Turn background bands plugin
const turnBandsPlugin = {{
  id: 'turnBands',
  beforeDraw(chart) {{
    const ctx = chart.ctx;
    const xAxis = chart.scales.x;
    const yAxis = chart.scales.y;
    turns.forEach((indices, i) => {{
      if (i % 2 === 0) return; // only shade odd turns
      if (indices.length === 0) return;
      const first = indices[0];
      const last = indices[indices.length - 1];
      // Get pixel positions
      const x0 = xAxis.getPixelForValue(first) - (xAxis.getPixelForValue(1) - xAxis.getPixelForValue(0)) / 2;
      const x1 = xAxis.getPixelForValue(last) + (xAxis.getPixelForValue(1) - xAxis.getPixelForValue(0)) / 2;
      ctx.save();
      ctx.fillStyle = 'rgba(255,255,255,0.03)';
      ctx.fillRect(x0, yAxis.top, x1 - x0, yAxis.bottom - yAxis.top);
      ctx.restore();
    }});
  }}
}};

// 1. Cost timeline (primary chart)
new Chart(document.getElementById('costTimeline'), {{
  type: 'bar',
  plugins: [turnBandsPlugin],
  data: {{
    labels: calls.map(c => c.caller),
    datasets: [{{
      data: calls.map(c => c.cost_usd),
      backgroundColor: calls.map(c => getCategoryColor(c.category)),
      borderWidth: 0,
      borderRadius: 2,
    }}]
  }},
  options: {{
    responsive: true,
    plugins: {{
      legend: {{ display: false }},
      tooltip: {{
        callbacks: {{
          title: (items) => {{
            const c = calls[items[0].dataIndex];
            return c.caller + ' (' + c.type + ')';
          }},
          label: (item) => {{
            const c = calls[item.dataIndex];
            return [
              'Cost: ' + formatCost(c.cost_usd),
              'Input: ' + formatTokens(c.input_tokens),
              'Output: ' + formatTokens(c.output_tokens),
              'Cache read: ' + formatTokens(c.cache_read),
              'Cache create: ' + formatTokens(c.cache_creation),
              'Duration: ' + (c.duration_ms / 1000).toFixed(1) + 's'
            ];
          }}
        }}
      }}
    }},
    scales: {{
      x: {{
        ticks: {{ maxRotation: 45, font: {{ size: 9 }} }}
      }},
      y: {{
        title: {{ display: true, text: 'Cost (USD)' }},
        ticks: {{ callback: v => '$' + v.toFixed(3) }}
      }}
    }}
  }}
}});

// 2. Token breakdown (stacked bar)
new Chart(document.getElementById('tokenBreakdown'), {{
  type: 'bar',
  data: {{
    labels: calls.map(c => c.caller),
    datasets: [
      {{
        label: 'Input tokens',
        data: calls.map(c => c.input_tokens),
        backgroundColor: '#95A5A6',
        borderWidth: 0,
      }},
      {{
        label: 'Cache creation',
        data: calls.map(c => c.cache_creation),
        backgroundColor: '#FF8200',
        borderWidth: 0,
      }},
      {{
        label: 'Cache read',
        data: calls.map(c => c.cache_read),
        backgroundColor: '#169B62',
        borderWidth: 0,
      }},
      {{
        label: 'Output tokens',
        data: calls.map(c => c.output_tokens),
        backgroundColor: '#4ECDC4',
        borderWidth: 0,
      }}
    ]
  }},
  options: {{
    responsive: true,
    plugins: {{ legend: {{ position: 'top', labels: {{ boxWidth: 12 }} }} }},
    scales: {{
      x: {{ stacked: true, ticks: {{ maxRotation: 45, font: {{ size: 9 }} }} }},
      y: {{ stacked: true, title: {{ display: true, text: 'Tokens' }}, ticks: {{ callback: v => v.toLocaleString() }} }}
    }}
  }}
}});

// 3. Cost by category (horizontal bar)
const categories = Object.keys(stats.cost_by_category).sort((a, b) => stats.cost_by_category[b] - stats.cost_by_category[a]);
new Chart(document.getElementById('costByCategory'), {{
  type: 'bar',
  data: {{
    labels: categories,
    datasets: [{{
      data: categories.map(c => stats.cost_by_category[c]),
      backgroundColor: categories.map(c => getCategoryColor(c)),
      borderWidth: 0,
      borderRadius: 3,
    }}]
  }},
  options: {{
    indexAxis: 'y',
    responsive: true,
    plugins: {{
      legend: {{ display: false }},
      tooltip: {{ callbacks: {{ label: item => formatCost(item.raw) }} }}
    }},
    scales: {{
      x: {{ title: {{ display: true, text: 'Cost (USD)' }}, ticks: {{ callback: v => '$' + v.toFixed(3) }} }}
    }}
  }}
}});

// 4. Cumulative cost (line)
let runningCost = 0;
const cumCosts = calls.map(c => {{ runningCost += c.cost_usd; return runningCost; }});
new Chart(document.getElementById('cumulativeCost'), {{
  type: 'line',
  data: {{
    labels: calls.map(c => c.caller),
    datasets: [{{
      data: cumCosts,
      borderColor: '#169B62',
      backgroundColor: 'rgba(22,155,98,0.1)',
      fill: true,
      tension: 0.2,
      pointRadius: 2,
      pointHoverRadius: 5,
      borderWidth: 2,
    }}]
  }},
  options: {{
    responsive: true,
    plugins: {{
      legend: {{ display: false }},
      tooltip: {{ callbacks: {{ label: item => formatCost(item.raw) }} }}
    }},
    scales: {{
      x: {{ ticks: {{ maxRotation: 45, font: {{ size: 9 }} }} }},
      y: {{ title: {{ display: true, text: 'Cumulative USD' }}, ticks: {{ callback: v => '$' + v.toFixed(3) }} }}
    }}
  }}
}});

// 5. Top 10 most expensive calls
const sorted = [...calls].sort((a, b) => b.cost_usd - a.cost_usd).slice(0, 10);
new Chart(document.getElementById('topCalls'), {{
  type: 'bar',
  data: {{
    labels: sorted.map(c => c.caller),
    datasets: [{{
      data: sorted.map(c => c.cost_usd),
      backgroundColor: sorted.map(c => getCategoryColor(c.category)),
      borderWidth: 0,
      borderRadius: 3,
    }}]
  }},
  options: {{
    indexAxis: 'y',
    responsive: true,
    plugins: {{
      legend: {{ display: false }},
      tooltip: {{
        callbacks: {{
          label: item => {{
            const c = sorted[item.dataIndex];
            return [formatCost(c.cost_usd), 'In: ' + formatTokens(c.input_tokens), 'Out: ' + formatTokens(c.output_tokens)];
          }}
        }}
      }}
    }},
    scales: {{
      x: {{ title: {{ display: true, text: 'Cost (USD)' }}, ticks: {{ callback: v => '$' + v.toFixed(3) }} }}
    }}
  }}
}});

// 6. Cache efficiency (doughnut)
new Chart(document.getElementById('cacheEfficiency'), {{
  type: 'doughnut',
  data: {{
    labels: ['Cache read (hits)', 'Cache creation (misses)', 'Uncached input'],
    datasets: [{{
      data: [stats.total_cache_read, stats.total_cache_creation, stats.total_input],
      backgroundColor: ['#169B62', '#FF8200', '#95A5A6'],
      borderWidth: 1,
      borderColor: '#222',
    }}]
  }},
  options: {{
    responsive: true,
    plugins: {{
      legend: {{ position: 'bottom', labels: {{ boxWidth: 12, padding: 16 }} }},
      tooltip: {{ callbacks: {{ label: item => item.label + ': ' + formatTokens(item.raw) + ' tokens' }} }}
    }}
  }}
}});

// 7. Duration per call
new Chart(document.getElementById('durationChart'), {{
  type: 'bar',
  data: {{
    labels: calls.map(c => c.caller),
    datasets: [{{
      data: calls.map(c => c.duration_ms),
      backgroundColor: calls.map(c => getCategoryColor(c.category)),
      borderWidth: 0,
      borderRadius: 2,
    }}]
  }},
  options: {{
    responsive: true,
    plugins: {{
      legend: {{ display: false }},
      tooltip: {{
        callbacks: {{
          title: items => calls[items[0].dataIndex].caller,
          label: item => (item.raw / 1000).toFixed(1) + 's'
        }}
      }}
    }},
    scales: {{
      x: {{ ticks: {{ maxRotation: 45, font: {{ size: 9 }} }} }},
      y: {{ title: {{ display: true, text: 'Duration (ms)' }}, ticks: {{ callback: v => (v/1000).toFixed(1) + 's' }} }}
    }}
  }}
}});
</script>
</body>
</html>"""


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 session-usage.py <log.jsonl> [output.html]")
        sys.exit(1)

    log_path = sys.argv[1]
    if not os.path.exists(log_path):
        print(f"Error: {log_path} not found")
        sys.exit(1)

    if len(sys.argv) >= 3:
        output_path = sys.argv[2]
    else:
        output_path = os.path.join(os.path.dirname(log_path), "usage.html")

    events = parse_log(log_path)
    if not events:
        print("No events found in log")
        sys.exit(1)

    calls = extract_usage_data(events)
    if not calls:
        print("No API calls found in log")
        sys.exit(1)

    stats = compute_stats(calls)
    title = f"Session - {os.path.basename(os.path.dirname(os.path.abspath(log_path)))}"
    html = generate_html(calls, stats, title)

    with open(output_path, "w") as f:
        f.write(html)

    print(f"Usage report: {output_path}")
    if stats.get("has_usage"):
        print(f"  {stats['total_calls']} calls, ${stats['total_cost']:.4f} total, {stats['cache_hit_rate']:.1f}% cache hit rate")
    else:
        print("  No usage data found - re-run session to capture token data")


if __name__ == "__main__":
    main()
