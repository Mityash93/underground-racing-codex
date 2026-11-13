#!/usr/bin/env python3
"""Convert wallon's CC BY Audi R8 archive to calibrated Godot driving art.

Bake FBX/glTF transforms, split paired wheels spatially, merge by material.
Only Python's standard library is required. Source ZIP stays untouched.
"""
import copy
import hashlib
import json
import math
import struct
import zipfile
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/cars/audi_r8"
IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]


def multiply(a, b):
    return [sum(a[k * 4 + r] * b[c * 4 + k] for k in range(4)) for c in range(4) for r in range(4)]


def transform(matrix, point, direction=False):
    return [sum(matrix[c * 4 + r] * point[c] for c in range(3)) + (0 if direction else matrix[12 + r]) for r in range(3)]


def bounds(points):
    return ([min(p[i] for p in points) for i in range(3)],
            [max(p[i] for p in points) for i in range(3)])


def prepare():
    archive = DEST / "audi_r8.zip"
    output = DEST / "prepared"
    output.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as source:
        if sum(i.file_size for i in source.infolist()) > 150_000_000:
            raise ValueError("Unexpected archive size")
        for entry in source.infolist():
            path = Path(entry.filename)
            if path.is_absolute() or ".." in path.parts or (entry.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError("Unsafe ZIP member")
            if entry.is_dir() or path.suffix != ".png":
                continue
            target = output / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read(entry))
        gltf = json.loads(source.read("scene.gltf"))
        binary = source.read("scene.bin")
        (DEST / "license.txt").write_bytes(source.read("license.txt"))

    def read(index):
        accessor = gltf["accessors"][index]
        view = gltf["bufferViews"][accessor["bufferView"]]
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
        component = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}[accessor["componentType"]]
        fmt = "<" + component * width
        step = view.get("byteStride", struct.calcsize(fmt))
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        return [struct.unpack_from(fmt, binary, start + i * step) for i in range(accessor["count"])]

    parts = {}
    prefix = multiply(gltf["nodes"][0]["matrix"], gltf["nodes"][1]["matrix"])
    for index in gltf["nodes"][2]["children"]:
        parent = gltf["nodes"][index]
        matrix = multiply(prefix, parent.get("matrix", IDENTITY))
        mesh_node = gltf["nodes"][parent["children"][0]]
        matrix = multiply(matrix, mesh_node.get("matrix", IDENTITY))
        primitives = []
        for primitive in gltf["meshes"][mesh_node["mesh"]]["primitives"]:
            assert primitive.get("mode", 4) == 4
            positions = [transform(matrix, p) for p in read(primitive["attributes"]["POSITION"])]
            normals = [transform(matrix, p, True) for p in read(primitive["attributes"]["NORMAL"])]
            uvs = read(primitive["attributes"]["TEXCOORD_0"]) if "TEXCOORD_0" in primitive["attributes"] else [(0, 0)] * len(positions)
            primitives.append((primitive["material"], positions, normals, uvs, [i[0] for i in read(primitive["indices"])]))
        parts[index] = primitives

    def half_tire(index):
        return bounds([p for primitive in parts[index] for p in primitive[1] if p[0] < 0])

    front_min, front_max = half_tire(15)
    rear_min, rear_max = half_tire(5)
    front = [(a + b) / 2 for a, b in zip(front_min, front_max)]
    rear = [(a + b) / 2 for a, b in zip(rear_min, rear_max)]
    body_min, body_max = bounds([p for index, primitives in parts.items() if index > 17 for primitive in primitives for p in primitive[1]])
    scale = 4.5 / (body_max[2] - body_min[2])
    # The source front wheels have baked steering (~33 degrees) and camber.
    # Recover the axle from the rim's repeated planar face normal. Using the
    # vehicle X axis or squeezing its bounding box makes a rolling wheel wobble.
    clusters = defaultdict(list)
    for _, positions, normals, _, _ in parts[13]:
        for p, normal in zip(positions, normals):
            if p[0] >= 0:
                continue
            n = [-normal[0], normal[1], -normal[2]]
            length = math.sqrt(sum(v * v for v in n))
            n = [v / length * (1 if n[0] >= 0 else -1) for v in n]
            clusters[tuple(round(v, 3) for v in n)].append(n)
    face = max(clusters.values(), key=len)
    axle = [sum(n[i] for n in face) / len(face) for i in range(3)]
    length = math.sqrt(sum(v * v for v in axle))
    axle = [v / length for v in axle]
    up = [(1 if i == 1 else 0) - axle[i] * axle[1] for i in range(3)]
    length = math.sqrt(sum(v * v for v in up))
    up = [v / length for v in up]
    forward = [axle[1] * up[2] - axle[2] * up[1],
               axle[2] * up[0] - axle[0] * up[2], axle[0] * up[1] - axle[1] * up[0]]
    axes = [axle, up, forward]

    def straighten(vector):
        return [sum(a * b for a, b in zip(vector, axis)) for axis in axes]

    tire_points = [straighten([-(p[0] - front[0]) * scale,
                              (p[1] - front[1]) * scale, -(p[2] - front[2]) * scale])
                   for primitive in parts[15] for p in primitive[1] if p[0] < 0]
    tire_min, tire_max = bounds(tire_points)
    radius = (tire_max[1] - tire_min[1]) / 2
    center_z = (body_max[2] + body_min[2]) / 2
    ground = front[1] - radius / scale

    def vehicle_point(p):
        # Source faces +Z. Godot cars face -Z. Ground contact is local y=.05.
        return [-p[0] * scale, (p[1] - ground) * scale + 0.05, -(p[2] - center_z) * scale]

    front_mount = vehicle_point(front)
    rear_mount = vehicle_point(rear)
    materials = copy.deepcopy(gltf["materials"])
    # Retain the source copper paint. Bound extreme gloss for stable night lighting.
    for material in materials:
        pbr = material.get("pbrMetallicRoughness", {})
        pbr["roughnessFactor"] = max(0.1, pbr.get("roughnessFactor", 1.0))

    def scene(name, selected, wheel=False):
        groups = {}
        for index in selected:
            for mat, positions, normals, uvs, indices in parts[index]:
                group = groups.setdefault(mat, {"p": [], "n": [], "uv": [], "i": []})
                mapping = {}
                for start in range(0, len(indices), 3):
                    triangle = indices[start:start + 3]
                    if wheel and sum(positions[i][0] for i in triangle) >= 0:
                        continue
                    for old in triangle:
                        if old not in mapping:
                            mapping[old] = len(group["p"])
                            p = vehicle_point(positions[old])
                            if wheel:
                                p = [a - b for a, b in zip(p, front_mount)]
                                p = straighten(p)
                            n = [-normals[old][0], normals[old][1], -normals[old][2]]
                            if wheel:
                                n = straighten(n)
                            length = math.sqrt(sum(v * v for v in n)) or 1
                            group["p"].append(p)
                            group["n"].append([v / length for v in n])
                            group["uv"].append(uvs[old])
                        group["i"].append(mapping[old])

        doc = {"asset": {"version": "2.0", "generator": "STREET LEGENDS Audi preparation"},
               "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"name": name, "children": []}],
               "meshes": [], "accessors": [], "bufferViews": [], "materials": materials}
        for key in ("images", "textures", "samplers", "extensionsUsed"):
            if key in gltf:
                doc[key] = copy.deepcopy(gltf[key])
        data = bytearray()

        def accessor(values, width, integer=False, vertex=False):
            while len(data) % 4:
                data.append(0)
            offset = len(data)
            flat = values if width == 1 else [v for row in values for v in row]
            data.extend(struct.pack("<" + ("I" if integer else "f") * len(flat), *flat))
            doc["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(data) - offset})
            item = {"bufferView": len(doc["bufferViews"]) - 1, "componentType": 5125 if integer else 5126,
                    "count": len(values), "type": {1: "SCALAR", 2: "VEC2", 3: "VEC3"}[width]}
            if vertex:
                item["min"], item["max"] = bounds(values)
            doc["accessors"].append(item)
            return len(doc["accessors"]) - 1

        for mat, group in groups.items():
            if not group["i"]:
                continue
            attributes = {"POSITION": accessor(group["p"], 3, vertex=True),
                          "NORMAL": accessor(group["n"], 3), "TEXCOORD_0": accessor(group["uv"], 2)}
            primitive = {"attributes": attributes, "indices": accessor(group["i"], 1, integer=True), "material": mat}
            doc["meshes"].append({"primitives": [primitive]})
            doc["nodes"][0]["children"].append(len(doc["nodes"]))
            doc["nodes"].append({"name": ("BrakeLight" if mat == 6 else "Surface") + str(mat), "mesh": len(doc["meshes"]) - 1})
        doc["buffers"] = [{"uri": name + ".bin", "byteLength": len(data)}]
        (output / (name + ".bin")).write_bytes(data)
        (output / (name + ".gltf")).write_text(json.dumps(doc, separators=(",", ":")))

    scene("audi_body", [i for i in parts if i > 17])
    scene("audi_wheel", [11, 13, 15], wheel=True)
    scene("audi_brake", [17], wheel=True)
    calibration = {"front_half_track": front_mount[0], "rear_half_track": rear_mount[0],
                   "front_z": front_mount[2], "rear_z": rear_mount[2], "wheel_y": front_mount[1], "radius": radius,
                   "source_axle": axle, "straightened_tire_bounds": [tire_min, tire_max]}
    (DEST / "calibration.json").write_text(json.dumps(calibration, indent=2) + "\n")
    (DEST / "source.json").write_text(json.dumps({
        "title": "Audi R8", "author": "wallon", "author_url": "https://sketchfab.com/realwallon",
        "source": "https://sketchfab.com/3d-models/audi-r8-e17e438f076f4427a58d93aa779edaed",
        "license": "CC-BY-4.0", "license_url": "https://creativecommons.org/licenses/by/4.0/",
        "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
        "changes": ["Transforms baked, length normalized to 4.5 m, faces -Z.",
                    "Paired wheels separated; canonical front right wheel used at all mounts.",
                    "Calipers separated; front assembly also used at rear.",
                    "Baked source steering/camber removed from wheel and caliper; original width restored.",
                    "Meshes merged by material, original textures/copper paint retained.",
                    "Roughness bounded to 0.1; red rear LED responds to braking."]}, indent=2) + "\n")
    print(json.dumps(calibration, indent=2))


if __name__ == "__main__":
    prepare()
