import argparse
import datetime
import fnmatch
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
import threading
from pathlib import Path
SUITES = {'smoke', 'systems', 'scenes', 'integration', 'render'}
ERROR = re.compile('(?:SCRIPT )?ERROR:|Assertion failed|AssertionError|assertion failed', re.I)

def load_manifest(root):
    m = json.loads((root / 'tests/manifest.json').read_text(encoding='utf-8-sig'))
    entries = m['tests']
    ids = set()
    paths = set()
    if m.get('version') != 1:
        raise ValueError('Unknown manifest version')
    for t in entries:
        p = (root / t['path']).resolve()
        if not re.fullmatch('[a-z0-9_]+', t['id']) or t['id'] in ids:
            raise ValueError('Invalid/duplicate id ' + t['id'])
        if not p.is_relative_to(root.resolve()) or not p.is_file() or t['path'] in paths or (p.suffix not in ('.gd', '.tscn')):
            raise ValueError('Invalid/duplicate path ' + t['path'])
        if not t['suites'] or not set(t['suites']) <= SUITES:
            raise ValueError('Invalid suites ' + t['id'])
        if type(t['requires_rendering']) is not bool or type(t['timeout_sec']) not in (int, float) or (not 0 < t['timeout_sec'] <= 600):
            raise ValueError('Invalid capabilities ' + t['id'])
        if 'phases' in t and (not isinstance(t['phases'], list) or not t['phases']):
            raise ValueError('Invalid phases')
        for phase in [t] + t.get('phases', []):
            if not isinstance(phase, dict):
                raise ValueError('Invalid phase: expected object')
            if not isinstance(phase.get('args', []), list) or not all((isinstance(a, str) for a in phase.get('args', []))):
                raise ValueError('Invalid args')
        ids.add(t['id'])
        paths.add(t['path'])
    runnable = {p.relative_to(root).as_posix() for base in (root / 'tests', root / 'components') for p in base.rglob('*.gd') if 'support' not in p.relative_to(root).parts and (p.stem.endswith('_test') or p.stem.startswith('test_'))}
    if runnable - paths:
        raise ValueError('Unregistered runnable tests: ' + ', '.join(sorted(runnable - paths)))
    return entries

def isolated_env(directory, seed):
    env = os.environ.copy()
    for key, child in {'APPDATA': 'appdata', 'LOCALAPPDATA': 'localappdata', 'HOME': 'home', 'USERPROFILE': 'home', 'XDG_DATA_HOME': 'data', 'XDG_CONFIG_HOME': 'config', 'XDG_CACHE_HOME': 'cache', 'TEMP': 'temp', 'TMP': 'temp'}.items():
        p = directory / child
        p.mkdir(parents=True, exist_ok=True)
        env[key] = str(p.resolve())
    env.update(PACKBOUND_TEST_ARTIFACT_DIR=str(directory.resolve()), PACKBOUND_TEST_SEED=str(seed), PACKBOUND_TEST_ISOLATED='1')
    return env

def terminate_process_tree(process):
    """Terminate only the process tree owned by this runner invocation."""
    if os.name == 'nt':
        subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True)
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def run_process(command, env, timeout, cwd):
    """Drain both pipes concurrently and stop immediately on fatal Godot errors."""
    options = {'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == 'nt' else {'start_new_session': True}
    process = subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, **options)
    fatal_error = threading.Event()
    stdout_chunks = []
    stderr_chunks = []

    def drain(pipe, chunks):
        try:
            for line in iter(pipe.readline, b''):
                chunks.append(line)
                if ERROR.search(line.decode('utf-8', errors='replace')):
                    fatal_error.set()
        finally:
            pipe.close()

    readers = [threading.Thread(target=drain, args=(process.stdout, stdout_chunks), daemon=True),
               threading.Thread(target=drain, args=(process.stderr, stderr_chunks), daemon=True)]
    for reader in readers:
        reader.start()
    deadline = time.monotonic() + timeout
    expired = False
    while process.poll() is None:
        if fatal_error.wait(timeout=min(0.05, max(0, deadline - time.monotonic()))):
            terminate_process_tree(process)
            break
        if time.monotonic() >= deadline:
            expired = True
            terminate_process_tree(process)
            break
    process.wait(timeout=10)
    for reader in readers:
        reader.join(timeout=10)
    return (process.returncode,
            b''.join(stdout_chunks).decode('utf-8', errors='replace'),
            b''.join(stderr_chunks).decode('utf-8', errors='replace'), expired)


def classify(code, output, expired):
    expired = expired or (code == 2 and bool(re.search(r'\btimed out\b', output, re.I)))
    evidence = []
    for line in output.splitlines():
        if line.startswith('PACKBOUND_TEST_RESULT '):
            try:
                evidence.append(json.loads(line[len('PACKBOUND_TEST_RESULT '):]))
            except json.JSONDecodeError:
                evidence.append({'failures': 1})
    failed = code != 0 or bool(ERROR.search(output))
    for e in evidence:
        if not isinstance(e, dict) or type(e.get('checks')) is not int or type(e.get('failures')) is not int or (e['checks'] <= 0) or (e['failures'] != 0):
            failed = True
    if not evidence:
        counts = re.findall('(\\d+) checks?[,;:]?\\s+(\\d+) failures?', output, re.I)
        if not counts or any((int(checks) <= 0 or int(failures) != 0 for checks, failures in counts)):
            failed = True
    return ('timed_out' if expired else 'failed' if failed else 'passed', evidence)

def execute_test(root, exe, t, directory, render, seed):
    directory.mkdir(parents=True, exist_ok=True)
    r = {'id': t['id'], 'path': t['path'], 'seed': seed, 'artifact_dir': str(directory.resolve()), 'phases': [], 'status': 'passed'}
    if t['requires_rendering'] and (not render):
        r.update(status='skipped', reason='requires rendering; enable -Render')
    else:
        env = isolated_env(directory, seed)
        started = time.monotonic()
        for i, phase in enumerate(t.get('phases', [{}])):
            command = [exe, '--path', str(root), '--log-file', str((directory / f'phase_{i + 1}.godot.log').resolve())]
            if not render:
                command += ['--headless']
            command += ['--script', 'res://' + t['path']] if t['path'].endswith('.gd') else ['res://' + t['path']]
            args = t.get('args', []) + phase.get('args', [])
            if args:
                command += ['--'] + args
            code, out, err, expired = run_process(command, env, t['timeout_sec'], root)
            (directory / f'phase_{i + 1}.stdout.txt').write_text(out, encoding='utf-8')
            (directory / f'phase_{i + 1}.stderr.txt').write_text(err, encoding='utf-8')
            status, evidence = classify(code, out + '\n' + err, expired)
            for result in evidence:
                if not isinstance(result, dict):
                    status = 'failed'
                    continue
                actual_user_dir = result.get('user_data_dir')
                isolation_error = None
                if not isinstance(actual_user_dir, str) or not actual_user_dir.strip():
                    isolation_error = 'Missing or invalid actual user:// directory evidence'
                else:
                    try:
                        user_path = Path(actual_user_dir)
                        if not user_path.is_absolute() or not user_path.resolve().is_relative_to(directory.resolve()):
                            isolation_error = 'user:// resolved outside test artifacts'
                    except (OSError, ValueError):
                        isolation_error = 'Invalid actual user:// directory evidence'
                if isolation_error:
                    status = 'failed'
                    result['isolation_error'] = isolation_error
            r['phases'].append({'name': phase.get('name', str(i + 1)), 'status': status, 'exit_code': code, 'legacy_result': not evidence, 'evidence': evidence, 'command': command})
            if status != 'passed':
                r['status'] = status
                break
        r['duration_sec'] = round(time.monotonic() - started, 3)
    (directory / 'report.json').write_text(json.dumps(r, indent=2), encoding='utf-8')
    return r

def first_diagnostic(report):
    """Return one useful failure message without requiring raw-log browsing."""
    for phase in report.get('phases', []):
        for result in phase.get('evidence', []):
            if not isinstance(result, dict):
                continue
            if result.get('isolation_error'):
                return result['isolation_error']
            failed_checks = result.get('failed_checks', [])
            if failed_checks:
                first = failed_checks[0]
                if isinstance(first, dict):
                    detail = first.get('message', 'Failed check')
                    if 'expected' in first or 'actual' in first:
                        detail += f"; expected={first.get('expected')} actual={first.get('actual')}"
                    return detail
                return str(first)
    directory = Path(report['artifact_dir'])
    for pattern in ('phase_*.stderr.txt', 'phase_*.stdout.txt'):
        for log in sorted(directory.glob(pattern)):
            for line in log.read_text(encoding='utf-8', errors='replace').splitlines():
                if ERROR.search(line) or re.search(r'\bFAIL:|\btimed out\b', line, re.I):
                    return line.strip()
    if report.get('status') == 'timed_out':
        return 'Process exceeded its test timeout'
    if report.get('status') == 'failed':
        phases = report.get('phases', [])
        if phases and phases[-1].get('exit_code'):
            return f"Process exit {phases[-1]['exit_code']}"
        return 'Missing or invalid final test evidence'
    return report.get('reason', '')


def write_markdown_report(destination, reports, seed, counts=None):
    """Write report.md for a fresh run or existing aggregate JSON results."""
    destination = Path(destination)
    if counts is None:
        counts = {status: sum(report['status'] == status for report in reports)
                  for status in ('passed', 'failed', 'skipped', 'timed_out')}

    def cell(value):
        return str(value).replace('\\', '\\\\').replace('|', '\\|').replace('\r', ' ').replace('\n', ' ').replace('<', '&lt;').replace('>', '&gt;')

    lines = ['# Packbound test results', '', f'Seed: `{seed}`', '',
             ', '.join(f'{status}: **{count}**' for status, count in counts.items()), '',
             '| Test | Status | Checks | Failures | First diagnostic | Artifacts |',
             '| --- | --- | ---: | ---: | --- | --- |']
    for report in reports:
        evidence = [result for phase in report.get('phases', []) for result in phase.get('evidence', []) if isinstance(result, dict)]
        checks = sum(result.get('checks', 0) for result in evidence if type(result.get('checks')) is int)
        failures = sum(result.get('failures', 0) for result in evidence if type(result.get('failures')) is int)
        relative = Path(os.path.relpath(Path(report['artifact_dir']).resolve(), destination.resolve())).as_posix()
        links = f'[report]({relative}/report.json)'
        for index, phase in enumerate(report.get('phases', []), 1):
            links += f' / [log {index}]({relative}/phase_{index}.godot.log) / [stderr {index}]({relative}/phase_{index}.stderr.txt)'
        diagnostic = first_diagnostic(report) if report['status'] != 'passed' else ''
        lines.append(f"| {cell(report['id'])} | {report['status']} | {checks if evidence else '-'} | {failures if evidence else '-'} | {cell(diagnostic)} | {links} |")
    target = destination / 'report.md'
    target.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return target


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--suite', choices=sorted(SUITES | {'all'}), default='smoke')
    p.add_argument('--test', default='*')
    p.add_argument('--render', action='store_true')
    p.add_argument('--list', action='store_true')
    p.add_argument('--godot')
    p.add_argument('--run-id')
    p.add_argument('--seed', type=int, default=1729)
    a = p.parse_args()
    root = Path(__file__).resolve().parents[2]
    try:
        entries = load_manifest(root)
        selected = [t for t in entries if (a.suite == 'all' or a.suite in t['suites']) and fnmatch.fnmatchcase(t['id'], a.test)]
        if not selected:
            raise ValueError('No tests match selection')
        if a.list:
            for t in selected:
                print(f"{t['id']} [{','.join(t['suites'])}] render={t['requires_rendering']} {t['timeout_sec']}s {t['path']}")
            return 0
        exe = a.godot or shutil.which('godot') or shutil.which('godot4') or 'D:\\Apps\\Installs\\Godot\\Godot_v4.7.2-stable_win64_console.exe'
        if not Path(exe).is_file():
            raise ValueError('Godot executable not found; use -Godot')
        runid = a.run_id or datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
        if not re.fullmatch('[A-Za-z0-9_-]+', runid):
            raise ValueError('Unsafe run id')
        dest = root / 'workspace/tasks/test-runs' / runid
        dest.mkdir(parents=True, exist_ok=False)
        reports = []
        for t in selected:
            result = execute_test(root, exe, t, dest / t['id'], a.render, a.seed)
            reports.append(result)
            diagnostic = first_diagnostic(result) if result['status'] in ('failed', 'timed_out') else ''
            print(f"{result['status']:9} {t['id']}" + (f' — {diagnostic}' if diagnostic else ''), flush=True)
        counts = {s: sum((t['status'] == s for t in reports)) for s in ('passed', 'failed', 'skipped', 'timed_out')}
        (dest / 'report.json').write_text(json.dumps({'seed': a.seed, 'counts': counts, 'legacy_phase_count': sum(phase['legacy_result'] for report in reports for phase in report['phases']), 'tests': reports}, indent=2), encoding='utf-8')
        write_markdown_report(dest, reports, a.seed, counts)
        print(f'{counts} seed={a.seed} artifacts={dest}')
        return int(bool(counts['failed'] or counts['timed_out']))
    except (ValueError, KeyError, OSError, TypeError) as e:
        print(f'Runner error: {e}', file=sys.stderr)
        return 2
if __name__ == '__main__':
    sys.exit(main())
