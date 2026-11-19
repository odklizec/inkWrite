"""Build a separate sign-in diagnostic with explicit source dependencies."""
from pathlib import Path
import argparse,json,re
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);a=p.parse_args()
if a.stage.exists():p.error('stage must not exist')
repo=Path(__file__).resolve().parent.parent
files={'manifest.json':'tools/github-auth-check/manifest.json',
 'index.lua':'tools/github-auth-check/index.lua','auth_check.lua':'tools/github-auth-check/auth_check.lua'}
for name in ('sync_auth','sync_credentials','sync_transport','sync_primitives','sync_config','sync','github_payload','buffer','documents'):
 files['domain/'+name+'.lua']='domain/'+name+'.lua'
for target,source in files.items():
 data=(repo/source).read_bytes();dest=a.stage/target;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
 if target.endswith('.lua'):
  for module in re.findall(r'require\([\'"]([^\'"]+)[\'"]\)',data.decode()):
   assert module.replace('.','/')+'.lua' in files,(target,module)
manifest=json.loads((a.stage/'manifest.json').read_text())
assert manifest['app_id']=='inkwrite.githubauthcheck'and manifest['permissions']==['net']
print(str(a.stage.resolve()));print(len(files)-1,'Lua files; separate app identity and require closure verified')
