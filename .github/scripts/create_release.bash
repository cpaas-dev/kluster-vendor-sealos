#!/usr/bin/env bash

# 创建 GitHub Release，notes 里记录镜像引用、上游 sealos 版本与离线镜像清单。
#
# 用法：create_release.bash VERSION IMAGE_REF
#
# 参数：
#   VERSION     sealos 版本，如 v5.1.1
#   IMAGE_REF   已推送的镜像引用，如 ghcr.io/foo/bar:v5.1.1
#
# 环境变量：
#   GH_TOKEN      gh CLI 凭据
#   GH_REPO       目标仓库
#   GITHUB_SHA    Release 指向的 commit；留空则由 gh 用默认分支
#   UPSTREAM_REPO 上游仓库，用于生成链接；默认 labring/sealos

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

V="${1:-}"
REF="${2:-}"
UPSTREAM_REPO="${UPSTREAM_REPO:-labring/sealos}"

if [[ -z "${V}" || -z "${REF}" ]]; then
    echo "usage: create_release.bash VERSION IMAGE_REF" >&2
    exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

if gh release view "${V}" --json tagName >/dev/null 2>&1; then
    echo "skip: ${V} already released, refusing to overwrite"
    exit 0
fi

# 与 Dockerfile 里写进 LvscareImageList 的内容保持一致
echo "ghcr.io/labring/lvscare:${V}" > "${workdir}/LvscareImageList"

{
    echo "Upstream sealos \`${V}\` repackaged as an OCI artifact."
    echo
    echo "## 镜像"
    echo
    echo '```bash'
    echo "docker pull ${REF}"
    echo '```'
    echo
    echo "## 上游版本"
    echo
    echo "Sealos [\`${V}\`](https://github.com/${UPSTREAM_REPO}/releases/tag/${V})"
    echo
    echo "## 二进制"
    echo
    echo '```plain'
    echo "sealos sealctl lvscare image-cri-shim"
    echo '```'
    echo
    echo "## 离线镜像清单"
    echo
    echo '```plain'
    cat "${workdir}/LvscareImageList"
    echo '```'
} > "${workdir}/notes.md"

create_args=(
    "${V}"
    --title "${V}"
    --notes-file "${workdir}/notes.md"
)

if [[ -n "${GITHUB_SHA:-}" ]]; then
    create_args+=(--target "${GITHUB_SHA}")
fi

gh release create "${create_args[@]}"

{
    echo "### Released ${V}"
    echo
    echo "- image: \`${REF}\`"
    echo "- release: ${GITHUB_SERVER_URL:-https://github.com}/${GH_REPO:-}/releases/tag/${V}"
} | emit_summary
