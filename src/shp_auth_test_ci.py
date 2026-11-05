"""SharePoint app-only auth test (Sites.Selected). Reads settings from environment variables.
Local:  set vars in .env (or shell), then: python sp_auth_test.py
GitHub: runs in .github/workflows/sp_auth_test.yml
"""
import os
from urllib.parse import urlparse

import msal
import requests

try:
    from dotenv import load_dotenv
    load_dotenv()  # local only; in GitHub Actions the vars come from secrets
except ImportError:
    pass

tenant = os.environ['MS_TENANT_ID']
client_id = os.environ['MS_CLIENT_ID']
secret = os.environ['MS_CLIENT_SECRET']
site_url = os.environ['SP_SITE_URL']

# 1. Sign in with the secret
app = msal.ConfidentialClientApplication(
    client_id, authority=f'https://login.microsoftonline.com/{tenant}', client_credential=secret
)
result = app.acquire_token_for_client(scopes=['https://graph.microsoft.com/.default'])
if 'access_token' not in result:
    raise SystemExit(f'FAIL sign-in: {result.get("error_description")}')
headers = {'Authorization': f'Bearer {result["access_token"]}'}
print('OK   sign-in')

# 2. Open the site
u = urlparse(site_url)
r = requests.get(f'https://graph.microsoft.com/v1.0/sites/{u.netloc}:{u.path.rstrip("/")}', headers=headers)
if r.status_code != 200:
    raise SystemExit(f'FAIL site access: {r.status_code} {r.text[:200]}')
site_id = r.json()['id']
print(f'OK   site: {r.json()["displayName"]}')

# 3. List files in the Documents library root
r = requests.get(f'https://graph.microsoft.com/v1.0/sites/{site_id}/drive/root/children', headers=headers)
if r.status_code != 200:
    raise SystemExit(f'FAIL list files: {r.status_code} {r.text[:200]}')
print('OK   files:')
for item in r.json()['value']:
    print('     -', item['name'])

# 4. List folders inside raw_data
folder = os.environ.get('SP_FOLDER', 'raw_data')
r = requests.get(f'https://graph.microsoft.com/v1.0/sites/{site_id}/drive/root:/{folder}:/children', headers=headers)
if r.status_code != 200:
    raise SystemExit(f'FAIL list {folder}: {r.status_code} {r.text[:200]}')
folders = [i['name'] for i in r.json()['value'] if 'folder' in i]
print(f'OK   {len(folders)} folder(s) in {folder}:')
for name in sorted(folders):
    print('     -', name)