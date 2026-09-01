# syntax=docker.io/docker/dockerfile:1.25.0

ARG BASE_IMAGE=docker.io/rockylinux/rockylinux:10.2.20260525.0

FROM --platform=${BUILDPLATFORM} ${BASE_IMAGE} AS base

ARG GITHUB_URL=https://github.com
# ARG GITHUB_URL=https://gh-proxy.org/https://github.com
# ARG GITHUB_URL=https://nexus-mirror.alpha-quant.tech/repository/github

ARG BUILDARCH

# sealos
# https://github.com/labring/sealos/releases
ARG INST_SEALOS_V=v5.1.1

# oras
# https://github.com/oras-project/oras/releases
ARG INST_ORAS_V=v1.3.3

ARG VENDOR_ARCHES="amd64 arm64"

ENV \
    GITHUB_URL=${GITHUB_URL} \
    INST_SEALOS_V=${INST_SEALOS_V} \
    INST_ORAS_V=${INST_ORAS_V} \
    VENDOR_ARCHES=${VENDOR_ARCHES}

RUN --mount=type=cache,target=/tmp,id=build-tmp,sharing=locked \
    \
    true \
    && curl --fail -sL -m 300 \
    ${GITHUB_URL}/oras-project/oras/releases/download/${INST_ORAS_V}/oras_${INST_ORAS_V/v/}_linux_${BUILDARCH}.tar.gz \
    -o /tmp/oras_${INST_ORAS_V/v/}_linux_${BUILDARCH}.tar.gz \
    && tar zxf /tmp/oras_${INST_ORAS_V/v/}_linux_${BUILDARCH}.tar.gz -C /tmp oras \
    && mv /tmp/oras /bin/ && chmod +x /bin/oras \
    && true

# ---------------------------------------------------------------------------
# binaries
#    /cpaas/vendor/sealos/<arch>/{sealos,sealctl,lvscare,image-cri-shim}
#    /cpaas/vendor/sealos/<arch>/<bin>.sha256sum
#    /cpaas/vendor/sealos/LvscareImageList
#    /cpaas/vendor/oras/<arch>/oras
#
# ---------------------------------------------------------------------------
FROM --platform=${BUILDPLATFORM} base AS binaries

RUN --mount=type=cache,target=/tmp,id=build-tmp,sharing=locked \
    set -eu \
    && ver="${INST_SEALOS_V#v}" \
    && for arch in ${VENDOR_ARCHES}; do \
    tarball="sealos_${ver}_linux_${arch}.tar.gz" ; \
    dst="/cpaas/vendor/sealos/${arch}" ; \
    base_url="${GITHUB_URL}/labring/sealos/releases/download/${INST_SEALOS_V}" ; \
    curl --fail -sL -m 600 --retry 3 --retry-delay 5 \
    "${base_url}/${tarball}" -o "/tmp/${tarball}" ; \
    mkdir -p "${dst}" ; \
    tar zxf "/tmp/${tarball}" -C "${dst}" \
    sealos sealctl lvscare image-cri-shim ; \
    chmod +x "${dst}"/* ; \
    ( cd "${dst}" && for f in * ; do sha256sum "${f}" > "${f}.sha256sum" ; done ) ; \
    done

RUN --mount=type=cache,target=/tmp,id=build-tmp,sharing=locked \
    set -eu \
    && for arch in ${VENDOR_ARCHES}; do \
    tarball="oras_${INST_ORAS_V#v}_linux_${arch}.tar.gz" ; \
    dst="/cpaas/vendor/oras/${arch}" ; \
    mkdir -p "${dst}" ; \
    curl --fail -sL -m 300 --retry 3 --retry-delay 5 \
    "${GITHUB_URL}/oras-project/oras/releases/download/${INST_ORAS_V}/${tarball}" \
    -o "/tmp/${tarball}" ; \
    tar zxf "/tmp/${tarball}" -C "${dst}" oras ; \
    chmod +x "${dst}/oras" ; \
    done

# sealos 起 HA 时以静态 Pod 方式跑 lvscare，镜像 tag 跟 sealos 版本一致
RUN echo "ghcr.io/labring/lvscare:${INST_SEALOS_V}" \
    | tee /cpaas/vendor/sealos/LvscareImageList

RUN set -eu \
    && for arch in ${VENDOR_ARCHES}; do \
    dst="/cpaas/vendor/sealos/${arch}" ; \
    for bin in sealos sealctl lvscare image-cri-shim; do \
    test -x "${dst}/${bin}" \
    || { echo "missing binary: ${arch}/${bin}" >&2; exit 1; } ; \
    test -s "${dst}/${bin}.sha256sum" \
    || { echo "missing checksum: ${arch}/${bin}.sha256sum" >&2; exit 1; } ; \
    done ; \
    test -x "/cpaas/vendor/oras/${arch}/oras" \
    || { echo "missing binary: ${arch}/oras" >&2; exit 1; } ; \
    ( cd "${dst}" && sha256sum --check --strict ./*.sha256sum ) ; \
    done

# ---------------------------------------------------------------------------
# images
#    /cpaas/vendor/sealos-images/labring/lvscare   OCI layout，保留完整多架构 index
# ---------------------------------------------------------------------------
FROM --platform=${BUILDPLATFORM} base AS images

ARG REGISTRY_MIRROR=ghcr.io
# ARG REGISTRY_MIRROR=ghcr.m.daocloud.io
# ARG REGISTRY_MIRROR=nexus-mirror.alpha-quant.tech:9605

ARG REGISTRY_MIRROR_PLAIN_HTTP=
# ARG REGISTRY_MIRROR_PLAIN_HTTP=true

ARG REGISTRY_MIRROR_INSECURE=
# ARG REGISTRY_MIRROR_INSECURE=true

COPY --from=binaries \
    /cpaas/vendor/sealos/LvscareImageList \
    /cpaas/vendor/sealos/LvscareImageList
COPY --chmod=755 mirror_images.bash /usr/local/bin/mirror_images.bash

RUN REGISTRY_MIRROR=${REGISTRY_MIRROR} \
    FROM_PLAIN_HTTP=${REGISTRY_MIRROR_PLAIN_HTTP} \
    FROM_INSECURE=${REGISTRY_MIRROR_INSECURE} \
    PLATFORM= \
    /usr/local/bin/mirror_images.bash \
    /cpaas/vendor/sealos/LvscareImageList \
    /cpaas/vendor/sealos-images

# ---------------------------------------------------------------------------
# target
# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE}

ARG TARGETARCH

# sealos
# https://github.com/labring/sealos/releases
ARG INST_SEALOS_V=v5.1.1

ENV INST_SEALOS_V=${INST_SEALOS_V}

COPY --from=binaries /cpaas/vendor/oras/${TARGETARCH}/oras /bin/oras
COPY --from=binaries /cpaas/vendor/sealos/LvscareImageList /cpaas/vendor/sealos/LvscareImageList
COPY --from=binaries /cpaas/vendor/sealos/${TARGETARCH}/ /cpaas/vendor/sealos/
COPY --from=images /cpaas/vendor/sealos-images /cpaas/vendor/sealos-images

LABEL \
    org.opencontainers.image.title="kluster-vendor-sealos" \
    org.opencontainers.image.description="Upstream sealos binaries repackaged as OCI artifacts" \
    org.opencontainers.image.version="${INST_SEALOS_V}" \
    org.opencontainers.image.source="https://github.com/cpaas-dev/kluster-vendor-sealos" \
    org.opencontainers.image.vendor="Kluster" \
    org.opencontainers.image.licenses="Apache-2.0"
