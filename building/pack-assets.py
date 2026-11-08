#!/usr/bin/env python3
"""
FMCE - compila la carpeta assets/ en UN solo archivo binario: assets.pack

    python3 building/pack-assets.py                  # assets/ -> building/_pack/assets.pack (+ assets.id)
    python3 building/pack-assets.py --verify         # ademas lo relee y comprueba cada archivo
    python3 building/pack-assets.py --list [PACK]    # lista el contenido de un .pack
    python3 building/pack-assets.py --extract DIR [PACK]   # lo desempaqueta (para revisar / depurar)

Lo llaman building/build.sh, building/build.bat y building/android-build.sh antes de lime.
Project.xml mete building/_pack/assets.pack (y assets.id) en el build; el juego lo lee con funky.core.PackLibrary.

Formato FMPK v1 (little-endian, sin compresion: png/ogg ya vienen comprimidos y asi se lee con seek, sin cargar todo en RAM):

    0   4   "FMPK"
    4   4   u32 version (1)
    8   4   u32 cantidad de archivos
    12  4   u32 tamano del indice en bytes
    16  ..  indice: por archivo  [u16 largo_ruta][ruta utf-8][u32 offset][u32 tamano]
    ..  ..  datos (offset absoluto desde el inicio del archivo)

Las rutas son los IDs de OpenFL tal cual ("assets/images/menus/menuBG.png"), asi que el codigo del juego no cambia.
Limite: 2 GB (el lector de Haxe usa Int de 32 bits con signo).

No entran (Project.xml ya los trata aparte o el juego no los usa):
    fonts/   -> van embebidas en el ejecutable (<assets path="assets/fonts" embed="true"/>)
    *.mp3    -> en nativo se usan los .ogg
    basura   -> .DS_Store, Thumbs.db, *.bak, *.bck, *.tmp
Los videos NO estan en assets/: viven en addons/videos/ (hxvlc necesita un archivo real, no puede leer de un .pack).
"""
import argparse
import fnmatch
import hashlib
import os
import struct
import sys

MAGIC = b"FMPK"
VERSION = 1
MAX_SIZE = 0x7FFFFFFF

DEFAULT_EXCLUDE_DIRS = ["fonts"]
DEFAULT_EXCLUDE_GLOBS = ["*.mp3", ".DS_Store", "Thumbs.db", "*.bak", "*.bck", "*.tmp"]


def collect(src_dir, root_name, exclude_dirs, exclude_globs):
    """[(id, ruta_en_disco)] ordenado por id (el orden fijo hace el .pack reproducible)."""
    entries = []
    src_dir = os.path.normpath(src_dir)
    for base, dirs, files in os.walk(src_dir):
        rel_base = os.path.relpath(base, src_dir).replace(os.sep, "/")
        rel_base = "" if rel_base == "." else rel_base
        # carpetas excluidas, solo las de primer nivel (assets/fonts, no cualquier "fonts" mas adentro)
        if rel_base == "":
            dirs[:] = [d for d in dirs if d not in exclude_dirs]
        dirs.sort()
        for name in sorted(files):
            if any(fnmatch.fnmatch(name, g) for g in exclude_globs):
                continue
            rel = (rel_base + "/" + name) if rel_base else name
            entries.append((root_name + "/" + rel, os.path.join(base, name)))
    entries.sort(key=lambda e: e[0])
    return entries


def build(entries, out_path):
    index_parts = []
    for rid, _ in entries:
        raw = rid.encode("utf-8")
        if len(raw) > 0xFFFF:
            raise SystemExit("ruta demasiado larga: " + rid)
    index_size = sum(2 + len(rid.encode("utf-8")) + 8 for rid, _ in entries)
    data_start = 16 + index_size

    offset = data_start
    sizes = []
    for rid, path in entries:
        size = os.path.getsize(path)
        sizes.append(size)
        index_parts.append(struct.pack("<H", len(rid.encode("utf-8"))) + rid.encode("utf-8")
                           + struct.pack("<II", offset, size))
        offset += size
    if offset > MAX_SIZE:
        raise SystemExit("el .pack pasaria de 2 GB (%d bytes)" % offset)

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    tmp = out_path + ".tmp"
    sha = hashlib.sha1()
    with open(tmp, "wb") as out:
        def put(chunk):
            out.write(chunk)
            sha.update(chunk)

        put(MAGIC + struct.pack("<III", VERSION, len(entries), index_size))
        for part in index_parts:
            put(part)
        for (rid, path), size in zip(entries, sizes):
            with open(path, "rb") as f:
                remaining = size
                while remaining > 0:
                    chunk = f.read(min(1 << 20, remaining))
                    if not chunk:
                        raise SystemExit("el archivo cambio mientras se empaquetaba: " + path)
                    put(chunk)
                    remaining -= len(chunk)
    os.replace(tmp, out_path)
    return sha.hexdigest(), offset


def read_index(pack_path):
    with open(pack_path, "rb") as f:
        head = f.read(16)
        if len(head) < 16 or head[:4] != MAGIC:
            raise SystemExit(pack_path + ": no es un .pack de FMCE")
        version, count, index_size = struct.unpack("<III", head[4:])
        if version != VERSION:
            raise SystemExit("%s: version %d no soportada (este script es v%d)" % (pack_path, version, VERSION))
        raw = f.read(index_size)
    entries = []
    pos = 0
    for _ in range(count):
        (n,) = struct.unpack_from("<H", raw, pos)
        pos += 2
        rid = raw[pos:pos + n].decode("utf-8")
        pos += n
        offset, size = struct.unpack_from("<II", raw, pos)
        pos += 8
        entries.append((rid, offset, size))
    if pos != index_size:
        raise SystemExit(pack_path + ": indice corrupto")
    return entries


def verify(pack_path, entries):
    total = os.path.getsize(pack_path)
    bad = 0
    with open(pack_path, "rb") as pack:
        for (rid, path), (prid, offset, size) in zip(entries, read_index(pack_path)):
            if rid != prid or size != os.path.getsize(path) or offset + size > total:
                print("  MAL (indice):", rid)
                bad += 1
                continue
            pack.seek(offset)
            if hashlib.sha1(pack.read(size)).digest() != hashlib.sha1(open(path, "rb").read()).digest():
                print("  MAL (contenido):", rid)
                bad += 1
    return bad


def main():
    ap = argparse.ArgumentParser(description="Compila assets/ en assets.pack")
    ap.add_argument("--src", default="assets", help="carpeta a empaquetar (por defecto assets)")
    ap.add_argument("--root", default=None, help="prefijo de los IDs (por defecto el nombre de --src)")
    ap.add_argument("--out", default=os.path.join("building", "_pack"), help="carpeta de salida")
    ap.add_argument("--exclude-dir", action="append", default=None, help="carpeta de primer nivel a omitir (repetible)")
    ap.add_argument("--exclude", action="append", default=None, help="patron de nombre de archivo a omitir (repetible)")
    ap.add_argument("--verify", action="store_true", help="releer el .pack y comprobar cada archivo")
    ap.add_argument("--list", nargs="?", const="", metavar="PACK", help="listar un .pack")
    ap.add_argument("--extract", nargs="+", metavar=("DIR", "PACK"), help="desempaquetar: DIR [PACK]")
    args = ap.parse_args()

    default_pack = os.path.join(args.out, "assets.pack")

    if args.list is not None:
        pack = args.list or default_pack
        for rid, offset, size in read_index(pack):
            print("%10d  %s" % (size, rid))
        return 0

    if args.extract:
        dest = args.extract[0]
        pack = args.extract[1] if len(args.extract) > 1 else default_pack
        with open(pack, "rb") as f:
            for rid, offset, size in read_index(pack):
                target = os.path.normpath(os.path.join(dest, rid))
                if not target.startswith(os.path.normpath(dest) + os.sep):
                    raise SystemExit("ruta sospechosa en el .pack: " + rid)
                os.makedirs(os.path.dirname(target), exist_ok=True)
                f.seek(offset)
                with open(target, "wb") as out:
                    out.write(f.read(size))
        print("desempaquetado en", dest)
        return 0

    if not os.path.isdir(args.src):
        print("pack-assets: no existe la carpeta '%s' (ejecuta el script desde la raiz del proyecto)" % args.src, file=sys.stderr)
        return 1

    root = args.root or os.path.basename(os.path.normpath(args.src))
    ex_dirs = DEFAULT_EXCLUDE_DIRS if args.exclude_dir is None else args.exclude_dir
    ex_globs = DEFAULT_EXCLUDE_GLOBS if args.exclude is None else args.exclude

    entries = collect(args.src, root, ex_dirs, ex_globs)
    if not entries:
        print("pack-assets: '%s' esta vacio" % args.src, file=sys.stderr)
        return 1

    pack_path = os.path.join(args.out, "assets.pack")
    digest, total = build(entries, pack_path)

    # assets.id: lo que el juego compara para saber si el .pack empaquetado cambio (Android lo extrae del APK una sola vez)
    with open(os.path.join(args.out, "assets.id"), "w", newline="\n") as f:
        f.write(digest + "\n")

    print("pack-assets: %d archivos -> %s (%.1f MB, id %s)" % (len(entries), pack_path, total / 1048576.0, digest[:12]))

    if args.verify:
        bad = verify(pack_path, entries)
        if bad:
            print("pack-assets: %d archivos con error" % bad, file=sys.stderr)
            return 1
        print("pack-assets: verificado")
    return 0


if __name__ == "__main__":
    sys.exit(main())
