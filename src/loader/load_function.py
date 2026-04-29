import pandas as pd
from logging_history import logger 
import os
import boto3
import config
import io
import pyarrow.csv as pv
import pyarrow.parquet as pq

# logger = logger.getLogger(__name__)

def get_s3_client():
    """Creates the S3 client using config credentials."""
    return boto3.client(
        's3',
        aws_access_key_id=config.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=config.AWS_SECRET_ACCESS_KEY,
        region_name=config.AWS_REGION
    )

def get_data_from_s3(s3_key):
    """
    Downloads a PARQUET file from S3 and returns a DataFrame.
    s3_key: the full path inside the bucket (e.g. 'processed/sales.parquet')
    s3_bucket: my-bucket
    s3_key: data/raw/sales.parquet - is actually the file path with file name in S3

    """
    logger.info(f"Fetching Parquet file from S3: {s3_key}")
    try:
        s3_client = get_s3_client()
        response = s3_client.get_object(Bucket=config.S3_BUCKET_NAME, Key=s3_key)
        
        # We read the 'Body' and wrap it in BytesIO
        # engine='pyarrow' is fast and handles complex schemas well
        df = pd.read_parquet(io.BytesIO(response['Body'].read()), engine='pyarrow')
        
        logger.info(f"Successfully downloaded and parsed {s3_key}")
        return df
        
    except Exception as e:
        logger.error(f"Failed to get Parquet file from S3. Error: {e}", exc_info=True)
        return None

# GET FROM LOCAL
def get_data_from_local(local_path):
    """Reads local Parquet -> DataFrame."""
    try:
        if not os.path.exists(local_path):
            logger.warning(f"File not found: {local_path}")
            return None
        # df = pd.read_parquet(local_path, engine='pyarrow')
        df = pd.read_csv(local_path, encoding='utf-8')
        logger.info(f"Local -> DF: {local_path} successful.")
        return df
    except Exception as e:
        logger.error(f"Failed local read: {e}", exc_info=True)
        return None

# SAVE TO LOCAL
def save_data_to_local(df, local_path):
    """Saves DataFrame -> local Parquet file."""
    try:
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        df.to_parquet(local_path, index=False, engine='pyarrow')
        logger.info(f"DF -> Local: {local_path} saved.")
        return True
    except Exception as e:
        logger.error(f"Failed local save: {e}", exc_info=True)
        return False

# PUSH TO S3
def push_data_to_s3(local_path, s3_key):
    """Uploads an existing local file -> S3."""
    logger.info(f'S3 BUCKET NAME is {config.S3_BUCKET_NAME}')
    try:
        s3_client = get_s3_client()
        s3_client.upload_file(local_path, config.S3_BUCKET_NAME, s3_key)
        
        logger.info(f"Local -> S3: {s3_key} upload successful.")
        return True
    except Exception as e:
        logger.error(f"Failed S3 upload: {e}", exc_info=True)
        return False

# if __name__ == "__main__":
    # path_to_file = config.S3_BUCKET_NAME + "my_data.parquet"
    # df = get_data_from_s3(path_to_file)
    # print(config.S3_BUCKET_NAME)
