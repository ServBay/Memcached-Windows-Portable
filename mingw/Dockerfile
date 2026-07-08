FROM debian:bookworm

# Pinned to debian:bookworm (stable) for reproducible toolchain + wine.
# debian:testing was a moving target whose wine packaging broke ("wine64" /
# "wine" had no installation candidate), and it would silently drift. wine64
# is required to RUN the cross-compiled .exe for the `make test` / mc-crusher
# self-test, so we need a release where it installs cleanly.

# Add i386 architecture for 32-bit builds
RUN dpkg --add-architecture i386

# Install build and test dependencies (matches _ci-linux-debian.sh).
# NOTE: do NOT add the old `ln -sf /usr/lib/wine/wine64 /usr/bin/wine64` line —
# that was wine-10 specific and would clobber bookworm's real /usr/bin/wine64.
RUN apt-get -qq -o=Dpkg::Use-Pty=0 update && \
    apt-get -qq -o=Dpkg::Use-Pty=0 install -y \
      autoconf automake libtool \
      curl git gpg python3-pip make cmake \
      libssl-dev libio-socket-ssl-perl \
      gcc-mingw-w64 g++-mingw-w64 \
      zip zstd time jq dos2unix \
      wine64 perl && \
    rm -rf /var/lib/apt/lists/*

# Install pefile (Python PE file parser used during build)
RUN pip3 --disable-pip-version-check install --break-system-packages pefile
