#!/usr/bin/env python3
"""Regenera los zips de addons antes de cada commit.

Lo llama commit.sh. La salida es byte-idéntica si los archivos de entrada no
cambiaron (fechas fijas, orden estable y permisos fijos), así que no genera
commits fantasma: solo actualiza los zips cuando hay cambios reales.
"""

from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
ADDONS = ROOT / "addons"

# carpeta -> zip dentro de addons/
TARGETS = (
	("hudskins", "hudskins.zip"),
	("videos", "videos.zip"),
)

FIXED_DATE = (1980, 1, 1, 0, 0, 0)
FIXED_ATTR = 0o100644 << 16


def rebuild(folder: str, zip_name: str) -> bool:
	src = ADDONS / folder
	out = ADDONS / zip_name

	if not src.is_dir():
		print(f"update_addon_zips: falta {src}, se omite {zip_name}")
		return False

	files = sorted(
		path
		for path in src.rglob("*")
		if path.is_file()
		and not any(part.startswith(".") for part in path.relative_to(src).parts)
	)

	tmp = out.with_name(out.name + ".tmp")
	with zipfile.ZipFile(tmp, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
		for path in files:
			info = zipfile.ZipInfo(path.relative_to(ADDONS).as_posix(), FIXED_DATE)
			info.compress_type = zipfile.ZIP_DEFLATED
			info.create_system = 3
			info.external_attr = FIXED_ATTR
			zf.writestr(info, path.read_bytes())

	changed = not out.exists() or tmp.read_bytes() != out.read_bytes()
	if changed:
		tmp.replace(out)
		print(f"update_addon_zips: actualizado {zip_name} ({len(files)} archivos)")
	else:
		tmp.unlink()
	return changed


def main() -> int:
	changed = False
	for folder, zip_name in TARGETS:
		changed |= rebuild(folder, zip_name)
	if not changed:
		print("update_addon_zips: zips al dia")
	return 0


if __name__ == "__main__":
	sys.exit(main())
