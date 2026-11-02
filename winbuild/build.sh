#!/bin/bash
# Build OpenOCD (MSYS2 UCRT64) from the repository tree. Normally called from build.ps1.
# Arguments: <build name> <reconfigure 0|1> <clean 0|1>
#   build/<name>/  - build directory (out of the source tree)
#   bin/<name>/    - resulting openocd.exe + the DLLs it needs
set -eu

# Plain ASCII English tool output. With a Russian Windows locale MSYS2 prints UTF-8, which the
# PowerShell console decodes as the OEM code page (mojibake in the console and in logs).
export LC_ALL=C LANG=C

NAME=${1:-base}
RECONF=${2:-0}
CLEAN=${3:-0}

if [ -n "${WB_ROOT:-}" ]; then
	WB=$(cygpath -u "$WB_ROOT")
else
	WB=$(cd "$(dirname "$0")" && pwd)
fi
SRC=$(dirname "$WB")		# repository root

export PATH=/ucrt64/bin:$PATH
export ACLOCAL_PATH=/ucrt64/share/aclocal

# git from MSYS2 complains about "dubious ownership" (the directory is owned by Administrators).
# This only touches the HOME of this toolchain (winbuild/toolchain/msys64/home/...), not your profile.
for d in "$SRC" "$SRC/jimtcl"; do
	git config --global --get-all safe.directory | grep -qxF "$d" || git config --global --add safe.directory "$d"
done

cd "$SRC"

# A fresh clone has an empty jimtcl submodule; initialize it on demand.
if [ ! -f "$SRC/jimtcl/configure" ]; then
	echo "=== submodule jimtcl"
	git -C "$SRC" submodule update --init jimtcl
fi

if grep -q $'\r' configure.ac; then
	echo "ERROR: configure.ac has CRLF line endings. The tree must be LF, see winbuild/README.md (LF section)." >&2
	exit 1
fi

if [ ! -f configure ] || [ "$RECONF" = 1 ]; then
	echo "=== bootstrap"
	./bootstrap nosubmodule
fi

OUT=$WB/build/$NAME
if [ "$CLEAN" = 1 ]; then
	rm -rf "$OUT"
fi
mkdir -p "$OUT"
cd "$OUT"
if [ ! -f Makefile ] || [ "$RECONF" = 1 ]; then
	echo "=== configure"
	"$SRC/configure" --enable-internal-jimtcl --enable-usb-blaster --enable-usb-blaster-2 \
		--disable-jlink --disable-internal-libjaylink --disable-werror
fi

echo "=== make"
make -j"$(nproc)"

BIN=$WB/bin/$NAME
mkdir -p "$BIN"
cp src/openocd.exe "$BIN/"
ldd src/openocd.exe | awk '$3 ~ /^\/ucrt64\// { print $3 }' | while read -r dll; do
	cp "$dll" "$BIN/"
done
echo "=== done: $BIN/openocd.exe"
