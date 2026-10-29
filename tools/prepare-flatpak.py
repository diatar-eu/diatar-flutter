import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import tarfile


APPS = {
    "Diatar": ("eu.diatar.diatar", "diatar_app"),
    "DiaVetito": ("eu.diatar.vetito", "diavetito"),
}


def prepare(app, archive, destination):
    app_id, executable = APPS[app]
    destination.mkdir(parents=True, exist_ok=False)
    with tarfile.open(archive, "r:gz") as source:
        source.extractall(destination, filter="data")

    bundle = destination / "bundle"
    assets = bundle / "data" / "flutter_assets"
    for required in (bundle / executable, bundle / "lib" / "libapp.so"):
        if not required.is_file():
            raise ValueError(f"Missing release bundle file: {required}")
    version = json.loads((assets / "version.json").read_text(encoding="utf-8"))["version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", version):
        raise ValueError(f"Invalid bundled version: {version!r}")

    # Android-only JNI dependencies can emit this unused asset on Linux too.
    # Neither app uses a JVM on Linux; do not ship a library requiring libjvm.so.
    jni_library = bundle / "lib" / "libdartjni.so"
    if jni_library.exists():
        jni_library.unlink()
        print(f"Omitted Android-only JNI asset: {jni_library}")

    templates = Path(__file__).resolve().parent.parent / "flatpak"
    for name in (f"{app_id}.yaml", f"{app_id}.desktop"):
        (destination / name).write_text(
            (templates / name).read_text(encoding="utf-8"), encoding="utf-8", newline="\n"
        )
    metadata = (templates / f"{app_id}.metainfo.xml").read_text(encoding="utf-8")
    metadata = metadata.replace("__VERSION__", version).replace(
        "__DATE__", datetime.now(timezone.utc).date().isoformat()
    )
    (destination / f"{app_id}.metainfo.xml").write_text(metadata, encoding="utf-8")
    shutil.copyfile(assets / "assets" / "icon" / "icon.png", destination / "icon.png")
    print(f"Prepared {app_id} {version} from {archive}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Prepare an existing Linux build for Flatpak.")
    parser.add_argument("app", choices=APPS)
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path)
    arguments = parser.parse_args()
    prepare(arguments.app, arguments.archive, arguments.destination)
