FROM debian:testing

# Add i386 architecture for 32-bit builds
RUN dpkg --add-architecture i386

# Install build dependencies. NOTE: wine is intentionally NOT installed here:
# in current debian:testing neither `wine64` nor `wine` has an installation
# candidate, and wine is only needed to RUN the built .exe for `make test` /
# mc-crusher — it is not needed to cross-compile the binary. The release
# workflow therefore builds with BUILD_ONLY=1. Re-add wine (from a working
# source) in a follow-up to restore the runtime self-test.
RUN apt-get -qq -o=Dpkg::Use-Pty=0 update && \
    apt-get -qq -o=Dpkg::Use-Pty=0 install -y \
      autoconf automake libtool \
      curl git gpg python3-pip make cmake \
      libssl-dev libio-socket-ssl-perl \
      gcc-mingw-w64 g++-mingw-w64 \
      zip zstd time jq dos2unix \
      perl && \
    rm -rf /var/lib/apt/lists/*

# Install pefile (Python PE file parser used during build)
RUN pip3 --disable-pip-version-check install --break-system-packages pefile
