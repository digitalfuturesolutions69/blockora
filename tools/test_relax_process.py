#!/usr/bin/env python3
"""Verify committed Relax progress survives SIGKILL during an injected temp write."""
import hashlib
import json
from pathlib import Path
import select
import subprocess
import tempfile
import time

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="blockora-relax-process-") as directory:
    root = Path(directory)
    classic = root / "classic_session_v1.json"
    classic.write_text('{"sentinel":"untouched Classic evidence"}')
    classic_before = classic.read_bytes()
    base = ["godot", "--headless", "--path", str(repo), "--script",
            "tests/integration/relax_process_fixture.gd", "--"]

    def read(mode):
        run = subprocess.run(base + [mode, directory], capture_output=True, text=True, timeout=30)
        assert run.returncode == 0, run.stdout + run.stderr
        assert not any(x in run.stdout + run.stderr for x in ["SCRIPT ERROR", "ERROR:"]), run.stderr
        return json.loads(next(x.split("PROCESS_SNAPSHOT: ", 1)[1]
                               for x in run.stdout.splitlines() if x.startswith("PROCESS_SNAPSHOT: ")))

    before = read("prepare")
    committed = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in root.glob("*.json")}
    child = subprocess.Popen(base + ["interrupt", directory], stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, text=True, bufsize=1)
    try:
        deadline = time.monotonic() + 30
        ready = False
        while time.monotonic() < deadline:
            if select.select([child.stdout], [], [], 1)[0]:
                line = child.stdout.readline()
                if "INTERRUPTED_WRITE_READY" in line:
                    ready = True
                    break
                if not line and child.poll() is not None:
                    break
        assert ready, "Fault checkpoint not reached"
        child.kill()
        output, errors = child.communicate(timeout=10)
        assert child.returncode == -9
        assert not any(x in output + errors for x in ["SCRIPT ERROR", "ERROR:"])
    finally:
        if child.poll() is None:
            child.kill()
            child.wait()
    assert any(root.glob("*.json.tmp")), "Partial save must remain for recovery test"
    assert {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in root.glob("*.json")} == committed
    assert read("read") == before
    assert classic.read_bytes() == classic_before
print("RELAX PROCESS RESULT: 1 SIGKILL checkpoint, 4 recovery checks, 0 failures; injected partial temp write")
