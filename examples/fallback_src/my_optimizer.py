#!/usr/bin/env python3
"""
Reference *demo* source-code submission for the FloorSet Challenge "fallback".

The Submission Guidelines allow submitting source code instead of a PyInstaller
executable ("As a fallback, you may also submit your source code."). In that
case the official harness evaluates the source module directly:

    python iccad2026_evaluate.py --evaluate my_optimizer.py

The harness imports the module and instantiates the first class that subclasses
FloorplanOptimizer (or one named MyOptimizer / Optimizer / ContestOptimizer),
then calls solve(). Unlike the executable path there is NO op_wrapper.py and NO
subprocess: solve() runs in-process and receives torch tensors directly.

This is intentionally a trivial shelf-packing baseline whose only purpose is to
exercise the source-code (fallback) evaluation path end-to-end. It is NOT
constraint-correct and will not score well. Replace solve() with your real
solver, keeping the same signature and return schema.
"""
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
    """Shelf-packing baseline implemented directly in Python (no binary)."""

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

        # Inputs arrive as torch tensors; convert to plain Python lists so this
        # demo has no dependency on tensor semantics.
        areas_raw = area_targets.tolist() if hasattr(area_targets, "tolist") else list(area_targets)
        tpos = None
        if target_positions is not None:
            tpos = target_positions.tolist() if hasattr(target_positions, "tolist") else list(target_positions)

        areas = [_scalar(areas_raw[i]) if i < len(areas_raw) else 1.0 for i in range(n)]
        total_area = sum(a for a in areas if a > 0) or float(n)
        row_width = math.sqrt(total_area) * 1.2  # rough square-ish die aspect

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
                # Preplaced block: x, y, w, h all set -> keep exactly fixed.
                if (tx is not None and tx >= 0 and ty is not None and ty >= 0
                        and w is not None and h is not None):
                    positions.append((float(tx), float(ty), w, h))
                    continue

            # Derive any missing dimensions from the area target.
            a = areas[i] if areas[i] > 0 else 1.0
            if w is None and h is None:
                w = h = math.sqrt(a)
            elif w is None:
                w = a / h if h else 1.0
            elif h is None:
                h = a / w if w else 1.0

            # Shelf placement: wrap to a new row when the current one is full.
            if shelf_x > 0 and shelf_x + w > row_width:
                shelf_y += shelf_h
                shelf_x = 0.0
                shelf_h = 0.0

            positions.append((shelf_x, shelf_y, w, h))
            shelf_x += w
            shelf_h = max(shelf_h, h)

        return positions
