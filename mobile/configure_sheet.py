"""Copy only the public meal sheet URL into an ignored Flutter build config."""
import json
from pathlib import Path
from dotenv import dotenv_values

root = Path(__file__).resolve().parent.parent
url = dotenv_values(root / '.env').get('MENU_SHEET_URL', '')
if not url.startswith('https://docs.google.com/spreadsheets/d/'):
    raise SystemExit('Set MENU_SHEET_URL to the Google Sheet share link in .env.')
(root / 'mobile' / 'sheet_config.json').write_text(json.dumps({'MEAL_SHEET_URL': url}) + '\n')
print('Configured the Android app with the meal sheet URL only; no credentials copied.')
