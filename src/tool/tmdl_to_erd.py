"""Draw a simple ERD for each Power BI semantic model and add it to dbt docs.

Reads every fabricspace/**/<name>.SemanticModel/definition/relationships.tmdl and writes,
into dbt_demokit_pro/models/docs/erd/ (committed, so the team can view them; rerun after
relationships change):
  - <name>.svg   one diagram per semantic model
  - overview.md  the dbt docs landing page (__overview__) with every diagram embedded

Each box = table name + key (the column other tables point to). Lines use crow's foot
notation: crow's foot = many side, bar = one side (cardinality from the TMDL; Power BI's
default is many-to-one). Dashed = inactive relationship.

Fixed layout, not automatic:
  - fact tables (name contains "fact") in the center column, A-Z
  - dimensions linked to a fact: left and right of the facts, ordered to sit next to their facts
  - dimensions linked only to other dimensions: one column further out, on their targets' side
Standard library only.

Usage (repo root):  .venv\\Scripts\\python.exe src\\tool\\tmdl_to_erd.py
"""
from __future__ import annotations

import base64
import re
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
FABRIC = ROOT / "fabricspace"
OUT = ROOT / "dbt_demokit_pro" / "models" / "docs" / "erd"

# Layout constants (px). Monospace font so text width = chars * CHAR_W.
FONT, CHAR_W = 13, 7.9
PAD_X, LINE_H, BOX_GAP_Y, COL_GAP, MARGIN, TITLE_H = 12, 22, 28, 110, 24, 40
LINE_COLOR = "#555"


# ---------------------------------------------------------------- parsing
def split_ref(ref: str) -> tuple[str, str]:
    """'table.column' or "'my table'.'my col'" -> (table, column)."""
    parts = re.findall(r"'((?:[^']|'')*)'|([^.]+)", ref.strip())
    names = [(q.replace("''", "'") if q else p).strip() for q, p in parts]
    return names[0], names[1]


def parse_relationships(path: Path) -> list[dict]:
    rels, cur = [], None
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if line.startswith("relationship "):
            cur = {"active": True, "from_card": "many", "to_card": "one"}
            rels.append(cur)
        elif cur is not None and ":" in line:
            key, _, val = line.strip().partition(":")
            val = val.strip()
            if key == "fromColumn":
                cur["from"] = split_ref(val)
            elif key == "toColumn":
                cur["to"] = split_ref(val)
            elif key == "isActive":
                cur["active"] = val.lower() != "false"
            elif key == "fromCardinality":
                cur["from_card"] = val.lower()
            elif key == "toCardinality":
                cur["to_card"] = val.lower()
    return [r for r in rels if "from" in r and "to" in r and r["from"][0] != r["to"][0]]


# ---------------------------------------------------------------- layout
def layout(rels: list[dict]) -> tuple[list[list[str]], set[str]]:
    """Columns left -> right: [outer-left, inner-left, facts, inner-right, outer-right]."""
    tables = sorted({r["from"][0] for r in rels} | {r["to"][0] for r in rels})
    nbrs = {t: set() for t in tables}
    for r in rels:
        nbrs[r["from"][0]].add(r["to"][0])
        nbrs[r["to"][0]].add(r["from"][0])

    facts = [t for t in tables if "fact" in t.lower()]
    if not facts:  # fallback: tables that point to others
        facts = sorted({r["from"][0] for r in rels})
    row = {f: i for i, f in enumerate(facts)}

    def bary(t: str, pos: dict[str, float]) -> float:
        linked = [pos[n] for n in nbrs[t] if n in pos]
        return sum(linked) / len(linked) if linked else float("inf")

    inner = sorted((t for t in tables if t not in row and nbrs[t] & set(facts)),
                   key=lambda t: (bary(t, row), t))
    outer = sorted(t for t in tables if t not in row and t not in inner)

    # An outer dim (linked only to dims) and the inner dims it links to share one side,
    # so their lines stay short. Everything else fills the emptier side, in fact order.
    side: dict[str, str] = {}

    def emptier() -> str:
        return "L" if sum(s == "L" for s in side.values()) < sum(s == "R" for s in side.values()) else "R"

    for o in outer:
        s = next((side[n] for n in nbrs[o] if n in side), None) or emptier()
        for t in [o, *sorted(n for n in nbrs[o] if n in inner)]:
            side.setdefault(t, s)
    for t in inner:
        side.setdefault(t, emptier())

    left = [t for t in inner if side[t] == "L"]
    right = [t for t in inner if side[t] == "R"]
    pos = {t: i for i, t in enumerate(left)} | {t: i for i, t in enumerate(right)}
    outer_l = sorted((o for o in outer if side[o] == "L"), key=lambda t: (bary(t, pos), t))
    outer_r = sorted((o for o in outer if side[o] == "R"), key=lambda t: (bary(t, pos), t))

    return [c for c in (outer_l, left, facts, right, outer_r) if c], set(facts)


# ---------------------------------------------------------------- drawing
MARKERS = f"""<defs>
<marker id="many" viewBox="0 0 14 14" refX="14" refY="7" markerWidth="14" markerHeight="14"
  markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  <path d="M0,7 L14,0 M0,7 L14,7 M0,7 L14,14" fill="none" stroke="{LINE_COLOR}" stroke-width="1.4"/>
</marker>
<marker id="one" viewBox="0 0 14 14" refX="14" refY="7" markerWidth="14" markerHeight="14"
  markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  <path d="M0,7 L14,7 M7,0 L7,14" fill="none" stroke="{LINE_COLOR}" stroke-width="1.4"/>
</marker>
</defs>"""


def render_svg(title: str, rels: list[dict]) -> str:
    cols, facts = layout(rels)
    keys = {t: sorted({r["to"][1] for r in rels if r["to"][0] == t}) for c in cols for t in c}
    col_of = {t: i for i, c in enumerate(cols) for t in c}

    def lines(t: str) -> list[str]:
        return [t] + [f"🔑 {k}" for k in keys[t]]

    def box_h(t: str) -> float:
        return len(lines(t)) * LINE_H + 8

    col_w = [max(len(s) for t in c for s in lines(t)) * CHAR_W + 2 * PAD_X + 8 for c in cols]
    col_h = [sum(box_h(t) for t in c) + BOX_GAP_Y * (len(c) - 1) for c in cols]
    body_h = max(col_h)

    boxes: dict[str, tuple[float, float, float, float]] = {}
    x = MARGIN
    for c, col in enumerate(cols):
        y = MARGIN + TITLE_H + (body_h - col_h[c]) / 2  # center each column vertically
        for t in col:
            boxes[t] = (x, y, col_w[c], box_h(t))
            y += box_h(t) + BOX_GAP_Y
        x += col_w[c] + COL_GAP
    width = x - COL_GAP + MARGIN
    height = MARGIN + TITLE_H + body_h + MARGIN

    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:.0f}" height="{height:.0f}" '
        f'viewBox="0 0 {width:.0f} {height:.0f}" font-family="Consolas, Menlo, monospace" font-size="{FONT}">',
        MARKERS,
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        f'<text x="{MARGIN}" y="{MARGIN + 10}" font-size="15" font-weight="bold" fill="#222">{escape(title)}</text>',
    ]

    # Lines first so boxes sit on top. Lines leave and enter boxes horizontally,
    # so the crow's foot / bar markers sit flat against the box edge.
    for r in rels:
        a, b = r["from"][0], r["to"][0]
        ax, ay, aw, ah = boxes[a]
        bx, by, bw, bh = boxes[b]
        y1, y2 = ay + ah / 2, by + bh / 2
        if col_of[a] < col_of[b]:
            x1, x2 = ax + aw, bx
        elif col_of[a] > col_of[b]:
            x1, x2 = ax, bx + bw
        else:  # same column (e.g. fact -> fact): loop out on the right side
            x1, x2 = ax + aw, bx + bw
        if col_of[a] == col_of[b]:
            off = 30 + 0.15 * abs(y2 - y1)
            c1, c2 = x1 + off, x2 + off
        else:
            c1 = c2 = (x1 + x2) / 2
        dash = "" if r["active"] else ' stroke-dasharray="6 4"'
        start = "many" if r["from_card"] == "many" else "one"
        end = "many" if r["to_card"] == "many" else "one"
        svg.append(
            f'<path d="M{x1:.1f},{y1:.1f} C{c1:.1f},{y1:.1f} {c2:.1f},{y2:.1f} {x2:.1f},{y2:.1f}" '
            f'fill="none" stroke="{LINE_COLOR}" stroke-width="1.4"{dash} '
            f'marker-start="url(#{start})" marker-end="url(#{end})"/>'
        )

    for t, (bx, by, bw, bh) in boxes.items():
        fill = "#fff4e0" if t in facts else "#f7f9fc"
        svg.append(f'<rect x="{bx:.1f}" y="{by:.1f}" width="{bw:.1f}" height="{bh:.1f}" rx="4" '
                   f'fill="{fill}" stroke="#33475b" stroke-width="1.2"/>')
        for i, s in enumerate(lines(t)):
            weight = ' font-weight="bold"' if i == 0 else ""
            color = "#1a1a1a" if i == 0 else "#7a5a00"
            svg.append(f'<text x="{bx + PAD_X:.1f}" y="{by + 4 + (i + 0.75) * LINE_H:.1f}"'
                       f'{weight} fill="{color}">{escape(s)}</text>')
        if keys[t]:
            sep_y = by + 4 + LINE_H + 2
            svg.append(f'<line x1="{bx:.1f}" y1="{sep_y:.1f}" x2="{bx + bw:.1f}" y2="{sep_y:.1f}" '
                       f'stroke="#c5ced8"/>')
    svg.append("</svg>")
    return "\n".join(svg)


# ---------------------------------------------------------------- main
def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sections = []
    for tmdl in sorted(FABRIC.glob("**/*.SemanticModel/definition/relationships.tmdl")):
        name = tmdl.parents[1].name.removesuffix(".SemanticModel")
        rels = parse_relationships(tmdl)
        if not rels:
            continue
        svg = render_svg(name, rels)
        slug = re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")
        (OUT / f"{slug}.svg").write_text(svg, encoding="utf-8")
        data = base64.b64encode(svg.encode("utf-8")).decode("ascii")
        source = tmdl.relative_to(ROOT).as_posix()
        sections.append(f"## {name}\n\nSource: `{source}`\n\n![{name}](data:image/svg+xml;base64,{data})\n")
        print(f"ERD: {slug}.svg  ({len(rels)} relationships)")

    overview = (
        "{% docs __overview__ %}\n"
        "# Data models per dataset kit\n\n"
        "Generated by `src/tool/tmdl_to_erd.py` from the Power BI `relationships.tmdl` files. "
        "Facts (orange) in the center, dimensions around them. Box = table + key. "
        "Lines use crow's foot notation: crow's foot = many, bar = one. Dashed = inactive. "
        "Use the lineage graph (blue button, bottom right) for dbt dependencies.\n\n"
        + "\n".join(sections)
        + "\n{% enddocs %}\n"
    )
    (OUT / "overview.md").write_text(overview, encoding="utf-8")
    print(f"Docs page: {(OUT / 'overview.md').relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
