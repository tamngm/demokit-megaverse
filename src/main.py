from logging_history import logger
from extractor.extract_function import extract_data_from_kaggle
from loader.load_function import get_data_from_local, save_data_to_local, push_df_to_s3

import config
import pandas as pd
from transfomator import transform_zara_product_price

def run_pipeline():
    # kaggle_dataset_name = "jithinanievarghese/cosmetics-and-beauty-products-reviews-top-brands"
    kaggle_dataset_name = "marixe/zara-sales-for-eda"
    # logger.info("Main script started")

    # ------ EXTRACT & LOAD RAW TO S3
    # file_path = extract_data_from_kaggle(kaggle_dataset_name)
    # print(file_path)
    ## you can copy the file_path local in history_log after running data extraction
    file_path = r'C:\Users\minhtam.nguyen\.cache\kagglehub\datasets\marixe\zara-sales-for-eda\versions\5\Zara_sales_EDA.csv'
    # s3_file_name_raw = 'data/marixe_zara_product_sales/raw/zara_product_sales_raw.parquet'
    # push_data_to_s3(file_path, s3_file_name_raw)

    # ------ GET RAW FROM THE S3
    # s3_bucket_path = ''
    # df = get_raw_from_s3(s3_file_name_raw) #when you need to get raw from s3
    # df = pd.read_csv('data/raw/nyka_top_brands_cosmetics_product_reviews.csv')

    # ------ GET RAW FROM LOCAL TO TRANSFORM
    dfraw = get_data_from_local(file_path)

    # ----- CLEAN RAW READY FOR DEEP TRANSFORM WITH DBT
    dffmt = transform_zara_product_price.clean_data(dfraw, test=False, dataname="zara_product_sales_stg")
    
    # ----- UPLOAD FORMATTED DATA TO S3 (after formatted data good to go)
    push_df_to_s3(dffmt, "data/marixe_zara_product_sales/staging/zara_product_sales_stg.parquet")

    # ----- CLEAN RAW
    
    # temporarily store in local
    # dftransformed.to_csv('data/processed/cosmetics_product_reviews_cleaned.csv', mode='w', index=False)
    # dftransformed = pd.read_csv('data/processed/cosmetics_product_reviews_cleaned.csv')
    # s3_file_name_cleaned = 'cosmetics_product_reviews_cleaned.parquet'
    # file_path_proccesed = 'data/processed/cosmetics_product_reviews_cleaned.csv'
    # load_data_to_s3(file_path_proccesed, s3_file_name_cleaned)
    # print(dftransformed.shape)

    # ------ CATEGORIZE THE PRODUCT
    # dfproduct = pd.read_csv('data/raw/product_master_data.csv')
    # Create the object
    # product_processor = product_classifier(dfproduct, 'product_title')

    # # Call the method
    # product_processor.get_unique()
    # dfproduct_res = product_processor.run_categorization()
    # dfproduct_res.to_csv('data/processed/product_master_data_categorized.csv', mode='w', index=False)
    
    # upload product master data to S3
    # dfproductraw = pd.read_csv('data/raw/product_master_data.csv')
    # s3_file_name_raw = 'product_master_data_raw.parquet'
    # file_path_raw = 'data/raw/product_master_data_raw.csv'
    # push_data_to_s3(file_path_raw, s3_file_name_raw)

    # s3_file_name_categorized = 'product_master_data_categorized.parquet'
    # file_path_categorized = 'data/processed/product_master_data_categorized.csv'
    # push_data_to_s3(file_path_categorized, s3_file_name_categorized)

# def sales_pipeline():
#     kaggle_dataset_name = "jithinanievarghese/cosmetics-and-beauty-products-reviews-top-brands"
#     logger.info("Main script started")

#     # ------ EXTRACT & LOAD RAW TO S3
#     # file_path = extract_data_from_kaggle(kaggle_dataset_name)
#     s3_file_name_raw = 'cosmetic_product_reviews_raw.parquet'
#     # load_data_to_s3(file_path, s3_file_name_raw)
    
if __name__ == '__main__':
    run_pipeline()