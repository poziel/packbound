import json
import os
import sys
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path
import run_tests as runner

class RunnerTests(unittest.TestCase):

    def setUp(self):
        base = Path(__file__).resolve().parents[2] / 'workspace/tasks/test-runner-self-tests'
        base.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=base)
        self.root = Path(self.temp.name)
        (self.root / 'tests').mkdir()
        (self.root / 'components').mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def test_timeout(self):
        code, out, err, expired = runner.run_process([sys.executable, '-c', 'import time;time.sleep(30)'], os.environ.copy(), 0.1, self.root)
        self.assertTrue(expired)
        self.assertNotEqual(code, 0)

    def test_nonzero(self):
        code, out, err, expired = runner.run_process([sys.executable, '-c', 'raise SystemExit(7)'], os.environ.copy(), 5, self.root)
        self.assertEqual(code, 7)
        self.assertEqual(runner.classify(code, out, expired)[0], 'failed')

    def test_script_error_zero(self):
        self.assertEqual(runner.classify(0, 'passed\nSCRIPT ERROR: failed', False)[0], 'failed')

    def test_missing_evidence(self):
        self.assertEqual(runner.classify(0, 'Godot started', False)[0], 'failed')

    def test_structured_failure(self):
        self.assertEqual(runner.classify(0, 'PACKBOUND_TEST_RESULT {"checks":2,"failures":1}', False)[0], 'failed')

    def test_false_green(self):
        for text in ('passed', 'ERROR: missing resource', 'PACKBOUND_TEST_RESULT {}', 'PACKBOUND_TEST_RESULT []', 'PACKBOUND_TEST_RESULT broken', '2 checks, 1 failures'):
            self.assertEqual(runner.classify(0, text, False)[0], 'failed', text)
        self.assertEqual(runner.classify(0, '2 checks, 0 failures', False)[0], 'passed')

    def test_fatal_error_stops_hung_process(self):
        import time
        started = time.monotonic()
        code, output, errors, expired = runner.run_process(
            [sys.executable, '-u', '-c', 'import time;print("SCRIPT ERROR: broken fixture");time.sleep(30)'],
            os.environ.copy(), 10, self.root)
        self.assertLess(time.monotonic() - started, 5)
        self.assertFalse(expired)
        self.assertIn('SCRIPT ERROR:', output)
        self.assertEqual(runner.classify(code, output + errors, expired)[0], 'failed')

    def test_self_timeout(self):
        self.assertEqual(runner.classify(2, 'Test timed out waiting for animation', False)[0], 'timed_out')
        self.assertEqual(runner.classify(2, 'other failure', False)[0], 'failed')

    def test_concurrent_pipe_drain(self):
        code, output, errors, expired = runner.run_process(
            [sys.executable, '-u', '-c', 'import sys;sys.stdout.write("o"*200000);sys.stderr.write("e"*200000)'],
            os.environ.copy(), 5, self.root)
        self.assertEqual(code, 0)
        self.assertFalse(expired)
        self.assertEqual(len(output), 200000)
        self.assertEqual(len(errors), 200000)

    def test_required_actual_isolation_evidence(self):
        test = {'id': 'fixture', 'path': 'tests/fixture_test.gd', 'requires_rendering': False, 'timeout_sec': 2}
        directory = self.root / 'artifacts'
        for actual in (None, '', 5, str(self.root / 'outside'), 'relative/path'):
            evidence = {'checks': 1, 'failures': 0, 'user_data_dir': actual}
            output = 'PACKBOUND_TEST_RESULT ' + json.dumps(evidence)
            with patch.object(runner, 'run_process', return_value=(0, output, '', False)):
                result = runner.execute_test(self.root, 'fake', test, directory, False, 42)
            self.assertEqual(result['status'], 'failed')
            self.assertIn('isolation_error', result['phases'][0]['evidence'][0])
        evidence['user_data_dir'] = str(directory / 'appdata' / 'Godot')
        with patch.object(runner, 'run_process', return_value=(0, 'PACKBOUND_TEST_RESULT ' + json.dumps(evidence), '', False)):
            result = runner.execute_test(self.root, 'fake', test, directory, False, 42)
        self.assertEqual(result['status'], 'passed')

    def test_invalid_phase_objects(self):
        test = {'id': 'fixture', 'path': 'tests/fixture_test.gd', 'suites': ['smoke'], 'requires_rendering': False, 'timeout_sec': 2}
        (self.root / test['path']).write_text('extends SceneTree')
        for phases in ([[]], [None], ['bad'], []):
            test['phases'] = phases
            (self.root / 'tests/manifest.json').write_text(json.dumps({'version': 1, 'tests': [test]}))
            with self.assertRaisesRegex(ValueError, 'Invalid phase'):
                runner.load_manifest(self.root)

    def test_markdown_diagnostics_and_escaping(self):
        directory = self.root / 'run'
        artifacts = directory / 'fixture'
        artifacts.mkdir(parents=True)
        (artifacts / 'phase_1.stderr.txt').write_text('ERROR: raw fallback')
        evidence = {'checks': 3, 'failures': 1, 'failed_checks': [{'message': 'bad | <item>\nnext', 'expected': 2, 'actual': 1}]}
        report = {'id': 'fixture', 'status': 'failed', 'artifact_dir': str(artifacts), 'phases': [{'evidence': [evidence], 'exit_code': 1}]}
        self.assertIn('expected=2 actual=1', runner.first_diagnostic(report))
        target = runner.write_markdown_report(directory, [report], 1729)
        text = target.read_text()
        self.assertIn('Seed: `1729`', text)
        self.assertIn('bad \\| &lt;item&gt; next', text)
        self.assertIn('| 3 | 1 |', text)
        self.assertIn('[report](fixture/report.json)', text)
        evidence['failed_checks'] = []
        self.assertEqual(runner.first_diagnostic(report), 'ERROR: raw fallback')
        (artifacts / 'phase_1.stderr.txt').unlink()
        report['status'] = 'timed_out'
        self.assertEqual(runner.first_diagnostic(report), 'Process exceeded its test timeout')

    def test_render_skip(self):
        r = runner.execute_test(self.root, 'missing', {'id': 'render', 'path': 'x.gd', 'requires_rendering': True}, self.root / 'artifacts', False, 42)
        self.assertEqual(r['status'], 'skipped')

    def test_isolation(self):
        env = runner.isolated_env(self.root / 'one', 11)
        other = runner.isolated_env(self.root / 'two', 12)
        for key in ('APPDATA', 'LOCALAPPDATA', 'HOME', 'USERPROFILE', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'TEMP', 'TMP'):
            self.assertTrue(Path(env[key]).is_relative_to(self.root / 'one'))
            self.assertNotEqual(env[key], other[key])
        code, out, err, expired = runner.run_process([sys.executable, '-c', 'import os;print(os.environ["PACKBOUND_TEST_SEED"])'], env, 5, self.root)
        self.assertEqual(out.strip(), '11')
        self.assertEqual(code, 0)

    def test_manifest(self):
        t = {'id': 'one', 'path': 'tests/one_test.gd', 'suites': ['smoke'], 'requires_rendering': False, 'timeout_sec': 2}
        (self.root / t['path']).write_text('extends SceneTree')
        m = self.root / 'tests/manifest.json'
        m.write_text(json.dumps({'version': 1, 'tests': [t]}))
        self.assertEqual(len(runner.load_manifest(self.root)), 1)
        (self.root / 'tests/unknown_test.gd').write_text('extends SceneTree')
        with self.assertRaisesRegex(ValueError, 'Unregistered'):
            runner.load_manifest(self.root)
        (self.root / 'tests/unknown_test.gd').unlink()
        m.write_text(json.dumps({'version': 1, 'tests': [t, t]}))
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            runner.load_manifest(self.root)
        t['suites'] = ['unknown']
        m.write_text(json.dumps({'version': 1, 'tests': [t]}))
        with self.assertRaisesRegex(ValueError, 'Invalid suites'):
            runner.load_manifest(self.root)
if __name__ == '__main__':
    unittest.main()
