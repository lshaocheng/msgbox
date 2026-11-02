#!/usr/bin/env python3
"""Measure only our Release app; never inspect chat apps or grant permissions."""
import json
import os
from pathlib import Path
import signal
import subprocess
import time

root = Path(__file__).resolve().parent.parent
executable = root / 'build-release/Build/Products/Release/Msgbox.app/Contents/MacOS/Msgbox'
assert executable.is_file(), 'Build Release first'
log = root / 'logs/idle-app.log'
with log.open('w') as output:
    process = subprocess.Popen([str(executable)], stdout=output, stderr=output)
    start = time.monotonic()
    samples = []
    try:
        for index in range(19):
            if index:
                time.sleep(10)
            assert process.poll() is None, 'App exited during idle measurement'
            rss = subprocess.run(['/bin/ps', '-o', 'rss=', '-p', str(process.pid)], capture_output=True, text=True, check=True)
            connections = subprocess.run(['/usr/sbin/lsof', '-nP', '-a', '-p', str(process.pid), '-i'], capture_output=True, text=True)
            assert connections.returncode in (0, 1), connections.stderr
            assert not connections.stderr, connections.stderr
            samples.append({'elapsed_seconds': round(time.monotonic()-start, 3), 'rss_kib': int(rss.stdout),
                            'network_sockets': max(0, len(connections.stdout.strip().splitlines())-1)})
            if index == 1:
                subprocess.run(['/usr/bin/sample', str(process.pid), '1', '-file', str(root / 'logs/idle-sample.txt')], capture_output=True, check=True)
        process.send_signal(signal.SIGTERM)
        _, status, usage = os.wait4(process.pid, 0)
        process.returncode = os.waitstatus_to_exitcode(status)
        elapsed = time.monotonic()-start
        result = {'duration_seconds': elapsed, 'termination': 'SIGTERM by benchmark after sampling',
                  'user_cpu_seconds': usage.ru_utime, 'system_cpu_seconds': usage.ru_stime,
                  'average_one_core_cpu_percent': 100*(usage.ru_utime+usage.ru_stime)/elapsed,
                  'max_rss_bytes': usage.ru_maxrss, 'voluntary_context_switches': usage.ru_nvcsw,
                  'involuntary_context_switches': usage.ru_nivcsw, 'samples': samples,
                  'scope': 'Release arm64; no Accessibility trust; UI closed; running targets; no physical sleep or energy measurement'}
        (root / 'logs/idle-metrics.json').write_text(json.dumps(result, indent=2)+'\n')
        print(json.dumps(result, indent=2))
    finally:
        if process.returncode is None:
            process.terminate()
            process.wait(timeout=10)
