FROM ubuntu:22.04

ARG LOLMINER_VERSION=1.98a
ARG XMRIG_VERSION=6.26.0
ARG SRBMINER_VERSION=3.8.0

ENV DEBIAN_FRONTEND=noninteractive \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl tar \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/miners

# lolMiner (NVIDIA/AMD GPU)
RUN mkdir lolminer \
 && curl -fsSL "https://github.com/Lolliedieb/lolMiner-releases/releases/download/${LOLMINER_VERSION}/lolMiner_v${LOLMINER_VERSION}_Lin64.tar.gz" \
    | tar -xz -C lolminer --strip-components=1 \
 && test -x lolminer/lolMiner

# XMRig (CPU, RandomX etc.)
RUN mkdir xmrig \
 && curl -fsSL "https://github.com/xmrig/xmrig/releases/download/v${XMRIG_VERSION}/xmrig-${XMRIG_VERSION}-linux-static-x64.tar.gz" \
    | tar -xz -C xmrig --strip-components=1 \
 && test -x xmrig/xmrig

# SRBMiner-Multi (CPU + GPU, many algorithms)
RUN mkdir srbminer \
 && curl -fsSL "https://github.com/doktor83/SRBMiner-Multi/releases/download/${SRBMINER_VERSION}/SRBMiner-Multi-$(echo ${SRBMINER_VERSION} | tr . -)-Linux.tar.gz" \
    | tar -xz -C srbminer --strip-components=1 \
 && test -x srbminer/SRBMiner-MULTI

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
