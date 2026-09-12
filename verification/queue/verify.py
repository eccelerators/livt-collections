#!/usr/bin/env python3
"""Measure Queue8 handshakes and reset recovery using generated production HDL."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    run = Path(tempfile.mkdtemp(prefix="livt-collections-queue-"))
    def command(args, name, cwd=run):
        with (run / name).open("w") as log:
            result = subprocess.run(args, cwd=cwd, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=120)
        if result.returncode:
            raise RuntimeError(f"Command failed: {run / name}")

    command(["livt", "build", "-f", "--project", str(ROOT)], "build.log")
    hdl = run / "hdl"
    hdl.mkdir()
    files = sorted((ROOT / "out/debug").glob("*/*.vhd"))
    for source in files:
        shutil.copy2(source, hdl / source.name)
    files = sorted(hdl.glob("*.vhd"))
    queue = (hdl / "Livt.Collections.Queue8.vhd").read_text()
    match = re.search(r"tryenqueue_in : in t_(iqueue_g_\w+)_tryenqueue_in", queue)
    if not match:
        raise RuntimeError("Cannot identify the byte queue interface")
    # A named specialization must not wrap another Queue or allocate extra memory.
    if len(re.findall(r"fifo_instance: entity work\.livt_collections_fifo_", queue)) != 1:
        raise RuntimeError("Expected exactly one backing FIFO")
    if re.search(r"entity work\.livt_collections_queue", queue):
        raise RuntimeError("Unexpected nested Queue layer")
    harness = run / "handshakes.vhd"
    harness.write_text((ROOT / "verification/queue/handshakes.vhd").read_text()
                       .replace("QUEUE_INTERFACE", match.group(1)))
    command(["ghdl", "-i", "--std=08", *map(str, files), str(harness)], "import.log")
    command(["ghdl", "-m", "--std=08", "queue_handshakes"], "elaborate.log")
    command(["ghdl", "-r", "--std=08", "queue_handshakes", "--assert-level=error"], "simulation.log")
    output = (run / "simulation.log").read_text()
    if "QUEUE_HANDSHAKE_PASS" not in output:
        raise RuntimeError(f"Missing success marker: {run / 'simulation.log'}")
    evidence = {
        "configuration": {"component": "Queue8", "clock_hz": 100000000},
        "latency_unit": "rising edges from first run sampling through observed busy deassertion, inclusive",
        "measurements": re.findall(r"MEASURE (\w+) cycles=(\d+)", output),
        "generated_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
        "source_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                          for folder in ("src", "verification/queue")
                          for p in sorted((ROOT / folder).rglob("*")) if p.is_file()},
    }
    command(["livt", "--version"], "compiler-version.log")
    command(["ghdl", "--version"], "ghdl-version.log")
    (run / "result.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(f"Queue handshake/reset contract passed; evidence: {run}")


if __name__ == "__main__":
    main()
