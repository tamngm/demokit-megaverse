"""
One-off load: copy CSV files from a SharePoint folder to S3 as Parquet.
Each file goes to s3://<bucket>/<s3-prefix>/<file_stem>/<file_stem>.parquet (one folder = one Athena table).

Expectation output in S3 from sharepoint
transactions_2025-03-14.csv → retail_fashion/transactions/business_date=2025-03-14/transactions_2025-03-14.parquet
customers.csv               → retail_fashion/customers/customers.parquet          (unchanged)

Usage:
  python src/loader/convert_csv_to_parquet.py --sp-folder "raw_data/retail_kit_v3" --s3-prefix data/offybi/retail_fashion --dry-run
"""
import argparse
import io
import os
import re
import sys
from urllib.parse import urlparse

import boto3
import msal
import pyarrow.csv as pv
import pyarrow.parquet as pq
import requests

# allow running this file directly: add src/ to the path so config.py is found
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

GRAPH = 'https://graph.microsoft.com/v1.0'
SCOPES = ['Sites.Read.All', 'Files.Read.All']
_app = None


def get_graph_token() -> str:
    """Device-code sign-in on the first call: prints a link + code, you sign in in the browser.
    Later calls reuse the cached token and refresh it silently, so long runs outlive the ~1h token."""
    global _app
    if _app is None:
        _app = msal.PublicClientApplication(
            config.MS_CLIENT_ID,
            authority=f'https://login.microsoftonline.com/{config.MS_TENANT_ID}',
        )
    accounts = _app.get_accounts()
    if accounts:
        result = _app.acquire_token_silent(SCOPES, account=accounts[0])
        if result and 'access_token' in result:
            return result['access_token']
    flow = _app.initiate_device_flow(scopes=SCOPES)
    print(flow['message'])
    result = _app.acquire_token_by_device_flow(flow)
    if 'access_token' not in result:
        raise RuntimeError(f"{result.get('error')}: {result.get('error_description')}")
    return result['access_token']


def graph_get(token: str, url: str) -> requests.Response:
    resp = requests.get(url, headers={'Authorization': f'Bearer {token}'}, timeout=300)
    resp.raise_for_status()
    return resp


def snake_case(name: str) -> str:
    """'Invoice ID' -> 'invoice_id'"""
    return re.sub(r'[^0-9a-zA-Z]+', '_', name).strip('_').lower()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--sp-folder', required=True)
    parser.add_argument('--s3-prefix', required=True)
    parser.add_argument('--dry-run', action='store_true') # list the files missing in S3, upload nothing
    args = parser.parse_args()

    token = get_graph_token()
    u = urlparse(config.SP_SITE_URL)
    site_id = graph_get(token, f'{GRAPH}/sites/{u.netloc}:{u.path.rstrip("/")}').json()['id']
    url = f'{GRAPH}/sites/{site_id}/drive/root:/{args.sp_folder}:/children'
    items = []
    while url:
        page = graph_get(token, url).json()
        items += page['value']
        url = page.get('@odata.nextLink')
    print(f'Found {len(items)} items')
    csv_files = [i for i in items if i['name'].lower().endswith('.csv')]

    s3 = boto3.client(
        's3',
        aws_access_key_id=config.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=config.AWS_SECRET_ACCESS_KEY,
        region_name=config.AWS_REGION
    )
    # keys already in S3: skipped, so a re-run only uploads what is missing
    prefix = args.s3_prefix.strip('/')
    existing = set()
    for page in s3.get_paginator('list_objects_v2').paginate(Bucket=config.S3_BUCKET_NAME, Prefix=prefix + '/'):
        existing.update(o['Key'] for o in page.get('Contents', []))

    missing, failed = 0, []
    for item in csv_files:
        name = os.path.splitext(item['name'])[0]
        daily = re.match(r'(.+)_(\d{4}-\d{2}-\d{2})$', name)        # for transactions_2025-03-14
        if daily:
            stem = snake_case(daily[1])
            key = f'{prefix}/{stem}/{daily[2]}/{stem}_{daily[2]}.parquet'
        else:
            stem = snake_case(name)
            key = f'{prefix}/{stem}/{stem}.parquet'
        if key in existing:
            continue
        missing += 1
        print(f'{item["name"]} -> s3://{config.S3_BUCKET_NAME}/{key}')
        if args.dry_run:
            continue

        try:
            csv_bytes = graph_get(get_graph_token(), f'{GRAPH}/sites/{site_id}/drive/items/{item["id"]}/content').content
            table = pv.read_csv(io.BytesIO(csv_bytes))
            table = table.rename_columns([snake_case(c) for c in table.column_names])

            buf = io.BytesIO()
            pq.write_table(table, buf)
            s3.put_object(Bucket=config.S3_BUCKET_NAME, Key=key, Body=buf.getvalue())
            print(f'  uploaded {table.num_rows:,} rows')
        except Exception as e:  # one bad file must not stop the run
            failed.append(item['name'])
            print(f'  FAILED: {e}')

    print(f'\n{len(csv_files)} csv files, {len(csv_files) - missing} already in S3, {missing} missing'
          + ('' if args.dry_run else f', {missing - len(failed)} uploaded, {len(failed)} failed'))
    for name in failed:
        print(f'  failed: {name}')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
