#!/usr/bin/env bash

# 把镜像清单（如 LvscareImageList）里的镜像逐个复制成本地 OCI layout 目录，
# 供离线分发使用。
#
# 用法：mirror_images.bash [IMAGE_LIST] [LAYOUT_DIR]
#
# 环境变量：
#   REGISTRY_MIRROR  拉取时替换镜像的 registry 地址（保留仓库路径），
#                    例如 ghcr.m.daocloud.io；落盘路径始终按原始清单命名
#   PLATFORM         只复制单个平台，例如 linux/amd64；默认留空，
#                    复制完整 index（amd64/arm64/... 全架构都在）。
#                    oras cp --platform 只接受一个平台，填了以后目标 tag
#                    指向单架构 manifest 而不再是 index，多架构请留空。
#   FROM_PLAIN_HTTP  源 registry 走明文 HTTP（oras cp --from-plain-http），
#                    自建无 TLS 的镜像站时置 1/true/yes；默认关闭
#   FROM_INSECURE    跳过源 registry 的 TLS 证书校验（oras cp --from-insecure），
#                    自签证书的镜像站时置 1/true/yes；默认关闭

set -euo pipefail

IMAGE_LIST="${1:-/cpaas/vendor/sealos/LvscareImageList}"
LAYOUT_DIR="${2:-/cpaas/vendor/sealos-images}"

REGISTRY_MIRROR="${REGISTRY_MIRROR:-}"
PLATFORM="${PLATFORM:-}"
FROM_PLAIN_HTTP="${FROM_PLAIN_HTTP:-}"
FROM_INSECURE="${FROM_INSECURE:-}"

flag_enabled() {
    local name="$1" value="${2,,}"
    case "${value}" in
        "" | 0 | false | no) return 1 ;;
        1 | true | yes) return 0 ;;
        *)
            echo "mirror_images: invalid ${name}: $2" >&2
            exit 1
            ;;
    esac
}

cp_args=()
if [[ -n "${PLATFORM}" ]]; then
    cp_args+=(--platform "${PLATFORM}")
fi
if flag_enabled FROM_PLAIN_HTTP "${FROM_PLAIN_HTTP}"; then
    cp_args+=(--from-plain-http)
fi
if flag_enabled FROM_INSECURE "${FROM_INSECURE}"; then
    cp_args+=(--from-insecure)
fi

# 去掉镜像引用前面的 registry 部分
#   ghcr.io/labring/lvscare:v5.1.1 -> labring/lvscare:v5.1.1
strip_registry() {
    local ref="$1" first="${1%%/*}"
    if [[ "$ref" == */* && ( "$first" == *.* || "$first" == *:* || "$first" == "localhost" ) ]]; then
        printf '%s' "${ref#*/}"
    else
        printf '%s' "$ref"
    fi
}

if [[ ! -s "${IMAGE_LIST}" ]]; then
    echo "mirror_images: image list not found or empty: ${IMAGE_LIST}" >&2
    exit 1
fi

mkdir -p "${LAYOUT_DIR}"

count=0
while read -r img _; do
    [[ -z "${img}" || "${img}" == \#* ]] && continue

    repo="$(strip_registry "${img}")"

    src="${img}"
    if [[ -n "${REGISTRY_MIRROR}" ]]; then
        src="${REGISTRY_MIRROR}/${repo}"
    fi
    dst="${LAYOUT_DIR}/${repo}"

    mkdir -p "$(dirname "${dst}")"

    echo "mirror_images: ${src} -> ${dst}"
    oras cp "${cp_args[@]}" "${src}" --to-oci-layout "${dst}"

    count=$((count + 1))
done < "${IMAGE_LIST}"

echo "mirror_images: ${count} image(s) mirrored into ${LAYOUT_DIR}"
