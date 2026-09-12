#!/usr/bin/env python3
"""Exercise the production byte FIFO at every edge, including reset and clear."""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--optimize", default="default",
                        choices=("default", "all", "none"))
    args = parser.parse_args()
    run = Path(tempfile.mkdtemp(prefix="livt-collections-fifo-"))

    def command(args, name):
        with (run / name).open("w") as log:
            result = subprocess.run(args, cwd=run, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=120)
        if result.returncode:
            raise RuntimeError(f"Command failed: {run / name}")

    build = ["livt", "build", "-f", "--project", str(ROOT)]
    if args.optimize != "default":
        build.extend(["--optimize", args.optimize])
    command(build, "build.log")
    files = sorted((ROOT / "out/debug").glob("*/*.vhd"))
    instances = []
    for capacity in (1, 3, 64):
        entities = []
        for path in files:
            content = path.read_text()
            entity = re.search(r"entity (livt_collections_fifo_g_\w+) is", content)
            if (entity and "ctor_pushdata : in std_logic_vector(7 downto 0)" in content
                    and re.search(r'constant CAPACITY .*x"%08X"' % capacity, content)):
                entities.append((entity.group(1), path, content))
        if len(entities) != 1:
            raise RuntimeError(f"Expected one byte FIFO for {capacity}: {entities}")
        entity, path, content = entities[0]
        for forbidden in ("storage_accessor", "this_storage_lvt_var", "this_update_storage"):
            if forbidden in content:
                raise RuntimeError(f"Whole-array storage staging remains in {path}: {forbidden}")
        if "set_signal_logic_array_2d_arity_1(this_storage" not in content:
            raise RuntimeError(f"Expected a direct addressed storage write in {path}")
        if capacity == 64:
            for declaration in (
                    "signal this_head : std_logic_vector(5 downto 0);",
                    "signal this_tail : std_logic_vector(5 downto 0);",
                    "signal this_used : std_logic_vector(6 downto 0);"):
                if declaration not in content:
                    raise RuntimeError(f"Missing narrowed declaration in {path}: {declaration}")
        instances.append(f"""capacity_{capacity}: if CAPACITY = {capacity} generate
            dut: entity work.{entity} port map (
                ctor_lvt_context_in => context_value, ctor_clear => clear_request,
                ctor_push => push_request, ctor_pop => pop_request,
                ctor_pushdata => push_data, ctor_parameter_pushaccepted => push_accepted,
                ctor_parameter_popaccepted => pop_accepted, ctor_parameter_popdata => pop_data,
                ctor_parameter_count => item_count, ctor_parameter_space => free_space,
                ctor_pushaccepted => open, ctor_popaccepted => open, ctor_popdata => open,
                ctor_count => open, ctor_space => open);
            end generate;""")
    harness = run / "edges.vhd"
    harness.write_text((ROOT / "verification/fifo/edges.vhd").read_text()
                       .replace("-- DUT_INSTANCES", "\n".join(instances)))
    command(["ghdl", "-i", "--std=08", *map(str, files), str(harness)], "import.log")
    command(["ghdl", "-m", "--std=08", "single_owner_edges"], "elaborate.log")
    for capacity in (1, 3, 64):
        name = f"capacity-{capacity}.log"
        command(["ghdl", "-r", "--std=08", "single_owner_edges",
                 f"-gCAPACITY={capacity}", "--assert-level=error"], name)
        if "SINGLE_OWNER_PASS" not in (run / name).read_text():
            raise RuntimeError(f"Missing success marker: {run / name}")
    print(f"FIFO edge contract passed at capacities 1/3/64 "
          f"(optimization={args.optimize}); evidence: {run}")


if __name__ == "__main__":
    main()
