# src/config.py
import os
from dotenv import load_dotenv
from pathlib import Path

# 1. LOAD THE SECRETS (Do this once at the top)
load_dotenv() 

# 2. GET THE VARIABLES
# os.getenv looks in the memory where load_dotenv put them
# Find and load the .env file
# load_dotenv()

# Assign variables
AWS_ACCESS_KEY_ID = os.getenv('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')
AWS_REGION = os.getenv('AWS_REGION')
S3_BUCKET_NAME = os.getenv('S3_BUCKET_NAME')
S3_BUCKET_PRODUCT_REVIEW_PATH = os.getenv('S3_BUCKET_PRODUCT_REVIEW_PATH')

# print(AWS_ACCESS_KEY_ID)