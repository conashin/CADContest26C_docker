# op_src.py - OPTIONAL but strongly recommended (Beta Submission Guidelines,
# Section 1/3). Full, self-contained source code used if op_wrapper.py fails
# or cannot run standalone: "The evaluator tries op_wrapper.py first. If that
# fails, it falls back to op_src.py."
#
# Keep this file independent of anything op_wrapper.py might rely on (a
# compiled binary, GPU-only code path, an optional dependency, ...), so it
# has the best chance of running when op_wrapper.py cannot. In this template
# op_wrapper.py is already pure Python with no external dependency beyond
# requirements.txt, so op_src.py mirrors it exactly. If you adopt the
# subprocess/binary pattern from examples/advanced_binary_wrapper/, this file
# is where a genuine no-binary fallback belongs.
import math
from typing import List, Optional, Tuple

from iccad2026_evaluate import FloorplanOptimizer


def _scalar(value) -> float:
    """area_targets entries may be nested (e.g. [[a]]) - unwrap to float."""
    while isinstance(value, (list, tuple)):
        if not value:
            return 0.0
        value = value[0]
    return float(value)


class MyOptimizer(FloorplanOptimizer):
    """Trivial shelf-packing baseline - NOT constraint-correct, for pipeline
    sanity-checking only. Replace solve() with your real solver."""

    def solve(
        self,
        block_count,
        area_targets,
        b2b_connectivity,
        p2b_connectivity,
        pins_pos,
        constraints,
        target_positions=None,
    ) -> List[Tuple[float, float, float, float]]:
        n = int(block_count)

        areas_raw = area_targets.tolist() if hasattr(area_targets, "tolist") else list(area_targets)
        tpos = None
        if target_positions is not None:
            tpos = target_positions.tolist() if hasattr(target_positions, "tolist") else list(target_positions)

        areas = [_scalar(areas_raw[i]) if i < len(areas_raw) else 1.0 for i in range(n)]
        total_area = sum(a for a in areas if a > 0) or float(n)
        row_width = math.sqrt(total_area) * 1.2

        positions: List[Tuple[float, float, float, float]] = []
        shelf_x = 0.0
        shelf_y = 0.0
        shelf_h = 0.0

        for i in range(n):
            w = h = None

            if tpos is not None and i < len(tpos):
                t = list(tpos[i]) + [-1.0, -1.0, -1.0, -1.0]
                tx, ty, tw, th = t[0], t[1], t[2], t[3]
                if tw is not None and tw >= 0:
                    w = float(tw)
                if th is not None and th >= 0:
                    h = float(th)
                if (tx is not None and tx >= 0 and ty is not None and ty >= 0
                        and w is not None and h is not None):
                    positions.append((float(tx), float(ty), w, h))
                    continue

            a = areas[i] if areas[i] > 0 else 1.0
            if w is None and h is None:
                w = h = math.sqrt(a)
            elif w is None:
                w = a / h if h else 1.0
            elif h is None:
                h = a / w if w else 1.0

            if shelf_x > 0 and shelf_x + w > row_width:
                shelf_y += shelf_h
                shelf_x = 0.0
                shelf_h = 0.0

            positions.append((shelf_x, shelf_y, w, h))
            shelf_x += w
            shelf_h = max(shelf_h, h)

        return positions
