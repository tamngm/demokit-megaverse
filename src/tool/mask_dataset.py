"""
Deterministic masking of the CSVs made by split_excel_tab_to_csv.py, driven by the data dictionary.

The rule of each column is read from the `masking_rule` column of <file>_data_dictionary.csv (empty = keep).
Same MASKING_KEY + same value = same masked value, in every column, tab and run, so the links between
tables (keys, codes, names) are kept.

Rules:
  keep          unchanged
  token         codes and ids: split into letter parts and number parts, each part masked on its own,
                separators kept. Same part -> same mask everywhere:
                  OID-376695           -> KQX-829104
                  OCD31-SUEZ_Devis     -> RTM58-HWAL_Qbnlz
  fake_company  realistic fake company name
  fake_person   fake first + last name
  fake_address  fake company name + street address
  scale_amount  x one secret factor (0.70-1.30), same for every amount: sums and ratios stay consistent
  shift_date    - one secret number of days, same for every date: durations and order stay correct
  scrub_text    free text: every value masked by the rules above is replaced by its mask; emails removed
  drop          column removed

Usage (MASKING_KEY must be set in .env):
  .venv\\Scripts\\python.exe src\\tool\\mask_dataset.py --dir "<folder>" [--file pulse_sku_kb] [--out "<folder>\\masked"]
"""
import argparse
import hashlib
import hmac
import re
import sys
from pathlib import Path

import pandas as pd
from faker import Faker

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))  # src/ for config.py
import config

ENC = 'utf-8-sig'
RULES = {'keep', 'token', 'fake_company', 'fake_person', 'fake_address',
         'scale_amount', 'shift_date', 'scrub_text', 'drop'}
MIN_PART = 3          # letter / number parts shorter than this stay as they are (P2, ID, v2 ...)
MIN_SCRUB = 4         # shorter values are not searched inside free text
PART_RE = re.compile(r'[A-Za-z]+|[0-9]+')
EMAIL_RE = re.compile(r'[\w.+-]+@[\w-]+\.[\w.-]+')


class Masker:
    def __init__(self, key: str):
        self.key = key.encode()
        self.parts: dict[str, str] = {}         # letter / number part -> mask
        self.names: dict[tuple, str] = {}       # (rule, value) -> fake name
        self.used: set[str] = set()             # masks already given out, so two values never share one
        self.masked: dict[str, str] = {}        # original value -> masked value, for scrub_text
        self.amount_factor = 0.70 + self._int('amount_factor') % 6001 / 10000   # 0.7000-1.3000
        self.date_offset = 30 + self._int('date_offset') % 335                  # 30-364 days back
        self.faker = Faker('fr_FR')

    def _int(self, *parts: str) -> int:
        msg = '\x1f'.join(parts).encode()
        return int.from_bytes(hmac.new(self.key, msg, hashlib.sha256).digest(), 'big')

    def _part(self, part: str) -> str:
        """Same-length mask of a letter-only or digit-only part, case kept, unique per part."""
        if len(part) < MIN_PART:
            return part
        key = part.lower() if part.isalpha() else part
        if key not in self.parts:
            attempt = 0
            while True:
                n = self._int('part', key, str(attempt))
                chars = []
                for ch in part:
                    n, r = divmod(n, 260)
                    if ch.isdigit():
                        chars.append(str(r % 10))
                    else:
                        c = chr(ord('A') + r % 26)
                        chars.append(c if ch.isupper() else c.lower())
                mask = ''.join(chars)
                if mask.lower() != key.lower() and ('p:' + mask.lower()) not in self.used:
                    break
                attempt += 1
            self.parts[key] = mask
            self.used.add('p:' + mask.lower())
        mask = self.parts[key]
        # same part, other casing ('Suez' vs 'SUEZ'): follow the casing of this occurrence
        return ''.join(m.upper() if c.isupper() else m.lower() for c, m in zip(part, mask)) \
            if part.isalpha() else mask

    def token(self, value) -> object:
        if pd.isna(value) or str(value).strip() == '':
            return value
        original = str(value)
        out = PART_RE.sub(lambda m: self._part(m.group()), original)
        self._remember(original, out)
        return out

    def fake(self, value, rule: str) -> object:
        if pd.isna(value) or str(value).strip() == '':
            return value
        original = str(value).strip()
        key = (rule, original.lower())
        if key not in self.names:
            attempt = 0
            while True:
                self.faker.seed_instance(self._int(rule, original.lower(), str(attempt)))
                if rule == 'fake_company':
                    name = self.faker.company()
                elif rule == 'fake_person':
                    name = self.faker.name()
                else:
                    name = f'{self.faker.company()}, {self.faker.street_address()}, ' \
                           f'{self.faker.postcode()} {self.faker.city()}'
                if ('n:' + name.lower()) not in self.used:
                    break
                attempt += 1
            self.names[key] = name
            self.used.add('n:' + name.lower())
        self._remember(original, self.names[key])
        return self.names[key]

    def _remember(self, original: str, masked: str) -> None:
        if len(original.strip()) >= MIN_SCRUB and original != masked:
            self.masked[original.strip()] = masked

    def prepare_scrub(self) -> None:
        # longest first, so a full name is replaced before a shorter value inside it
        items = sorted(self.masked.items(), key=lambda kv: -len(kv[0]))
        self.scrub_patterns = [
            (re.compile(r'(?<![A-Za-z0-9])' + re.escape(o) + r'(?![A-Za-z0-9])', re.IGNORECASE), m)
            for o, m in items]

    def scrub(self, text) -> object:
        if pd.isna(text):
            return text
        out = str(text)
        for pattern, masked in self.scrub_patterns:
            out = pattern.sub(lambda _, v=masked: v, out)
        return EMAIL_RE.sub('[email]', out)


def main() -> int:
    parser = argparse.ArgumentParser(description='Deterministic masking of the split CSVs, rules from the dictionary.')
    parser.add_argument('--dir', required=True, help='Folder with the CSVs and the data dictionary')
    parser.add_argument('--file', default='pulse_sku_kb', help='File stem (default: pulse_sku_kb)')
    parser.add_argument('--out', help='Output folder (default: <dir>\\masked)')
    args = parser.parse_args()

    folder = Path(args.dir)
    dict_file = folder / f'{args.file}_data_dictionary.csv'
    if not dict_file.is_file():
        sys.exit(f'Data dictionary not found: {dict_file}')
    if not config.MASKING_KEY:
        sys.exit('MASKING_KEY is not set: add MASKING_KEY=<long random text> to .env')

    dictionary = pd.read_csv(dict_file, encoding=ENC, dtype=str)
    if 'masking_rule' not in dictionary.columns:
        sys.exit(f'{dict_file.name} has no masking_rule column: add it, one rule per row (empty = keep).')
    dictionary['masking_rule'] = dictionary['masking_rule'].fillna('keep').str.strip().str.lower()
    bad = set(dictionary['masking_rule']) - RULES
    if bad:
        sys.exit(f'Unknown masking_rule value(s): {sorted(bad)}. Allowed: {sorted(RULES)}')
    # a column that appears in several tabs needs one rule, or the link between the tabs breaks
    mixed = dictionary.groupby('column_name')['masking_rule'].nunique()
    if (mixed > 1).any():
        sys.exit(f'Same column with different masking rules across tabs: {list(mixed[mixed > 1].index)}')
    rules = {(r.data_name, r.column_name): r.masking_rule for r in dictionary.itertuples()}

    masker = Masker(config.MASKING_KEY)
    files = sorted(folder.glob(f'{args.file}__*.csv'))
    tables = {f: pd.read_csv(f, encoding=ENC, dtype=str, keep_default_na=False, na_values=['']) for f in files}

    def rule_of(f: Path, col: str) -> str:
        return rules.get((f.stem[len(args.file) + 2:], col), 'keep')   # pulse_sku_kb__quotes -> quotes

    # pass 1: codes and names, so every masked value is known before free text is scrubbed
    for f, df in tables.items():
        for col in df.columns:
            rule = rule_of(f, col)
            if rule == 'token':
                df[col] = df[col].map(masker.token)
            elif rule.startswith('fake_'):
                df[col] = df[col].map(lambda v, r=rule: masker.fake(v, r))
    masker.prepare_scrub()

    # pass 2: amounts, dates, free text, dropped columns
    out_dir = Path(args.out) if args.out else folder / 'masked'
    out_dir.mkdir(parents=True, exist_ok=True)
    for f, df in tables.items():
        for col in list(df.columns):
            rule = rule_of(f, col)
            if rule == 'drop':
                df.drop(columns=col, inplace=True)
            elif rule == 'scale_amount':
                values = pd.to_numeric(df[col], errors='coerce')
                df[col] = (values * masker.amount_factor).round(2).where(values.notna(), df[col])
            elif rule == 'shift_date':
                dates = pd.to_datetime(df[col], errors='coerce')
                shifted = (dates - pd.Timedelta(days=masker.date_offset)).dt.strftime('%Y-%m-%d')
                df[col] = shifted.where(dates.notna(), df[col])
            elif rule == 'scrub_text':
                df[col] = df[col].map(masker.scrub)
        df.to_csv(out_dir / f.name, index=False, encoding=ENC)
        print(f'  {f.name:45} {len(df):>6,} rows')

    # dictionary copy without real sample values / min / max for masked columns
    out_dict = dictionary[dictionary['masking_rule'] != 'drop'].copy()
    out_dict.loc[out_dict['masking_rule'] != 'keep', ['sample_values', 'min', 'max']] = ''
    out_dict.to_csv(out_dir / dict_file.name, index=False, encoding=ENC)
    print(f'\nMasked {len(tables)} file(s) to {out_dir}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
