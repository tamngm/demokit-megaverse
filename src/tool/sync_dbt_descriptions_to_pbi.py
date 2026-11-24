"""
Copy table and column descriptions from dbt (the model .yml files) into a Power BI semantic model (PBIP / TMDL),
so they show as tooltips in Power BI and are used by Copilot / Q&A. The dbt .yml stays the single source.

How it matches:
  Power BI table  <-> dbt model with the same name      (e.g. uc5_srm_fact_quotes)
  Power BI column <-> dbt column with the same name, else the column's sourceColumn
Descriptions are written as `///` lines above each `table` / `column` in the .tmdl files (existing ones replaced).
Measures, calculated tables and columns without a dbt match are left as they are and listed at the end.

Usage (from the repo root; close the report in Power BI Desktop first, or it will overwrite the files on save):
  1. refresh dbt's manifest:   cd dbt_demokit_pro; dbt parse; cd ..
  2. preview:                  .venv\\Scripts\\python.exe src\\tool\\sync_dbt_descriptions_to_pbi.py --model "<...>.SemanticModel" --dry-run
  3. write:                    .venv\\Scripts\\python.exe src\\tool\\sync_dbt_descriptions_to_pbi.py --model "<...>.SemanticModel"
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_MANIFEST = ROOT / 'dbt_demokit_pro' / 'target' / 'manifest.json'

# `table name`, `column name`, `column 'name with spaces'`; a calculated column has `= <expression>`
OBJECT_RE = re.compile(r"^(?P<indent>\t*)(?P<kind>table|column) (?P<name>'(?:[^']|'')+'|[^\s=]+)(?P<rest>.*)$")
SOURCE_RE = re.compile(r'^\t+sourceColumn:\s*(?P<src>.+?)\s*$')


def unquote(name: str) -> str:
    return name[1:-1].replace("''", "'") if name.startswith("'") else name


def load_dbt_docs(manifest_path: Path) -> dict[str, tuple[str, dict[str, str]]]:
    """{model name: (model description, {column name: column description})}, names lower-cased."""
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    docs = {}
    for node in manifest['nodes'].values():
        if node.get('resource_type') not in ('model', 'seed'):
            continue
        columns = {c.lower(): (v.get('description') or '').strip() for c, v in node.get('columns', {}).items()}
        docs[node['name'].lower()] = ((node.get('description') or '').strip(), columns)
    return docs


def one_line(text: str) -> str:
    return ' '.join(text.split())


def sync_file(path: Path, docs: dict, dry_run: bool) -> dict:
    raw = path.read_bytes()
    bom = raw.startswith(b'\xef\xbb\xbf')
    text = raw.decode('utf-8-sig')
    newline = '\r\n' if '\r\n' in text else '\n'
    lines = text.split(newline)

    result = {'table': None, 'model': None, 'set': 0, 'unmatched': []}
    model_cols: dict[str, str] = {}
    out: list[str] = []
    for i, line in enumerate(lines):
        m = OBJECT_RE.match(line)
        if not m or (m['kind'] == 'column' and m['rest'].strip().startswith('=')):
            out.append(line)  # not a table/column, or a calculated column (no dbt source)
            continue
        name = unquote(m['name'])
        while out and out[-1].strip().startswith('///'):  # replace any existing description
            out.pop()

        description = ''
        if m['kind'] == 'table':
            result['table'] = name
            model = docs.get(name.lower())
            if model:
                result['model'] = name
                description, model_cols = model
            else:
                model_cols = {}
        else:
            # match by column name, else by the sourceColumn of this column block
            description = model_cols.get(name.lower(), '')
            if not description:
                for nxt in lines[i + 1:]:
                    if OBJECT_RE.match(nxt) or nxt.startswith('\tpartition'):
                        break
                    s = SOURCE_RE.match(nxt)
                    if s:
                        description = model_cols.get(unquote(s['src']).lower(), '')
                        break
            if description:
                result['set'] += 1
            elif model_cols:
                result['unmatched'].append(name)
        if description:
            out.append(f"{m['indent']}/// {one_line(description)}")
        out.append(line)

    new_text = newline.join(out)
    if new_text != text and not dry_run:
        path.write_bytes((b'\xef\xbb\xbf' if bom else b'') + new_text.encode('utf-8'))
    result['changed'] = new_text != text
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description='Copy dbt descriptions into a Power BI semantic model (TMDL).')
    parser.add_argument('--model', required=True, help='Path to the <name>.SemanticModel folder')
    parser.add_argument('--manifest', default=str(DEFAULT_MANIFEST), help='dbt manifest.json (default: dbt target)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would change, write nothing')
    args = parser.parse_args()

    tables_dir = Path(args.model) / 'definition' / 'tables'
    if not tables_dir.is_dir():
        sys.exit(f'No definition/tables folder in {args.model} (is it a PBIP .SemanticModel folder in TMDL format?)')
    manifest = Path(args.manifest)
    if not manifest.is_file():
        sys.exit(f'dbt manifest not found: {manifest}. Run `dbt parse` in dbt_demokit_pro first.')

    docs = load_dbt_docs(manifest)
    print(('DRY RUN: nothing written\n' if args.dry_run else '') + f'Semantic model: {Path(args.model).name}\n')
    skipped = []
    for f in sorted(tables_dir.glob('*.tmdl')):
        r = sync_file(f, docs, args.dry_run)
        if not r['model']:
            skipped.append(r['table'] or f.stem)
            continue
        line = f"  {r['table']:40} table + {r['set']} column description(s)"
        if r['unmatched']:
            line += f"   | no dbt description: {', '.join(r['unmatched'])}"
        print(line)
    if skipped:
        print(f"\nNo dbt model with the same name (left as is): {', '.join(skipped)}")
    print('\nReopen the report in Power BI Desktop to see the descriptions (hover a field in the Data pane).')
    return 0


if __name__ == '__main__':
    sys.exit(main())
