"""PreToolUse guard for Bash/PowerShell commands (see .claude/settings.json).

Blocks (exit 2, reason on stderr for Claude):
  1. reading/printing secret files (.env, ~/.aws/credentials) or secret env vars
  2. git commit while on main
  3. git push to main / from main
  4. git commit whose staged changes contain secret-looking strings
"""
import json
import re
import subprocess
import sys

SECRET_FILE = re.compile(r'\.env\b|\.aws[\\/]+credentials', re.IGNORECASE)
READ_VERB = re.compile(
    r'\b(cat|type|gc|get-content|more|less|head|tail|select-string|sls|findstr|grep|rg|strings|bat|copy|cp)\b',
    re.IGNORECASE)
SECRET_VAR_PRINT = re.compile(
    r'(echo|print|write-output|write-host)\b.*(AWS_SECRET_ACCESS_KEY|AWS_ACCESS_KEY_ID|HF_TOKEN|GIT_PAT)'
    r'|\$env:(AWS_SECRET_ACCESS_KEY|AWS_ACCESS_KEY_ID|HF_TOKEN|GIT_PAT)',
    re.IGNORECASE)
GIT_COMMIT = re.compile(r'\bgit\b[^|;&\n]*\bcommit\b')
GIT_PUSH = re.compile(r'\bgit\b[^|;&\n]*\bpush\b[^|;&\n]*')
SECRET_PATTERNS = {
    'AWS access key id': re.compile(r'\b(AKIA|ASIA)[0-9A-Z]{16}\b'),
    'AWS secret access key': re.compile(r'(?i)aws_secret_access_key\s*[=:]\s*[\'"]?[A-Za-z0-9/+]{30,}'),
    'HuggingFace token': re.compile(r'\bhf_[A-Za-z0-9]{30,}'),
    'GitHub token': re.compile(r'\b(ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})'),
}


def block(reason: str) -> None:
    print(f'Blocked by .claude/hooks/guard.py: {reason}', file=sys.stderr)
    sys.exit(2)


def git(cwd: str, *args: str) -> str:
    result = subprocess.run(['git', *args], cwd=cwd, capture_output=True)
    return result.stdout.decode('utf-8', errors='replace')


def find_staged_secrets(cwd: str, all_tracked: bool) -> list[str]:
    """Returns 'file: pattern name' for each added line that looks like a secret (values never printed)."""
    diff = git(cwd, 'diff', 'HEAD' if all_tracked else '--cached', '-U0', '--no-color')
    hits, current_file = [], '?'
    for line in diff.splitlines():
        if line.startswith('+++ '):
            current_file = line[6:] if line.startswith('+++ b/') else line[4:]
        elif line.startswith('+'):
            hits += [f'{current_file}: {name}' for name, rx in SECRET_PATTERNS.items() if rx.search(line)]
    return sorted(set(hits))


def main() -> None:
    data = json.load(sys.stdin)
    cmd = (data.get('tool_input') or {}).get('command', '')
    cwd = data.get('cwd') or '.'

    if SECRET_FILE.search(cmd) and READ_VERB.search(cmd):
        block('reading secret files (.env, ~/.aws/credentials) is not allowed. '
              'To see which settings exist, read src/config.py instead.')
    if SECRET_VAR_PRINT.search(cmd):
        block('printing secret environment variables is not allowed. Log "loaded: yes/no" instead of values.')

    commit = GIT_COMMIT.search(cmd)
    push = GIT_PUSH.search(cmd)
    if commit or push:
        branch = git(cwd, 'rev-parse', '--abbrev-ref', 'HEAD').strip()
        if commit and branch == 'main':
            block('committing on main is not allowed. Create a branch first: git switch -c feat/<uc>-<desc>')
        if push and (branch == 'main' or re.search(r'(\s|:)main\b', push.group(0))):
            block('pushing to main is not allowed. Push your branch and open a Pull Request.')
        if commit:
            hits = find_staged_secrets(cwd, all_tracked=bool(re.search(r'\s-[a-zA-Z]*a', commit.group(0))))
            if hits:
                block('staged changes look like they contain secrets: ' + '; '.join(hits)
                      + '. Remove them (use .env + src/config.py) and tell the user which key may be exposed.')


if __name__ == '__main__':
    main()
