#!/usr/bin/env python3
"""RecallDiscord for a release on the fork, in two steps that run on separate machines.

build: the engine from Recall's official release of the same version and the app from this checkout, unsigned.
package: signs a finished app with the fork's certificate and makes the DMG. It runs no code from the merge, which
is why it reads the entitlements build wrote instead of importing them.
"""
import argparse
import hashlib
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

NAME = 'RecallDiscord'
UPSTREAM = 'AsherJN/recall'


def run(*args, **options):
    print('+', ' '.join(str(a) for a in args), flush=True)
    return subprocess.run([str(a) for a in args], check=True, **options)


def sha256(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as file:
        for chunk in iter(lambda: file.read(1 << 22), b''):
            digest.update(chunk)
    return digest.hexdigest()


def fetch_engine(tag, target):
    """The engine inside Recall's official DMG, checked against its published SHA-256."""
    with tempfile.TemporaryDirectory() as folder:
        run('gh', 'release', 'download', tag, '--repo', UPSTREAM, '--pattern', 'Recall-*', '--dir', folder)
        image = next(Path(folder).glob('*.dmg'))
        if sha256(image) != image.with_name(image.name+'.sha256').read_text().split()[0]:
            raise SystemExit(f'{image.name} does not match its published SHA-256')
        mount = Path(folder)/'mount'
        mount.mkdir()
        run('hdiutil', 'attach', '-nobrowse', '-readonly', '-noautoopen', '-mountpoint', mount, image)
        try:
            shutil.copy2(mount/'Recall.app/Contents/Resources/runtime.tar.gz', target)
        finally:
            run('hdiutil', 'detach', mount, '-force')


def build(args):
    sys.path.insert(0, str(ROOT/'scripts'))
    from build_native_app import ENTITLEMENTS
    engine = args.runtime_archive or ROOT/'runtime/runtime.tar.gz'
    if not args.runtime_archive:
        engine.parent.mkdir(exist_ok=True)
        fetch_engine(args.tag, engine)
    workspace = ROOT/'runtime/dxmt'
    if not (workspace/'dxmt-source').exists():
        run(sys.executable, ROOT/'scripts/build_portable_dxmt.py', '--workspace', workspace, '--source-only')
    shutil.rmtree(args.output, ignore_errors=True)
    args.output.mkdir(parents=True)
    run(sys.executable, ROOT/'scripts/build_native_app.py', '--output', args.output/'Recall.app', '--workspace', workspace, '--runtime-archive', engine)
    app = args.output/f'{NAME}.app'
    (args.output/'Recall.app').rename(app)
    info_path = app/'Contents/Info.plist'
    info = plistlib.loads(info_path.read_bytes())
    info.update(CFBundleName=NAME, CFBundleDisplayName=NAME, CFBundleShortVersionString=args.version)
    info_path.write_bytes(plistlib.dumps(info))
    (args.output/'app.entitlements').write_bytes(plistlib.dumps(ENTITLEMENTS))


def package(args):
    app = args.folder/f'{NAME}.app'
    if plistlib.loads((app/'Contents/Info.plist').read_bytes())['CFBundleShortVersionString'] != args.version:
        raise SystemExit(f'{app} is not version {args.version}')
    base = ['codesign', '--force', '--timestamp=none', '--sign', args.identity]+(['--keychain', args.keychain] if args.keychain else [])
    for item in ('ow2-setup', 'ow2-pipeline', 'libpipeline_prepare.dylib', 'pipeline-prepare', 'pipeline-warm', 'Rosetta Check.app'):
        run(*base, app/'Contents/Helpers'/item)
    run(*base, '--entitlements', args.folder/'app.entitlements', app)
    run('codesign', '--verify', '--deep', '--strict', app)
    with tempfile.TemporaryDirectory() as folder:
        stage = Path(folder)/'stage'
        stage.mkdir()
        run('ditto', app, stage/app.name)
        os.symlink('/Applications', stage/'Applications')
        image = args.folder/f'{NAME}-{args.version}.dmg'
        run('hdiutil', 'create', '-quiet', '-volname', NAME, '-fs', 'HFS+', '-format', 'UDZO', '-srcfolder', stage, image)
    image.with_name(image.name+'.sha256').write_text(f'{sha256(image)}  {image.name}\n')
    print(image)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    steps = parser.add_subparsers(dest='step', required=True)
    first = steps.add_parser('build')
    first.add_argument('--tag', required=True, help="Recall's release, such as v1.6.3")
    first.add_argument('--version', required=True, help='such as 1.6.3-discord')
    first.add_argument('--runtime-archive', type=Path, help='use this engine instead of fetching it')
    first.add_argument('--output', type=Path, default=ROOT/'runtime/build/fork')
    second = steps.add_parser('package')
    second.add_argument('--folder', type=Path, required=True, help="build's output")
    second.add_argument('--version', required=True)
    second.add_argument('--identity', default='-', help="the certificate's SHA-1; - signs ad hoc, for a local try")
    second.add_argument('--keychain')
    args = parser.parse_args()
    (build if args.step == 'build' else package)(args)


if __name__ == '__main__':
    main()
