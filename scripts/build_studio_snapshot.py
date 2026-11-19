"""Export the editor as one Studio app, retaining development code as text.

Desktop tests and the separately rooted HTTPS probe are not editor modules.
Keeping their .lua extension in one Studio project makes its analyzer treat
them as app code, incorrectly resolving imports and permissions at editor root.
"""
from pathlib import Path
import argparse
import json
import re
import subprocess
import zipfile

RUNTIME = {
    'index.lua', 'keyboard.lua', 'manifest.json',
    'domain/app.lua', 'domain/buffer.lua', 'domain/documents.lua',
    'domain/layout.lua', 'domain/stats.lua',
    'domain/sync.lua', 'domain/sync_metadata.lua', 'domain/sync_auth.lua',
    'domain/sync_config.lua', 'domain/sync_transport.lua', 'domain/sync_primitives.lua',
    'domain/github_payload.lua', 'domain/sync_session.lua', 'domain/sync_ui.lua',
    'domain/sync_setup.lua', 'domain/sync_setup_ui.lua', 'domain/sync_credentials.lua', 'domain/approval_qr.lua', 'domain/sync_auto.lua', 'domain/sync_review.lua',
}


def cloud_path(name):
    if name in RUNTIME or name == 'README.md' or name.startswith('docs/'):
        return name
    return 'docs/development/' + name + '.txt'


def build(repo, template, archive, stage):
    tracked = subprocess.check_output(['git', 'ls-files'], cwd=repo, text=True).splitlines()
    names = [n for n in tracked if not n.startswith(('assets/', 'artwork/', '.'))]
    # Also include this exporter while preparing an uncommitted repair.
    for name in ('scripts/build_studio_snapshot.py', 'docs/STUDIO-PROJECT-LAYOUT.md'):
        if (repo / name).exists() and name not in names:
            names.append(name)
    contents = {cloud_path(n): (repo / n).read_bytes() for n in names}
    manifest = json.loads(contents['manifest.json'])
    with zipfile.ZipFile(template) as original:
        template_project = json.loads(original.read('xtapp-studio/project.json'))['project']
    manifest['display_name'] = template_project['name']
    contents['manifest.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
    layout = {cloud_path(n): n for n in names if cloud_path(n) != n}
    contents['docs/DEVELOPMENT-SOURCE-MAP.json'] = (json.dumps(layout, indent=2) + '\n').encode()
    # This is a shipping boundary check, not a simulated firmware check.
    active_lua = {n for n in contents if n.endswith('.lua')}
    assert active_lua == RUNTIME - {'manifest.json'}, active_lua
    assert manifest.get('permissions') == ['net']
    for name in active_lua:
        text = contents[name].decode('utf-8')
        if 'ctx.net' in text:
            assert name in {'domain/sync_transport.lua', 'domain/sync_session.lua'}, name
        for module in re.findall(r'require\(["\']([^"\']+)["\']\)', text):
            assert module.replace('.', '/') + '.lua' in active_lua, (name, module)
    assert len(contents) == len(names) + 1, 'cloud path collision'
    with zipfile.ZipFile(template) as original:
        meta = json.loads(original.read('xtapp-studio/project.json'))
        meta['project']['name'] = manifest['display_name']
        meta['project']['manifest'] = manifest
        meta['sourceFiles'] = sorted(contents)
        archive.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as out:
            out.writestr('xtapp-studio/project.json', json.dumps(meta, ensure_ascii=False, indent=2))
            out.writestr('README.md', 'Editor runtime plus development references. See docs/STUDIO-PROJECT-LAYOUT.md.\n')
            for name, data in contents.items():
                out.writestr('project-files/' + name, data)
                target = stage / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
            for name in original.namelist():
                if name.startswith(('assets/', 'presentation/')):
                    out.writestr(name, original.read(name))
                if name.startswith('assets/xic/') and name.endswith('.xic'):
                    target = stage / 'assets' / Path(name).name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(original.read(name))
    print(f'{len(active_lua)} editor Lua files; {len(layout)} non-executable development references; module/permission boundary verified')
    print(archive)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--template', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--stage', type=Path, required=True, help='A new directory for preview; never an existing project')
    args = parser.parse_args()
    if args.stage.exists():
        parser.error('--stage must not exist (prevents stale executable files)')
    build(Path(__file__).resolve().parent.parent, args.template, args.output, args.stage)
