import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile


SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'backup-vscode.sh'


class VSCodeBackupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source' / 'Code'
        self.extensions = self.root / 'extensions'
        self.backups = self.root / 'backups'
        self.log = self.root / 'code.log'
        self.code = self.root / 'code'
        self.code.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
with open(os.environ['TEST_CODE_LOG'], 'a') as f:
    f.write(json.dumps(sys.argv[1:]) + '\\n')
data_root = Path(sys.argv[sys.argv.index('--user-data-dir') + 1])
if any(os.environ.get(k) for k in ('VSCODE_PORTABLE', 'VSCODE_APPDATA', 'VSCODE_IPC_HOOK_CLI')):
    sys.exit(3)
profile_arg = next((a.split('=', 1)[1] for a in sys.argv if a.startswith('--profile=')), None)
if '--profile' in sys.argv or profile_arg is not None:
    profile = profile_arg if profile_arg is not None else sys.argv[sys.argv.index('--profile') + 1]
    storage = data_root / 'User/globalStorage/storage.json'
    if not storage.exists() or profile not in [p['name'] for p in json.loads(storage.read_text()).get('userDataProfiles', [])]:
        sys.exit(2)
if '--list-extensions' in sys.argv and os.environ.get('TEST_FAIL_LIST') == str(data_root):
    sys.exit(1)
if '--list-extensions' in sys.argv:
    print('publisher.work@4.5.6' if ('--profile' in sys.argv or profile_arg is not None) else 'publisher.default@1.2.3')
if '--install-extension' in sys.argv and os.environ.get('TEST_FAIL_EXTENSION') in sys.argv:
    sys.exit(1)
''')
        self.code.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.root / 'home'),
                        VSCODE_CONFIG_DIR=str(self.source), VSCODE_EXTENSIONS_DIR=str(self.extensions),
                        BACKUP_DIR=str(self.backups), CODE_BIN=str(self.code), TEST_CODE_LOG=str(self.log))
        self.write('User/settings.json', '{"editor.fontSize": 13}')
        self.write('User/keybindings.json', '[]')
        self.write('User/tasks.json', '{"tasks": []}')
        self.write('User/snippets/python.json', '{"hello": {}}')
        self.write('User/mcp.json', '{"secret": true}')
        self.write('User/profiles/abc123/settings.json', '{"work": true}')
        self.write('User/profiles/abc123/snippets/work.json', '{}')
        self.write('User/profiles/abc123/mcp.json', '{"secret": true}')
        self.write('User/globalStorage/storage.json', json.dumps({
            'userDataProfiles': [{'location': 'abc123', 'name': 'Work', 'useDefaultFlags': {'tasks': True}}],
            'secret': 'private'}))
        self.extensions.mkdir(parents=True)
        (self.extensions / 'extensions.json').write_text('{"path":"/private/extension"}')

    def write(self, relative, content, root=None):
        path = (root or self.source) / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def run_script(self, *args, input=None, env=None):
        return subprocess.run(['bash', str(SCRIPT), *map(str, args)], input=input, text=True,
                              capture_output=True, env=env or self.env)

    def backup(self):
        result = self.run_script('--zip')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        archives = list(self.backups.glob('*.zip'))
        self.assertEqual(len(archives), 1)
        return archives[0]

    def target_env(self):
        target = self.root / 'target' / 'Code'
        env = dict(self.env, VSCODE_CONFIG_DIR=str(target), VSCODE_EXTENSIONS_DIR=str(self.root / 'target-extensions'))
        return target, env

    def test_backup_contains_only_portable_config_and_profile_metadata(self):
        archive = self.backup()
        with zipfile.ZipFile(archive) as z:
            names = set(z.namelist())
            manifest = json.loads(z.read('manifest.json'))
            self.assertEqual(manifest['format'], 'vscode-config-backup')
            self.assertEqual(manifest['version'], 1)
            profiles = {p['id']: p for p in manifest['profiles']}
            self.assertEqual(profiles['default']['extensions'], ['publisher.default@1.2.3'])
            self.assertIsNone(profiles['default']['name'])
            self.assertEqual(profiles['abc123']['name'], 'Work')
            self.assertEqual(profiles['abc123']['useDefaultFlags'], {'tasks': True})
            self.assertEqual(profiles['abc123']['extensions'], ['publisher.work@4.5.6'])
            self.assertIn('User/settings.json', names)
            self.assertIn('User/profiles/abc123/snippets/work.json', names)
            self.assertFalse(any('mcp.json' in n or 'globalStorage' in n or 'extensions.json' in n for n in names))
            self.assertNotIn(b'private', b''.join(z.read(n) for n in names if not n.endswith('/')))

    def test_restore_registers_profile_and_installs_extensions(self):
        archive = self.backup()
        target, env = self.target_env()
        result = self.run_script('--restore', archive, input='y\n', env=env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        storage = json.loads((target / 'User/globalStorage/storage.json').read_text())
        profile = next(p for p in storage['userDataProfiles'] if p['name'] == 'Work')
        self.assertEqual((target / 'User/profiles' / profile['location'] / 'settings.json').read_text(), '{"work": true}')
        self.assertEqual((target / 'User/settings.json').read_text(), '{"editor.fontSize": 13}')
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertTrue(all('--user-data-dir' in c and c[c.index('--user-data-dir') + 1] in (str(self.source), str(target)) for c in calls))
        self.assertTrue(any('--install-extension' in c and 'publisher.default@1.2.3' in c for c in calls))
        self.assertTrue(any('--install-extension' in c and 'publisher.work@4.5.6' in c and ('Work' in c or '--profile=Work' in c) for c in calls))

    def test_restore_merges_existing_profile_and_creates_safety_backup(self):
        archive = self.backup()
        target, env = self.target_env()
        self.write('User/settings.json', '{"old": true}', target)
        self.write('User/globalStorage/storage.json', json.dumps({'other': 42, 'userDataProfiles': [{'name': 'Work', 'location': 'existing'}]}), target)
        result = self.run_script('--restore', archive, input='y\n', env=env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        storage = json.loads((target / 'User/globalStorage/storage.json').read_text())
        self.assertEqual(storage['other'], 42)
        self.assertEqual(next(p for p in storage['userDataProfiles'] if p['name'] == 'Work')['location'], 'existing')
        self.assertTrue((target / 'User/profiles/existing/settings.json').exists())
        self.assertTrue(list(self.backups.glob('vscode-pre-restore-*.zip')))

    def test_cancel_does_not_mutate_or_install(self):
        archive = self.backup()
        target, env = self.target_env()
        before = self.log.read_text()
        self.run_script('--restore', archive, input='n\n', env=env)
        self.assertFalse(target.exists())
        self.assertEqual(self.log.read_text(), before)

    def test_unsafe_members_rejected_before_changes(self):
        archive = self.backup()
        for member in ('../escape', 'User/mcp.json', 'symlink'):
            with self.subTest(member=member):
                bad = self.root / (member.replace('/', '_') + '.zip')
                with zipfile.ZipFile(archive) as source, zipfile.ZipFile(bad, 'w') as dest:
                    for info in source.infolist():
                        dest.writestr(info, source.read(info.filename))
                    if member == 'symlink':
                        info = zipfile.ZipInfo('User/snippets/link')
                        info.create_system = 3
                        info.external_attr = 0o120777 << 16
                        dest.writestr(info, '/tmp/escape')
                    else:
                        dest.writestr(member, 'bad')
                target, env = self.target_env()
                result = self.run_script('--restore', bad, input='y\n', env=env)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse(target.exists())

    def test_extension_failure_is_reported_after_config_restore(self):
        archive = self.backup()
        target, env = self.target_env()
        env['TEST_FAIL_EXTENSION'] = 'publisher.work@4.5.6'
        result = self.run_script('--restore', archive, input='y\n', env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('publisher.work@4.5.6', result.stdout + result.stderr)
        self.assertTrue((target / 'User/settings.json').exists())

    def test_diff_reports_changes_without_mutation(self):
        archive = self.backup()
        before = (self.source / 'User/settings.json').read_text()
        result = self.run_script('--diff', archive)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.source / 'User/settings.json').read_text(), before)
        self.write('User/settings.json', '{"changed": true}')
        result = self.run_script('--diff', archive)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual((self.source / 'User/settings.json').read_text(), '{"changed": true}')

    def test_missing_arguments_and_help(self):
        for option in ('--restore', '--diff'):
            with self.subTest(option=option):
                self.assertNotEqual(self.run_script(option).returncode, 0)
        self.assertEqual(self.run_script('--help').returncode, 0)
        self.assertEqual(self.run_script('--list').returncode, 0)

    def test_safety_backup_failure_prevents_overwrite(self):
        archive = self.backup()
        target, env = self.target_env()
        self.write('User/settings.json', '{"old": true}', target)
        env['TEST_FAIL_LIST'] = str(target)
        result = self.run_script('--restore', archive, input='y\n', env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((target / 'User/settings.json').read_text(), '{"old": true}')
        self.assertFalse(list(self.backups.glob('vscode-pre-restore-*.zip')))

    def test_inherited_resources_and_existing_excluded_data(self):
        self.write('User/globalStorage/storage.json', json.dumps({'userDataProfiles': [{'location': 'abc123', 'name': 'Work', 'useDefaultFlags': {'settings': True, 'tasks': True, 'extensions': True}}]}))
        archive = self.backup()
        target, env = self.target_env()
        self.write('User/mcp.json', '{"target": true}', target)
        self.write('User/profiles/existing/mcp.json', '{"targetWork": true}', target)
        self.write('User/globalStorage/storage.json', json.dumps({'userDataProfiles': [{'name': 'Work', 'location': 'existing', 'useDefaultFlags': {'mcp': True}}]}), target)
        result = self.run_script('--restore', archive, input='y\n', env=env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        profile = json.loads((target / 'User/globalStorage/storage.json').read_text())['userDataProfiles'][0]
        self.assertEqual(profile['useDefaultFlags'], {'settings': True, 'tasks': True, 'extensions': True, 'mcp': True})
        self.assertEqual((target / 'User/mcp.json').read_text(), '{"target": true}')
        self.assertEqual((target / 'User/profiles/existing/mcp.json').read_text(), '{"targetWork": true}')
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        installs = [c for c in calls if '--install-extension' in c]
        self.assertEqual(len(installs), 1)
        self.assertIn('publisher.default@1.2.3', installs[0])

    def test_diff_matches_profile_by_name_after_restore(self):
        archive = self.backup()
        target, env = self.target_env()
        self.write('User/globalStorage/storage.json', json.dumps({'userDataProfiles': [{'name': 'Work', 'location': 'existing'}]}), target)
        result = self.run_script('--restore', archive, input='y\n', env=env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = self.run_script('--diff', archive, env=env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_corrupt_archive_and_target_symlink_leave_target_unchanged(self):
        archive = self.backup()
        target, env = self.target_env()
        self.write('User/settings.json', '{"old": true}', target)
        corrupt = self.root / 'corrupt.zip'
        corrupt.write_bytes(archive.read_bytes()[:30])
        result = self.run_script('--restore', corrupt, input='y\n', env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((target / 'User/settings.json').read_text(), '{"old": true}')
        outside = self.root / 'outside'
        outside.write_text('untouched')
        (target / 'User/settings.json').unlink()
        (target / 'User/settings.json').symlink_to(outside)
        result = self.run_script('--restore', archive, input='y\n', env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(outside.read_text(), 'untouched')

    def test_cli_environment_is_isolated(self):
        env = dict(self.env, VSCODE_PORTABLE='/foreign', VSCODE_APPDATA='/foreign', VSCODE_IPC_HOOK_CLI='/foreign')
        result = self.run_script('--zip', env=env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        archive = next(self.backups.glob('*.zip'))
        _, target_env = self.target_env()
        target_env.update({k: env[k] for k in ('VSCODE_PORTABLE', 'VSCODE_APPDATA', 'VSCODE_IPC_HOOK_CLI')})
        result = self.run_script('--restore', archive, input='y\n', env=target_env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_dash_leading_profile_is_passed_as_single_option(self):
        name = '--install-extension=evil.extension'
        self.write('User/globalStorage/storage.json', json.dumps({'userDataProfiles': [{'location': 'abc123', 'name': name}]}))
        archive = self.backup()
        _, env = self.target_env()
        result = self.run_script('--restore', archive, input='y\n', env=env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertTrue(any('--profile=' + name in c for c in calls))
        self.assertTrue(all(name not in c for c in calls))

    def test_legacy_mcp_in_jsonc_source_blocks_backup(self):
        for relative in ('User/settings.json', 'User/profiles/abc123/settings.json'):
            with self.subTest(relative=relative):
                original = (self.source / relative).read_text()
                self.write(relative, '{ // legacy\n "\\u006dcp": {"servers": {}},\n }')
                result = self.run_script('--zip')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('mcp', (result.stdout + result.stderr).lower())
                self.assertIn('migra', (result.stdout + result.stderr).lower())
                self.assertFalse(list(self.backups.glob('*.zip')))
                self.write(relative, original)

    def test_legacy_mcp_in_incoming_or_target_settings_blocks_restore(self):
        archive = self.backup()
        bad = self.root / 'inline-mcp.zip'
        with zipfile.ZipFile(archive) as source, zipfile.ZipFile(bad, 'w') as dest:
            for info in source.infolist():
                data = b'{ /* comment */ "\\u006dcp": {}, }' if info.filename == 'User/settings.json' else source.read(info.filename)
                dest.writestr(info, data)
        target, env = self.target_env()
        result = self.run_script('--restore', bad, input='y\n', env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(target.exists())
        legacy = '{ // local\n "\\u006dcp": {}, }'
        self.write('User/settings.json', legacy, target)
        result = self.run_script('--restore', archive, input='y\n', env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((target / 'User/settings.json').read_text(), legacy)
        self.assertFalse(list(self.backups.glob('vscode-pre-restore-*.zip')))

    def test_non_mcp_jsonc_text_roundtrips(self):
        content = '{ // mcp is mentioned\n "text": "mcp", "nested": {"mcp": 1},\n}'
        self.write('User/settings.json', content)
        archive = self.backup()
        target, env = self.target_env()
        result = self.run_script('--restore', archive, input='y\n', env=env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((target / 'User/settings.json').read_text(), content)

    def test_default_and_unknown_arguments(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(list(self.backups.glob('*.zip'))), 1)
        self.assertNotEqual(self.run_script('--unknown').returncode, 0)


if __name__ == '__main__':
    unittest.main()
