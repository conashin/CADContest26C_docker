#!/usr/bin/env python3
"""
Reference *demo* optimizer for the FloorSet Challenge.

It implements the exact I/O contract that op_wrapper.py expects:
  - reads a single JSON object from STDIN
  - writes {"positions": [[x, y, w, h], ...]} (one entry per block) to STDOUT

This is intentionally a trivial shelf-packing baseline whose only purpose is to
exercise the full evaluation pipeline end-to-end (binary <-> wrapper <-> judge).
It is NOT constraint-correct and will not score well. Replace optimizer_main.py
with your real solver, keeping the same stdin/stdout JSON schema.
"""
import json
import math
import sys


def _scalar(value):
    """area_targets entries may be nested lists like [[a]] - unwrap to float."""
    while isinstance(value, list):
        if not value:
            return 0.0
        value = value[0]
    return float(value)


def solve(payload):
    n = int(payload["block_count"])
    area_targets = payload.get("area_targets") or []
    target_positions = payload.get("target_positions")

    areas = [_scalar(area_targets[i]) if i < len(area_targets) else 1.0 for i in range(n)]
    total_area = sum(a for a in areas if a > 0) or float(n)
    row_width = math.sqrt(total_area) * 1.2  # rough square-ish aspect for the die

    positions = []
    shelf_x = 0.0
    shelf_y = 0.0
    shelf_h = 0.0

    for i in range(n):
        x = y = w = h = None

        if target_positions is not None and i < len(target_positions):
            t = list(target_positions[i]) + [-1.0, -1.0, -1.0, -1.0]
            tx, ty, tw, th = t[0], t[1], t[2], t[3]
            if tw is not None and tw >= 0:
                w = float(tw)
            if th is not None and th >= 0:
                h = float(th)
            # Preplaced block: x, y, w, h all specified -> keep it exactly fixed.
            if (tx is not None and tx >= 0 and ty is not None and ty >= 0
                    and w is not None and h is not None):
                positions.append([float(tx), float(ty), w, h])
                continue

        # Derive missing dimensions from the area target.
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

        positions.append([shelf_x, shelf_y, w, h])
        shelf_x += w
        shelf_h = max(shelf_h, h)

    return positions


def main():
    payload = json.load(sys.stdin)
    positions = solve(payload)
    json.dump({"positions": positions}, sys.stdout)


if __name__ == "__main__":
    main()
