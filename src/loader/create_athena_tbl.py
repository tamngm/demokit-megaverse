import logging
import os
import re
import sys
import time

import boto3

# allow running this file directly: add src/ to the path so config.py is found
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')

SQL_DIR = os.path.join(os.path.dirname(__file__), 'load_config')


def get_athena_client():
    """Creates the Athena client using config credentials."""
    return boto3.client(
        'athena',
        aws_access_key_id=config.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=config.AWS_SECRET_ACCESS_KEY,
        region_name=config.AWS_REGION
    )


def split_sql(sql_text: str) -> list[str]:
    """Splits a multi-statement SQL file into single statements (drops -- comments)."""
    sql_text = re.sub(r'--.*', '', sql_text)
    return [s.strip() for s in sql_text.split(';') if s.strip()]


def run_athena_query(client, sql: str) -> bool:
    """Runs one statement on Athena and waits until it finishes."""
    resp = client.start_query_execution(
        QueryString=sql,
        QueryExecutionContext={'Database': config.ATHENA_DATABASE},
        ResultConfiguration={'OutputLocation': config.ATHENA_OUTPUT_LOCATION},
        WorkGroup=config.ATHENA_WORKGROUP
    )
    query_id = resp['QueryExecutionId']

    while True:
        status = client.get_query_execution(QueryExecutionId=query_id)['QueryExecution']['Status']
        state = status['State']
        if state == 'SUCCEEDED':
            return True
        if state in ('FAILED', 'CANCELLED'):
            logging.error(f"Query {query_id} {state}: {status.get('StateChangeReason', 'Unknown')}")
            return False
        time.sleep(2)


def create_athena_tbl(sql_filename: str) -> bool:
    """Reads a .sql file and creates every table in it on Athena."""
    with open(sql_filename, encoding='utf-8') as f:
        statements = split_sql(f.read())
    logging.info(f'Read {len(statements)} statements from {sql_filename}')

    client = get_athena_client()
    run_athena_query(client, 'CREATE DATABASE IF NOT EXISTS offybi')

    failed = []
    for sql in statements:
        # pull the table name for logging, e.g. `offybi`.`customer`
        match = re.search(r'TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([`\w.]+)', sql, re.IGNORECASE)
        table_name = match.group(1).replace('`', '') if match else sql[:50]

        if run_athena_query(client, sql):
            logging.info(f'Created: {table_name}')
        else:
            failed.append(table_name)

    if failed:
        logging.error(f'Failed tables: {failed}')
        return False
    logging.info(f'All {len(statements)} tables created.')
    return True


def get_sql_path_from_args() -> str | None:
    """Returns the SQL file path given as CLI arg, or None (with an alert) if missing/not found."""
    if len(sys.argv) < 2:
        logging.error('No SQL file given. Usage: python src/loader/create_athena_tbl.py <file.sql>')
        logging.error(f'Available in {SQL_DIR}: {[f for f in os.listdir(SQL_DIR) if f.endswith(".sql")]}')
        return None

    sql_path = os.path.join(SQL_DIR, sys.argv[1])
    if not os.path.isfile(sql_path):
        logging.error(f'SQL file not found: {sql_path}')
        return None
    return sql_path


def main() -> int:
    sql_path = get_sql_path_from_args()
    if sql_path is None:
        return 1
    return 0 if create_athena_tbl(sql_path) else 1


if __name__ == '__main__':
    sys.exit(main())
