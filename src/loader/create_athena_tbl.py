
import logging
import boto3
import config
import time

def get_athena_client():
    """Creates the S3 client using config credentials."""
    return boto3.client(
        'athena',
        aws_access_key_id=config.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=config.AWS_SECRET_ACCESS_KEY,
        region_name=config.AWS_REGION
    )


def create_athena_tbl_(sql_filename: str, table_name: str):

    try:
        client = get_athena_client()
        
        # read the sql file
        sql = open(sql_filename, encoding='utf-8', errors='ignore').read().strip()
        logging.info(f'Success: Reading SQL.')
        print(f"ATHENA_WORKGROUP: '{config.ATHENA_WORKGROUP}'")
        print(f"AWS_REGION: '{config.AWS_REGION}'")
        print(f"Output location repr: { repr(config.ATHENA_OUTPUT_LOCATION)} ")  # shows hidden chars

        # Start query
        resp = client.start_query_execution(
            QueryString= sql,
            QueryExecutionContext={"Database":config.ATHENA_DATABASE},
            ResultConfiguration={"OutputLocation":config.ATHENA_OUTPUT_LOCATION},
            WorkGroup=config.ATHENA_WORKGROUP
        )

        query_id = resp["QueryExecutionId"]
        
        logging.info(f"🚀 Started: {table_name} | Query ID: {query_id}")
        
        # Wait for completion
        while True:
            status = client.get_query_execution(QueryExecutionId= query_id)
            state = status['QueryExecution']['Status']['State']

            if state == 'SUCCEEDED':
                logging.info(f"Success: Created {table_name}.")
                break
            if state in ["FAILED", "CANCELLED"]:
                reason = status["QueryExecution"]["Status"].get("StateChangeReason", "Unknown")
                print(f"❌ Failed: {reason}")
                break
            
            time.sleep(2)  # simple wait
    except Exception as e:
        logging.debug(f"Failed create Athena table from S3: {e}", exc_info=True) 
        print('Failed create Athena table from S3!')
        return None

    

