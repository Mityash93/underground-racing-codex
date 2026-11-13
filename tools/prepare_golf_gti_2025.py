#!/usr/bin/env python3
"""Prepare the user's Sketchfab glTF archive; no third-party Python packages.

Keep the author's node transforms, use first animation keys for a closed car,
and separate rolling tires from fixed brakes. Raw art is local, not redistributed.
"""
import copy
import hashlib
import json
import struct
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/cars/golf_gti_2025"


def prepare():
    archive = DEST / "volkswagen_golf_gti_2025.zip"
    output = DEST / "prepared"
    output.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as source:
        if sum(i.file_size for i in source.infolist()) > 150_000_000:
            raise ValueError("Unexpected archive size")
        for entry in source.infolist():
            path = Path(entry.filename)
            if path.is_absolute() or ".." in path.parts or (entry.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError("Unsafe archive path")
            if entry.is_dir():
                continue
            if path.name == "scene.gltf":
                continue
            target = output / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read(entry))
        gltf = json.loads(source.read("scene.gltf"))
        (DEST / "license.txt").write_bytes(source.read("license.txt"))
    binary = (output / "scene.bin").read_bytes()

    def first_value(index):
        accessor = gltf["accessors"][index]
        view = gltf["bufferViews"][accessor["bufferView"]]
        size = {"VEC3": 3, "VEC4": 4}[accessor["type"]]
        assert accessor["componentType"] == 5126
        offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        return list(struct.unpack_from("<" + "f" * size, binary, offset))

    for animation in gltf.get("animations", []):
        for channel in animation["channels"]:
            target = channel["target"]
            if target["path"] in ("translation", "rotation", "scale"):
                node = gltf["nodes"][target["node"]]
                node.pop("matrix", None)
                node[target["path"]] = first_value(animation["samplers"][channel["sampler"]]["output"])
    gltf.pop("animations", None)
    # Godot has two UV sets. Discard the third AO set instead of using wrong UVs.
    for material in gltf["materials"]:
        if material.get("occlusionTexture", {}).get("texCoord", 0) > 1:
            material.pop("occlusionTexture", None)
        pbr = material.get("pbrMetallicRoughness", {})
        if pbr.get("metallicRoughnessTexture", {}).get("texCoord", 0) != pbr.get("baseColorTexture", {}).get("texCoord", 0):
            pbr.pop("metallicRoughnessTexture", None)
    for mesh in gltf["meshes"]:
        for primitive in mesh["primitives"]:
            for key in list(primitive["attributes"]):
                if key.startswith("TEXCOORD_") and int(key.split("_")[-1]) > 1:
                    primitive["attributes"].pop(key)

    # Actual tire centres, including the author's rim/tire offsets.
    def tire_center(wheel, tire):
        wp = gltf["nodes"][wheel]["matrix"][12:15]
        matrix = gltf["nodes"][tire]["matrix"]
        accessor = gltf["accessors"][gltf["meshes"][gltf["nodes"][gltf["nodes"][tire]["children"][0]]["mesh"]]["primitives"][0]["attributes"]["POSITION"]]
        center = [(lo + hi) / 2 for lo, hi in zip(accessor["min"], accessor["max"])]
        return [wp[row] + matrix[12 + row] + sum(matrix[col * 4 + row] * center[col] for col in range(3)) for row in range(3)]

    front = tire_center(11, 14)
    rear = tire_center(21, 24)
    radius = 0.32811111211776733
    shift_y = radius + 0.05 - front[1]

    def write_scene(name, roots, excluded, shift):
        document = copy.deepcopy(gltf)
        original = document["nodes"]
        selected = []

        def visit(index):
            if index in excluded:
                return
            selected.append(index)
            for child in original[index].get("children", []):
                visit(child)

        for root in roots:
            visit(root)
        mapping = {old: new for new, old in enumerate(selected)}
        used_meshes = sorted({original[i]["mesh"] for i in selected if "mesh" in original[i]})
        mesh_map = {old: new for new, old in enumerate(used_meshes)}
        nodes = []
        for index in selected:
            node = original[index]
            node["children"] = [mapping[i] for i in node.get("children", []) if i in mapping]
            if "mesh" in node:
                node["mesh"] = mesh_map[node["mesh"]]
            # Red LED inserts only; don't turn clear reflectors or whole atlases red.
            if index in (105, 164):
                node["name"] = "BrakeLight_" + str(index)
            nodes.append(node)
        nodes.append({"name": name, "translation": shift, "children": [mapping[i] for i in roots]})
        document["nodes"] = nodes
        document["meshes"] = [document["meshes"][i] for i in used_meshes]
        document["scenes"] = [{"nodes": [len(nodes) - 1]}]
        document["scene"] = 0
        (output / (name + ".gltf")).write_text(json.dumps(document, separators=(",", ":")))

    # Original wrapper rotations cancel; root 26/179 and wheel/brake roots are in vehicle space.
    write_scene("golf_body", [26, 179], {28, 181}, [0, shift_y, 0])
    write_scene("golf_wheel", [11], set(), [-v for v in front])
    write_scene("golf_brake", [34], set(), [-v for v in front])
    calibration = {"front_half_track": front[0], "rear_half_track": rear[0],
                   "wheel_y": radius + 0.05, "front_z": front[2], "rear_z": rear[2], "radius": radius}
    (DEST / "calibration.json").write_text(json.dumps(calibration, indent=2) + "\n")
    metadata = json.loads((DEST / "source.json").read_text())
    metadata.update(status="prepared_local_art", model_archive_downloaded=True,
                    archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
                    notes=["User supplied the official downloaded archive, including license.txt.",
                           "First animation keys freeze closed driving pose; airbags removed.",
                           "Body, right wheel and fixed brake separated; source textures retained.",
                           "Third UV-set AO discarded for Godot compatibility.",
                           "Rear brakes reuse front assembly; optional art excluded from Git."])
    (DEST / "source.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps(calibration, indent=2))


if __name__ == "__main__":
    prepare()
