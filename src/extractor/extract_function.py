import pandas as pd
from src.logging_history import logger 

import kagglehub
import os


# print(S3_BUCKET, AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)


def extract_data_from_kaggle(kaggle_dataset_name):
    # this script is used for Kaggle source
    # it first stores temporararily in local device
    try:
        pathkaggle = kagglehub.dataset_download(kaggle_dataset_name)
        
        logger.info("Path to dataset files:", pathkaggle)
        file_name = kaggle_dataset_name
        #
        #  find CSV files
        files = [f for f in os.listdir(pathkaggle) if f.endswith('.csv')]
        if not files:
            raise FileNotFoundError(f"No .csv files found in {pathkaggle}")
        
        # # Pick the first CSV (or add logic to pick by size/name)
        target_file = os.path.join(pathkaggle, files[0])
        logger.info(f'First file in path: {target_file}')
        # local_path = os.path.join(pathkaggle, f"{file_name}.csv")

        # file_path = os.path.join(pathkaggle, file_name_ext)
        logger.info(f'File extracted to: {pathkaggle}')
        # logger.info(f'Data temporarily located at: {local_path}')

        logger.info('Successful extract raw file to local temporary storage.')


    except Exception as e:
        # exc_info=True adds the full stack trace (the red error text) to the log
        logger.error(f"Unexpected error during extraction: {e}", exc_info=True)
        raise
    return target_file


# if __name__ == '__main__':
#     csv_file_path = extract_data_from_kaggle()
#     s3_file_name = 'cosmetic_product_reviews_raw'
#     load_data_to_s3(csv_file_path, config.S3_BUCKET_PRODUCT_REVIEW_PATH, s3_file_name)
