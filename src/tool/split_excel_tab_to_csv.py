"""
Split every tab of an Excel file into one CSV per tab, plus one data dictionary CSV for all tabs.
Output goes to the same folder as the Excel file:
  <file>__<tab>.csv                the tab's data, column names in snake_case
  <file>_data_dictionary.csv       one row per tab x column: data_name (tab), type, nulls, distinct count,
                                   min/max, samples, description

Usage:
  .venv\\Scripts\\python.exe src\\tool\\split_excel_tab_to_csv.py --dir "<folder>" [--file pulse_sku_kb.xlsx]
"""
import argparse
import re
import sys
import unicodedata
from pathlib import Path

import pandas as pd


def snake_case(name: str) -> str:
    """'SKU List / 2025' -> 'sku_list_2025'; accents removed ('Mã SP' -> 'ma_sp')."""
    text = unicodedata.normalize('NFKD', str(name)).replace('đ', 'd').replace('Đ', 'D')
    text = text.encode('ascii', 'ignore').decode()
    return re.sub(r'[^0-9a-zA-Z]+', '_', text).strip('_').lower() or 'unnamed'


def unique_names(names: list[str]) -> list[str]:
    """Adds _2, _3 ... to repeated names so every column stays distinct."""
    seen: dict[str, int] = {}
    result = []
    for n in names:
        seen[n] = seen.get(n, 0) + 1
        result.append(n if seen[n] == 1 else f'{n}_{seen[n]}')
    return result


def data_dictionary(df: pd.DataFrame, original_headers: list[str], data_name: str) -> list[dict]:
    rows = []
    total = len(df)
    for col, header in zip(df.columns, original_headers):
        s = df[col]
        non_null = s.dropna()
        is_minmax = pd.api.types.is_numeric_dtype(s) or pd.api.types.is_datetime64_any_dtype(s)
        rows.append({
            'data_name': snake_case(data_name),
            'column_name': col,
            'original_header': header,
            'data_type': str(s.dtype),
            'non_null_count': len(non_null),
            'null_count': total - len(non_null),
            'null_pct': round((total - len(non_null)) / total * 100, 2) if total else 0,
            'distinct_count': non_null.nunique(),
            'min': non_null.min() if is_minmax and len(non_null) else '',
            'max': non_null.max() if is_minmax and len(non_null) else '',
            'sample_values': ' | '.join(str(v) for v in non_null.drop_duplicates().head(3)),
            'description': '',
        })
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description='Split each Excel tab into a CSV, plus one data dictionary CSV.')
    parser.add_argument('--dir', required=True, help='Folder that holds the Excel file; CSVs are written here')
    parser.add_argument('--file', default='file_name_example.xlsx', help='Excel file name with suffix .xlsx')
    args = parser.parse_args()

    folder = Path(args.dir)
    excel_path = folder / args.file
    if not excel_path.is_file():
        print(f'Excel file not found: {excel_path}')
        return 1

    stem = snake_case(excel_path.stem)
    sheets = pd.read_excel(excel_path, sheet_name=None)  # {tab name: DataFrame}
    print(f'Read {len(sheets)} tab(s) from {excel_path.name}\n')

    used_tab_names: set[str] = set()
    dictionary_rows: list[dict] = []
    for tab, df in sheets.items():
        df = df.dropna(how='all').dropna(axis=1, how='all')  # drop fully empty rows and columns
        if df.empty:
            print(f'  skipped (empty): {tab}')
            continue

        tab_name = snake_case(tab)
        while tab_name in used_tab_names:  # two tabs that clean to the same name
            tab_name += '_x'
        used_tab_names.add(tab_name)

        original_headers = [str(c) for c in df.columns]
        df.columns = unique_names([snake_case(c) for c in original_headers])

        data_file = folder / f'{stem}__{tab_name}.csv'
        # utf-8-sig: Excel opens it with Vietnamese characters intact
        df.to_csv(data_file, index=False, encoding='utf-8-sig')
        dictionary_rows += data_dictionary(df, original_headers, tab)
        print(f'  {tab!r:40} -> {data_file.name} ({len(df):,} rows x {len(df.columns)} cols)')

    # one dictionary for all tabs: one row per tab x column
    dict_file = folder / f'{stem}_data_dictionary.csv'
    pd.DataFrame(dictionary_rows).to_csv(dict_file, index=False, encoding='utf-8-sig')
    print(f'\nData dictionary: {dict_file.name} ({len(dictionary_rows)} columns)')
    print('Done.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
