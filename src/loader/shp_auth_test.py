"""Minimal SharePoint read test. Usage: python src/loader/sp_read_test.py raw_data/retail_kit_v3"""
import os, sys
from urllib.parse import urlparse
import msal, requests

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

folder = sys.argv[1] if len(sys.argv) > 1 else ''

# 1. Exchange the secret for a token (Microsoft requires this step)
app = msal.PublicClientApplication(
    config.MS_CLIENT_ID,
    authority=f'https://login.microsoftonline.com/{config.MS_TENANT_ID}',
)
flow = app.initiate_device_flow(scopes=['Sites.Read.All', 'Files.Read.All'])
print(flow['message'])
token = app.acquire_token_by_device_flow(flow)['access_token']
headers = {'Authorization': f'Bearer {token}'}

# 2. Find the site
u = urlparse(config.SP_SITE_URL)
r = requests.get(f'https://graph.microsoft.com/v1.0/sites/{u.netloc}:{u.path}', headers=headers)
print('Site:', r.status_code)
r.raise_for_status()
site_id = r.json()['id']

# 3. List files in the folder
path = f'root:/{folder}:/children' if folder else 'root/children'
r = requests.get(f'https://graph.microsoft.com/v1.0/sites/{site_id}/drive/{path}', headers=headers)
r.raise_for_status()
for item in r.json()['value']:
    print(item['name'])