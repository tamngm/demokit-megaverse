"""
Pipeline rule checks, run by .github/workflows/pipeline-checks.yml on every push and PR.
Reads the repo files only: no AWS, no Athena, no S3.

Local run (from the repo root):
  .venv\\Scripts\\python.exe ci\\check_pipeline.py
Exit code 0 = all checks passed, 1 = at least one failure (each one is printed).
"""
import os
import re
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
DBT = ROOT / 'dbt_demokit_pro'
MODELS = DBT / 'models'
SEEDS = DBT / 'seeds'
DDL_DIR = ROOT / 'src' / 'loader' / 'load_config'

BRANCH_RE = re.compile(r'^(feat|fix|docs)/[a-z0-9][a-z0-9-]*$')
DATA_EXT = ('.parquet', '.xlsx', '.xls')
SECRET_RES = [
    re.compile(r'AKIA[0-9A-Z]{16}'),                                                      # AWS access key id
    re.compile(r'aws_secret_access_key\s*[=:]\s*["\']?[A-Za-z0-9/+]{40}', re.IGNORECASE),  # AWS secret key value
]

failures: list[str] = []


def fail(rule: str, where: str, detail: str) -> None:
    failures.append(f'[{rule}] {where}: {detail}')


def git(*args: str) -> str:
    return subprocess.run(['git', *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


# ---------- 1. branch name ----------
def check_branch() -> None:
    # GitHub sets GITHUB_HEAD_REF on pull requests and GITHUB_REF_NAME on pushes
    branch = os.getenv('GITHUB_HEAD_REF') or os.getenv('GITHUB_REF_NAME')
    if not branch:
        try:
            branch = git('branch', '--show-current').strip()
        except subprocess.CalledProcessError:
            return
    if not branch or branch == 'main':
        return
    if not BRANCH_RE.match(branch):
        fail('branch', branch, 'name must be feat/<uc>-<desc>, fix/<desc> or docs/<desc>, lowercase with -')


# ---------- 2. no data files, no secrets ----------
def check_files_and_secrets() -> None:
    for f in git('ls-files').splitlines():
        name = f.rsplit('/', 1)[-1].lower()
        if name == '.env' or name.endswith('.env'):
            fail('secrets', f, 'environment file must not be committed')
        elif name.endswith(DATA_EXT):
            fail('data', f, 'data files must not be committed (upload them to SharePoint / S3)')
        elif name.endswith('.csv') and not f.startswith('dbt_demokit_pro/seeds/'):
            fail('data', f, 'CSV files are only allowed in dbt_demokit_pro/seeds/')

        path = ROOT / f
        if not path.is_file() or path.stat().st_size > 5_000_000:
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except (UnicodeDecodeError, OSError):
            continue  # binary file
        for pattern in SECRET_RES:
            if pattern.search(text):
                fail('secrets', f, 'looks like an AWS key: move it to .env and rotate the key')
                break


# ---------- 3. DDL: DROP before CREATE, table declared in sources.yml ----------
def table_names(sql: str, verb_re: str) -> set[str]:
    names = re.findall(verb_re + r'\s+(?:IF\s+(?:NOT\s+)?EXISTS\s+)?([`\w.]+)', sql, re.IGNORECASE)
    return {n.replace('`', '').lower().split('.')[-1] for n in names}


def source_tables() -> set[str]:
    data = yaml.safe_load((MODELS / 'sources.yml').read_text(encoding='utf-8')) or {}
    return {t['name'].lower() for s in data.get('sources', []) for t in s.get('tables', [])}


def check_ddl() -> None:
    sources = source_tables()
    for f in sorted(DDL_DIR.glob('*.sql')):
        sql = re.sub(r'--.*', '', f.read_text(encoding='utf-8'))
        created = table_names(sql, r'CREATE\s+(?:EXTERNAL\s+)?TABLE')
        dropped = table_names(sql, r'DROP\s+TABLE')
        for t in sorted(created - dropped):
            fail('ddl', rel(f), f'{t}: add DROP TABLE IF EXISTS before its CREATE')
        for t in sorted(created - sources):
            fail('sources', rel(f), f'{t}: add it to dbt_demokit_pro/models/sources.yml')


# ---------- 4. models: listed in a yml; mart columns described ----------
def yml_models() -> dict[str, dict]:
    models = {}
    for f in MODELS.rglob('*.yml'):
        data = yaml.safe_load(f.read_text(encoding='utf-8')) or {}
        for m in data.get('models') or []:
            models[m['name']] = m
    return models


def check_models() -> None:
    documented = yml_models()
    for layer in ('work', 'mart'):
        for f in sorted((MODELS / layer).rglob('*.sql')):
            name = f.stem
            if name not in documented:
                fail('yml', rel(f), f'model {name} is not listed in a .yml in its folder')
                continue
            if not (documented[name].get('description') or '').strip():
                fail('yml', rel(f), f'model {name} has no description')
            if layer == 'mart':
                columns = documented[name].get('columns') or []
                if not columns:
                    fail('yml', rel(f), f'mart model {name} has no columns listed')
                for c in columns:
                    if not (c.get('description') or '').strip():
                        fail('yml', rel(f), f'{name}.{c.get("name")} has no description')
    # yml entries without a .sql (model renamed or deleted)
    sql_names = {f.stem for f in MODELS.rglob('*.sql')}
    for name in sorted(set(documented) - sql_names):
        fail('yml', 'dbt_demokit_pro/models', f'{name} is in a .yml but has no .sql: remove or rename its block')


# ---------- 5. seeds named ref_* ----------
def check_seeds() -> None:
    for f in sorted(SEEDS.rglob('*.csv')):
        if not f.name.startswith('ref_'):
            fail('seeds', rel(f), 'seed files must be named ref_<name>.csv')


def main() -> int:
    for check in (check_branch, check_files_and_secrets, check_ddl, check_models, check_seeds):
        check()
    if failures:
        print(f'{len(failures)} pipeline check(s) failed:\n')
        for line in failures:
            print('  ' + line)
        print('\nRules: docs/go-with-pipeline.md')
        return 1
    print('All pipeline checks passed.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
