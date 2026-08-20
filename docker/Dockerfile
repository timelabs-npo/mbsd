FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    qemu-system-aarch64 \
    python3 \
    python3-pexpect \
    python3-pip \
    genisoimage \
    mtools \
    dosfstools \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY build_kernel.py /build/build_kernel.py
RUN chmod +x /build/build_kernel.py

ENTRYPOINT ["python3", "/build/build_kernel.py"]
