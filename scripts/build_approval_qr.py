"""Generate static QR data for GitHub approval or the illustrated guide. Requires qrcode 8.2."""
import argparse
from pathlib import Path
import qrcode

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--guide-url', help='Public HTTPS URL of the illustrated setup guide')
args = parser.parse_args()
url = args.guide_url or 'https://github.com/login/device'
if not url.startswith('https://') or not url.isascii() or any(c.isspace() for c in url):
    parser.error('Use an ASCII HTTPS URL without whitespace.')
output = 'github_guide_qr.lua' if args.guide_url else 'approval_qr.lua'
qr=qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M,box_size=6,border=4)
qr.add_data(url);qr.make(fit=True)
matrix=qr.get_matrix();rects=[]
for y,row in enumerate(matrix):
    x=0
    while x<len(row):
        if not row[x]:x+=1;continue
        start=x
        while x<len(row)and row[x]:x+=1
        rects.append((start,y,x-start))
assert len(rects)<512
text='-- Generated offline by scripts/build_approval_qr.py; public URL only.\n'
text+='return {url='+repr(url)+',size='+str(len(matrix))+',rects={\n'
text+=''.join('  {'+','.join(map(str,r))+'},\n'for r in rects)+'}}\n'
(Path(__file__).resolve().parent.parent/'domain'/output).write_text(text,encoding='utf-8',newline='\n')
if __name__=='__main__':print(f'{len(matrix)} modules with quiet zone; {len(rects)} merged black runs')
