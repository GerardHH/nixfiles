FROM ubuntu:24.04

RUN [ "$(id --user --name 1000)" = "ubuntu" ] || { \
    echo "uid 1000 is '$(id --user --name 1000)', not 'ubuntu'; flake.nix expects ubuntu." >&2; \
    exit 1; \
    }

# Everything the fixtures in tests/fixtures build with, as the specs run
# where the fixtures were built (`make check`): the C++ toolchain that the
# container profile leaves to the image (languages.c_cpp.provideTools =
# false), and colcon for the colcon workspace. A fixture for another language
# adds its tools here.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
    build-essential \
    ca-certificates \
    clang-format \
    clangd \
    cmake \
    colcon \
    curl \
    git \
    python3-colcon-cmake \
    python3-colcon-recursive-crawl \
    sudo \
    && rm --recursive --force /var/lib/apt/lists/*

RUN echo 'ubuntu ALL=(root) NOPASSWD:ALL' >/etc/sudoers.d/ubuntu \
    && chmod 0440 /etc/sudoers.d/ubuntu

USER ubuntu
