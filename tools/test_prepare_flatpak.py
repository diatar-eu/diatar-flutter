import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "prepare_flatpak", Path(__file__).with_name("prepare-flatpak.py")
)
packaging = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packaging)


class PrepareFlatpakTest(unittest.TestCase):
    def make_archive(self, directory, executable, version="12.3.4", include_library=True):
        archive = directory / "linux.tar.gz"
        files = {
            f"bundle/{executable}": b"executable",
            "bundle/data/flutter_assets/version.json": json.dumps(
                {"version": version, "build_number": "321"}
            ).encode(),
            "bundle/data/flutter_assets/assets/icon/icon.png": b"icon",
            "bundle/lib/libdartjni.so": b"Android-only library",
        }
        if include_library:
            files["bundle/lib/libapp.so"] = b"library"
        with tarfile.open(archive, "w:gz") as output:
            for name, data in files.items():
                entry = tarfile.TarInfo(name)
                entry.size = len(data)
                output.addfile(entry, io.BytesIO(data))
        return archive

    def test_prepares_each_app_using_bundled_version_and_assets(self):
        for app, (app_id, executable) in packaging.APPS.items():
            with self.subTest(app=app), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                archive = self.make_archive(root, executable)
                destination = root / "context"
                packaging.prepare(app, archive, destination)
                metadata = (destination / f"{app_id}.metainfo.xml").read_text()
                self.assertIn('version="12.3.4"', metadata)
                self.assertNotIn("__DATE__", metadata)
                self.assertEqual((destination / "icon.png").read_bytes(), b"icon")
                self.assertEqual(
                    (destination / "bundle" / executable).read_bytes(), b"executable"
                )
                self.assertNotIn(b"\r", (destination / f"{app_id}.desktop").read_bytes())
                self.assertFalse((destination / "bundle/lib/libdartjni.so").exists())

    def test_rejects_missing_release_library_and_invalid_version(self):
        for options in ({"include_library": False}, {"version": "main"}):
            with self.subTest(options=options), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                archive = self.make_archive(root, "diatar_app", **options)
                with self.assertRaises(ValueError):
                    packaging.prepare("Diatar", archive, root / "context")


if __name__ == "__main__":
    unittest.main()
