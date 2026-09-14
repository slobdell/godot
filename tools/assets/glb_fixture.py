"""Tiny GLB writer for tests and mock providers: a box (optionally with an emissive material).

No dependencies. The output is a valid glTF 2.0 binary that Godot's GLTFDocument loads, sized
like something a generator would return (arbitrary scale, facing +Z).
"""

import json
import struct


def box_glb(size=(2.0, 1.0, 3.0), material_name="Main", emissive=None) -> bytes:
    sx, sy, sz = (s / 2.0 for s in size)
    corners = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
               (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
    faces = [(0, 2, 1), (0, 3, 2), (4, 5, 6), (4, 6, 7), (0, 1, 5), (0, 5, 4),
             (3, 7, 6), (3, 6, 2), (0, 4, 7), (0, 7, 3), (1, 2, 6), (1, 6, 5)]
    positions = b"".join(struct.pack("<3f", *c) for c in corners)
    indices = b"".join(struct.pack("<3H", *f) for f in faces)
    indices += b"\x00" * (-len(indices) % 4)
    binary = positions + indices
    binary += b"\x00" * (-len(binary) % 4)

    material = {"name": material_name, "pbrMetallicRoughness": {"baseColorFactor": [0.3, 0.3, 0.32, 1.0]}}
    if emissive:
        material["emissiveFactor"] = list(emissive)
    gltf = {
        "asset": {"version": "2.0", "generator": "tank-squad glb_fixture"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "GeneratedModel", "mesh": 0}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1, "material": 0}]}],
        "materials": [material],
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(positions), "target": 34962},
            {"buffer": 0, "byteOffset": len(positions), "byteLength": len(faces) * 6, "target": 34963},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": 8, "type": "VEC3",
             "min": [-sx, -sy, -sz], "max": [sx, sy, sz]},
            {"bufferView": 1, "componentType": 5123, "count": len(faces) * 3, "type": "SCALAR"},
        ],
    }
    text = json.dumps(gltf, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    chunks = struct.pack("<I4s", len(text), b"JSON") + text + struct.pack("<I4s", len(binary), b"BIN\x00") + binary
    return struct.pack("<4sII", b"glTF", 2, 12 + len(chunks)) + chunks


if __name__ == "__main__":
    import sys
    with open(sys.argv[1] if len(sys.argv) > 1 else "box.glb", "wb") as handle:
        handle.write(box_glb(emissive=(0.0, 0.9, 1.0)))
