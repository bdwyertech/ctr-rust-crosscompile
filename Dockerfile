FROM rust:slim

RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt \
    apt-get update && apt-get install -y curl git bash xz-utils

# Install Zig
ARG ZIG_VERSION=0.15.2
RUN curl -L "https://ziglang.org/download/${ZIG_VERSION}/zig-$(uname -m)-linux-${ZIG_VERSION}.tar.xz" | tar -J -x -C /usr/local && \
    ln -s "/usr/local/zig-$(uname -m)-linux-${ZIG_VERSION}/zig" /usr/local/bin/zig

RUN cargo install --locked cargo-cross cargo-zigbuild

RUN rustup target add \
    aarch64-apple-darwin \
    x86_64-apple-darwin \
    aarch64-unknown-linux-gnu \
    x86_64-unknown-linux-gnu \
    x86_64-pc-windows-gnu

RUN git clone --depth 1 https://github.com/tpoechtrager/osxcross.git /osxcross

ARG OSX_VERSION_MIN=12.0
ARG OSX_TAR='MacOSX12.sdk.tar.xz'

RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt \
    curl -sfLo /osxcross/tarballs/${OSX_TAR} https://github.com/bdwyertech/dkr-go-crosscompile/releases/download/macsdk/${OSX_TAR} \
    && apt-get update && apt-get install -y build-essential clang cmake libxml2-dev libssl-dev python3 zlib1g-dev \
    && OSX_VERSION_MIN=${OSX_VERSION_MIN} UNATTENDED=1 /osxcross/build.sh \
    && rm -f /osxcross/tarballs/${OSX_TAR} \
    && rm -rf /osxcross/build \
    && apt-get remove -y build-essential clang cmake libxml2-dev libssl-dev python3 zlib1g-dev

# We need LLVM & LLD, as well as cross-compile packages (MinGW for Windows, etc.)
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt \
    apt-get update && apt-get install -y cmake llvm lld \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu gcc-mingw-w64 g++-mingw-w64 \
    && ln -s /usr/bin/clang-19 /usr/bin/clang \
    && ln -s /usr/bin/clang++-19 /usr/bin/clang++

ENV SDK=MacOSX12.sdk
ENV SDKROOT=/osxcross/target/SDK/MacOSX12.sdk
ENV AR_aarch64_apple_darwin=aarch64-apple-darwin21.1-ar
ENV CC_aarch64_apple_darwin=aarch64-apple-darwin21.1-clang
ENV CXX_aarch64_apple_darwin=aarch64-apple-darwin21.1-clang++
# ENV CFLAGS_aarch64_apple_darwin="-stdlib=libc++ -fuse-ld=aarch64-apple-darwin21.1-ld"
# ENV CXXFLAGS_aarch64_apple_darwin="-stdlib=libc++ -fuse-ld=aarch64-apple-darwin21.1-ld"
ENV CFLAGS_aarch64_apple_darwin="-stdlib=libc++ -fuse-ld=lld"
ENV CXXFLAGS_aarch64_apple_darwin="-stdlib=libc++ -fuse-ld=lld"
ENV CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER=aarch64-apple-darwin21.1-clang
ENV BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_darwin="--sysroot=$SDKROOT -idirafter/usr/include"
ENV AR_x86_64_apple_darwin=x86_64-apple-darwin21.1-ar
ENV CC_x86_64_apple_darwin=x86_64-apple-darwin21.1-clang
ENV CXX_x86_64_apple_darwin=x86_64-apple-darwin21.1-clang++
# ENV CFLAGS_x86_64_apple_darwin="-stdlib=libc++ -fuse-ld=x86_64-apple-darwin21.1-ld"
# ENV CXXFLAGS_x86_64_apple_darwin="-stdlib=libc++ -fuse-ld=x86_64-apple-darwin21.1-ld"
ENV CFLAGS_x86_64_apple_darwin="-stdlib=libc++ -fuse-ld=lld"
ENV CXXFLAGS_x86_64_apple_darwin="-stdlib=libc++ -fuse-ld=lld"
ENV CARGO_TARGET_X86_64_APPLE_DARWIN_LINKER=x86_64-apple-darwin21.1-clang
ENV BINDGEN_EXTRA_CLANG_ARGS_x86_64_apple_darwin="--sysroot=$SDKROOT -idirafter/usr/include"

# ENV MACOSX_DEPLOYMENT_TARGET=12.0
# Set environment variables to disable jitter entropy for macOS targets
# ENV AWS_LC_SYS_NO_JITTER_ENTROPY_x86_64_apple_darwin=1
# ENV AWS_LC_SYS_NO_JITTER_ENTROPY_aarch64_apple_darwin=1

ENV LD_LIBRARY_PATH=/osxcross/target/lib
ENV PATH=/osxcross/target/bin:$PATH
