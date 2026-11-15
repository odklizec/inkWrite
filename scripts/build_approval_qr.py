"""Generate static, offline GitHub approval QR data. Requires qrcode 8.2."""
from pathlib import Path
import qrcode
URL='https://github.com/login/device'
qr=qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M,box_size=6,border=4)
qr.add_data(URL);qr.make(fit=True)
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
text+='return {url='+repr(URL)+',size='+str(len(matrix))+',rects={\n'
text+=''.join('  {'+','.join(map(str,r))+'},\n'for r in rects)+'}}\n'
(Path(__file__).resolve().parent.parent/'domain/approval_qr.lua').write_text(text,encoding='utf-8')
if __name__=='__main__':print(f'{len(matrix)} modules with quiet zone; {len(rects)} merged black runs')
