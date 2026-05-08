import pandas as pd
from logging_history import logger 
import os
# import boto3
import config
import io
import pyarrow.csv as pv
import pyarrow.parquet as pq

def clean_data(df, test: bool, dataname:str):
    try:
        logger.info(f'shape of the data {df.shape}')
        dfshape = df.shape
        num_col = df.select_dtypes(include='number').columns
        obj_col = df.select_dtypes(include='object').columns
        logger.info(f'numeric cols: {num_col}')
        logger.info(f'object cols: {obj_col}')

        df['sales'] = df['Sales Volume'] * df['price']
        num_col = ['Sales Volume', 'price', 'sales']
        obj_col = ['Product Position', 'Promotion', 'Seasonal', 'terms', 'section', 'season', 'material']
        
        # drop n/a
        df.dropna(inplace=True)

        # standardize column names
        df.rename(columns={
            "Product ID":"product_id",
            "Product Position":"product_position",
            "Promotion":"promotion",
            "Product Category":"product_category",
            "Seasonal":"seasonal",
            "Sales Volume":"sales_volume",
            "brand":"brand",
            "url":"url",
            "name":"name",
            "description":"description",
            "price":"price",
            "currency":"currency",
            "terms":"terms",
            "section":"section",
            "season":"season",
            "material":"material",
            "origin":"origin"
            }, inplace=True)

        # enforce data schema
        standard_schema = {
            "product_id": "string",
            "product_position": "string",
            "promotion": "bool",
            "product_category": "string",
            "seasonal": "string",
            "sales_volume": "int64",
            "brand": "string",
            "url": "string",
            "name": "string",
            "description": "string",
            "price": "float64",
            "currency": "string",
            "sales": "float64",
            "terms": "string",
            "section": "string",
            "season": "string",
            "material": "string",
            "origin": "string"
        }

        for col, dtype in standard_schema.items():
            if col in df.columns:
                df[col] = df[col].astype(dtype)
        
        # test first to see if it works
        if test:
            tempo_local_path = f'data/processed/{dataname}.csv'
            df.to_csv(tempo_local_path, index=False)
            logger.info('Successful test. Dataframe extracted to tempo_local_path ')
        else:
            return df
        
    except Exception as e:
        # exc_info=True adds the full stack trace (the red error text) to the log
        logger.error(f"Unexpected error during transformation: {e}", exc_info=True)
        raise
    return False
