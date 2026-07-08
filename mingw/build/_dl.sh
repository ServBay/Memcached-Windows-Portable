#!/bin/sh -x

export MEMCACHED_VER_='1.6.8'
export MEMCACHED_DATE_VER_='' # Dynamically resolved based on MEMCACHED_VER_
export MC_CRUSHER_VER_='master'
export LIBEVENT_VER_='' # Dynamically resolved based on latest release
[ -z "${CURL_VER_}" ] && CURL_VER_='latest'
export OPENSSL_VER_='' # Dynamically resolved based on curl release
export OSSLSIGNCODE_VER_='1.7.1'
export OSSLSIGNCODE_HASH=f9a8cdb38b9c309326764ebc937cba1523a3a751a7ab05df3ecc99d18ae466c9

# Create revision string
# NOTE: Set _REV to empty after bumping CURL_VER_, and
#       set it to 1 then increment by 1 each time bumping a dependency
#       version or pushing a CI rebuild for the master branch.
export _REV=''

[ -z "${_REV}" ] || _REV="_${_REV}"

echo "Build: REV(${_REV})"

# Quit if any of the lines fail
set -e

# Detect host OS
case "$(uname)" in
  *_NT*)   os='win';;
  Linux*)  os='linux';;
  Darwin*) os='mac';;
  *BSD)    os='bsd';;
esac

# Install required component
# TODO: add `--progress-bar off` when pip 10.0.0 is available
if [ "${os}" != 'win' ]; then
  pip3 --version
  pip3 --disable-pip-version-check install --user --break-system-packages pefile
fi

alias curl='curl -fsSR --connect-timeout 15 -m 20 --retry 3'
alias wget='wget -nv --timeout=15 --tries=3 --https-only'

gpg_recv_key() {
  # https://keys.openpgp.org/about/api
  req="pks/lookup?op=get&options=mr&exact=on&search=0x$1"
# curl "https://keys.openpgp.org/${req}"     | gpg --import --status-fd 1 || \
  curl "https://pgpkeys.eu/${req}"           | gpg --import --status-fd 1 || \
  curl "https://keyserver.ubuntu.com/${req}" | gpg --import --status-fd 1
}

if [ "${_BRANCH#*dev*}" != "${_BRANCH}" ]; then
  _patsuf='.dev'
elif [ "${_BRANCH#*master*}" = "${_BRANCH}" ]; then
  _patsuf='.test'
else
  _patsuf=''
fi

# libevent
LIBEVENT_LATEST_URL=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/libevent/libevent/releases/latest)
LIBEVENT_VER_=$(basename "${LIBEVENT_LATEST_URL}" | sed -e "s/^release-//")
curl -o pack.bin -L --proto-redir =https "https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VER_}/libevent-${LIBEVENT_VER_}.tar.gz" || exit 1
openssl dgst -sha256 pack.bin | grep -q "${LIBEVENT_HASH}" || exit 1
tar -xvf pack.bin >/dev/null 2>&1 || exit 1
rm pack.bin
rm -f -r libevent && mv libevent-* libevent
[ -f "libevent${_patsuf}.patch" ] && dos2unix < "libevent${_patsuf}.patch" | patch --batch -N -p1 -d libevent

# Build LibreSSL from source with THIS toolchain's mingw runtime, instead of
# extracting curl's prebuilt one. curl's prebuilt libssl/libcrypto were built
# against a newer mingw runtime and reference symbols (e.g.
# __guard_dispatch_icall_fptr, __memcpy_chk, fstat64) that stable distros
# (debian:bookworm, ubuntu-24.04) don't provide, so libevent's openssl link
# test failed on anything but debian:testing. A source build matches the local
# runtime exactly and links cleanly everywhere.
dl_openssl_bin() {
  OPENSSL_CPU=$1
  case "${OPENSSL_CPU}" in
    64) _ossl_triplet='x86_64-w64-mingw32' ;;
    32) _ossl_triplet='i686-w64-mingw32' ;;
    *)  echo "dl_openssl_bin: bad CPU '${OPENSSL_CPU}'"; exit 1 ;;
  esac

  LIBRESSL_VER_='4.3.2'
  export SSL_PREFIX_=libressl
  OPENSSL_VER_="${LIBRESSL_VER_}"

  rm -rf "libressl-${LIBRESSL_VER_}.tar.gz" "libressl-${LIBRESSL_VER_}" \
         libressl-*-win${OPENSSL_CPU}-mingw* openssl-*-win${OPENSSL_CPU}-mingw*

  curl -o "libressl-${LIBRESSL_VER_}.tar.gz" -L --proto-redir =https \
    "https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VER_}.tar.gz" || exit 1
  tar xzf "libressl-${LIBRESSL_VER_}.tar.gz"

  SSL_DIR="libressl-${LIBRESSL_VER_}-win${OPENSSL_CPU}-mingw"
  (
    cd "libressl-${LIBRESSL_VER_}"
    # Cross-compile static libs only; skip the openssl CLI/tests to keep it lean
    # and avoid cross-run issues. The triplet selects the mingw compiler.
    ./configure \
      --host="${_ossl_triplet}" \
      --prefix="$(pwd)/../${SSL_DIR}" \
      --enable-static --disable-shared \
      --disable-hardening
    make -j2
    make install
  )

  # Archive the SSL library (parity with the original artifact set)
  tar -c --owner=0 --group=0 --numeric-owner --mode=go=rX,u+rw,a-s "${SSL_DIR}" | xz > "${SSL_DIR}.tar.xz"
  zip -q -9 -r "${SSL_DIR}.zip" "${SSL_DIR}"
  touch -c -r "libressl-${LIBRESSL_VER_}.tar.gz" "${SSL_DIR}.tar.xz" "${SSL_DIR}.zip"
}

# OpenSSL
if [ -n "$CPU" ]; then
  dl_openssl_bin "${CPU}"
else
  dl_openssl_bin 64
  dl_openssl_bin 32
fi

# Official memcached to be used in timestamping since it has no Changelog that can be used as reference
UPSTREAM_DIR="memcached-${MEMCACHED_VER_}"
rm -rf "${UPSTREAM_DIR}"
git clone --branch ${MEMCACHED_VER_} --depth=1 https://github.com/memcached/memcached.git "${UPSTREAM_DIR}"
cd "${UPSTREAM_DIR}"
export MEMCACHED_DATE_VER_="$(git log --date=format:'%Y%m%d%H%M' -1 | sed '3q;d' | awk -F ' ' '{print $2}')"
cd ..
echo "memcached upstream version: ${MEMCACHED_VER_} date: ${MEMCACHED_DATE_VER_}"

# Download mc-crusher if enabled
if [ -n "${CRUSHER_TEST}" ]; then
  curl -o mc-crusher-${MC_CRUSHER_VER_}.zip -L --proto-redir =https "https://github.com/memcached/mc-crusher/archive/${MC_CRUSHER_VER_}.zip" || exit 1
fi

# Download Coverity Scan Self-Build Tool
if [ -n "${COVERITY_SCAN}" ]; then
  wget https://scan.coverity.com/download/linux64 --post-data "token=${COVERITY_TOKEN}&project=${COVERITY_PROJECT}" -O coverity_tool.tgz
  tar -xvf coverity_tool.tgz >/dev/null 2>&1 || exit 1
  rm coverity_tool.tgz
  rm -f -r cov-analysis && mv cov-analysis-* cov-analysis
fi

# Download coverage uploader
if [ -z "${CODECOV_DISABLE}" ]; then
  curl -o codecov.sh -L --proto-redir =https "https://codecov.io/bash" || exit 1
fi

# osslsigncode (only needed for code signing; non-fatal if unavailable)
# NOTE: "https://github.com/mtrojnar/osslsigncode/archive/${OSSLSIGNCODE_VER_}.tar.gz"
if curl -o pack.bin -L --proto-redir =https "https://deb.debian.org/debian/pool/main/o/osslsigncode/osslsigncode_${OSSLSIGNCODE_VER_}.orig.tar.gz" 2>/dev/null; then
  openssl dgst -sha256 pack.bin | grep -q "${OSSLSIGNCODE_HASH}" || exit 1
  tar -xvf pack.bin >/dev/null 2>&1 || exit 1
  rm pack.bin
  rm -f -r osslsigncode && mv osslsigncode-${OSSLSIGNCODE_VER_} osslsigncode
  [ -f 'osslsigncode.patch' ] && dos2unix < 'osslsigncode.patch' | patch --batch -N -p1 -d osslsigncode
else
  rm -f pack.bin
  echo "WARNING: osslsigncode ${OSSLSIGNCODE_VER_} unavailable; code signing will be skipped"
fi

set +e

rm -f pack.bin pack.sig
