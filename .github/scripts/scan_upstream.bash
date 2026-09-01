#!/usr/bin/env bash

# 扫描上游 sealos 仓库，找出本仓库还没发布的版本。
# 只看上游最近 N 个正式 release，逐个检查本仓库有没有对应的 Release。
#
# sealos 上游 rc / beta 发得很密，正式版很稀疏，所以这里先滤掉预发布再取前 N 个，
# 不分 minor 组，按发布时间倒序。
#
# 用法：scan_upstream.bash
#
# 环境变量：
#   TRACKED_RELEASES  跟踪上游最近多少个正式 release；默认 5
#   UPSTREAM_REPO     上游仓库；默认 labring/sealos
#   GH_TOKEN          gh CLI 凭据
#   GH_REPO           本仓库 cpaas-dev/kluster-vendor-sealos
#
# 输出：
#   $GITHUB_OUTPUT 里的 missing=<逗号分隔版本> 全部已发布时为空串

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

TRACKED_RELEASES="${TRACKED_RELEASES:-5}"
UPSTREAM_REPO="${UPSTREAM_REPO:-labring/sealos}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

# GitHub 的 releases 接口按发布时间倒序返回
gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${UPSTREAM_REPO}/releases?per_page=100" \
    --jq '.[] | select(.draft == false and .prerelease == false) | .tag_name' \
    > "${workdir}/upstream.txt"

# 只要 vX.Y.Z，rc / alpha / beta 这类即使没打 prerelease 标记也挡在外面
grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' "${workdir}/upstream.txt" > "${workdir}/stable.txt" || true
if [[ ! -s "${workdir}/stable.txt" ]]; then
    fail "no stable upstream releases found, ${UPSTREAM_REPO} API response looks wrong"
fi

head -n "${TRACKED_RELEASES}" "${workdir}/stable.txt" > "${workdir}/tracked.txt"

echo "tracked upstream releases (latest ${TRACKED_RELEASES}):"
cat "${workdir}/tracked.txt"

gh release list --limit 500 --json tagName --jq '.[].tagName' \
    > "${workdir}/released.txt"

# 用 grep 而不是 comm，保住上游的时间倒序，新版本排在构建矩阵前面
missing="$(grep -F -x -v -f "${workdir}/released.txt" "${workdir}/tracked.txt" || true)"
missing="$(printf '%s' "${missing}" | paste -sd, -)"

echo "missing=${missing}"
emit_output "missing=${missing}"

{
    echo "### Upstream scan"
    echo
    echo "- tracked (latest ${TRACKED_RELEASES} releases): \`$(paste -sd, - < "${workdir}/tracked.txt")\`"
    if [[ -n "${missing}" ]]; then
        echo "- missing: \`${missing}\`"
    else
        echo "- missing: _none, everything is up to date_"
    fi
} | emit_summary

if [[ -z "${missing}" ]]; then
    echo "up to date, nothing to build"
fi
