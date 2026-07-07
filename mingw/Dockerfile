FROM debian:testing

# Add i386 architecture for 32-bit builds
RUN dpkg --add-architecture i386

# Install build and test dependencies (matches _ci-linux-debian.sh)
RUN apt-get -qq -o=Dpkg::Use-Pty=0 update && \
    apt-get -qq -o=Dpkg::Use-Pty=0 install -y \
      autoconf automake libtool \
      curl git gpg python3-pip make cmake \
      libssl-dev libio-socket-ssl-perl \
      gcc-mingw-w64 g++-mingw-w64 \
      zip zstd time jq dos2unix \
      wine perl && \
    rm -rf /var/lib/apt/lists/*

# Install pefile (Python PE file parser used during build)
RUN pip3 --disable-pip-version-check install --break-system-packages pefile

# Wine 10+ ships wine64 loader in /usr/lib/wine/ instead of /usr/bin/
RUN ln -sf /usr/lib/wine/wine64 /usr/bin/wine64
