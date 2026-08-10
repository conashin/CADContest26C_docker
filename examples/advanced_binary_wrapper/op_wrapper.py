# Advanced pattern: op_wrapper.py subprocess-launching a compiled binary.
#
# The Beta Submission Guidelines only require that op_wrapper.py itself be a
# plain .py file that subclasses FloorplanOptimizer (Section 5) - what it does
# internally is up to you. If your real solver is a native/PyInstaller binary,
# this is how you wrap it. The binary is one of the "<any other files>"
# allowed by Section 1, referenced via a path relative to cadc<team_id>/.
#
# To try this pattern:
#   1. Build the binary inside the container (see README "Advanced: Wrapping
#      a Compiled Binary"), or run examples/build_example.sh.
#   2. Copy this file to submission/op_wrapper.py (replacing the default
#      pure-Python template) alongside the built binary.
#   3. Strongly recommended: also provide an op_src.py with a pure-Python
#      fallback (see root op_src.py) in case the binary fails to load on the
#      judge - the evaluator tries op_wrapper.py first, then op_src.py.
import json
import os
import subprocess
from pathlib import Path
from iccad2026_evaluate import FloorplanOptimizer

class MyOptimizer(FloorplanOptimizer):
    def __init__(self, verbose=True):
        super().__init__(verbose=verbose)
        # Resolve executable from submission-relative locations.
        # Optional override: export MY_OPT_BIN=relative/or/absolute/path
        base_dir = Path(__file__).resolve().parent

        env_bin = os.environ.get("MY_OPT_BIN")
        candidates = []
        if env_bin:
            p = Path(env_bin)
            candidates.append(p if p.is_absolute() else (base_dir / p))

        candidates.extend([
            base_dir / "dist" / "my_optimizer" / "my_optimizer",  # PyInstaller --onedir
            base_dir / "my_optimizer",                               # PyInstaller --onefile
            base_dir / "bin" / "my_optimizer",                     # optional layout
        ])

        self.bin_path = next((p for p in candidates if p.exists()), candidates[0])

        if not self.bin_path.exists():
            raise FileNotFoundError(f"Optimizer executable not found: {self.bin_path}")
        if not os.access(self.bin_path, os.X_OK):
            raise PermissionError(f"Optimizer is not executable: {self.bin_path}")

    def solve(self, block_count, area_targets, b2b_connectivity, p2b_connectivity,
              pins_pos, constraints, target_positions=None):
        payload = {
            "block_count": int(block_count),
            "area_targets": area_targets.tolist(),
            "b2b_connectivity": b2b_connectivity.tolist(),
            "p2b_connectivity": p2b_connectivity.tolist(),
            "pins_pos": pins_pos.tolist(),
            "constraints": constraints.tolist(),
            "target_positions": target_positions.tolist() if target_positions is not None else None,
        }

        proc = subprocess.run(
            [str(self.bin_path)],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
            timeout=60,
            check=True,
        )

        if not proc.stdout.strip():
            raise RuntimeError(
                f"Optimizer produced empty stdout. stderr: {proc.stderr.strip()}"
            )

        data = json.loads(proc.stdout)   # expects {"positions": [[x,y,w,h], ...]}
        if "positions" not in data:
            raise ValueError(
                f"Optimizer JSON must contain 'positions'. Got keys: {list(data.keys())}"
            )
        return [tuple(map(float, p)) for p in data["positions"]]
