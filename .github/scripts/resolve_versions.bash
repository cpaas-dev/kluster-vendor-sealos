#!/usr/bin/env bash

# 解析并校验待发布的版本列表，产出构建矩阵。
#
# 已经有 GitHub Release 的版本不会再次构建
# 矩阵为空时后续 job 直接跳过
#
# 用法：resolve_versions.bash
#
# 环境变量：
#   VERSIONS       必填，逗号分隔的版本列表，如 "v5.1.1,v5.1.0"
#                  只接受正式版 vMAJOR.MINOR.PATCH，带 -rc/-alpha/-beta 一律拒绝
#   GH_TOKEN       gh CLI 凭据
#   GH_REPO        目标仓库，如 cpaas-dev/kluster-vendor-sealos
#
# 输出：
#   $GITHUB_OUTPUT 里的 matrix=<JSON 数组>，如 ["v5.1.1"] 或 []

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

VERSIONS="${VERSIONS:-}"

mapfile -t versions < <(
    printf '%s' "${VERSIONS}" \
        | tr ',' '\n' \
        | tr -d '[:blank:]\r' \
        | grep -v '^$' \
        | awk '!seen[$0]++'
)

if [[ ${#versions[@]} -eq 0 ]]; then
    fail "no versions provided (set VERSIONS)"
fi

wanted=()
for v in "${versions[@]}"; do
    if [[ ! "${v}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        fail "invalid or pre-release version: ${v} (expected vMAJOR.MINOR.PATCH)"
    fi

    if gh release view "${v}" --json tagName >/dev/null 2>&1; then
        echo "skip: ${v} already released"
        continue
    fi

    wanted+=("${v}")
done

matrix="$(printf '%s\n' "${wanted[@]+"${wanted[@]}"}" | jq -R . | jq -c -s 'map(select(length > 0))')"

echo "matrix=${matrix}"
emit_output "matrix=${matrix}"

{
    echo "### Release plan"
    echo
    echo "- requested: \`${versions[*]}\`"
    echo "- to build: \`${matrix}\`"
} | emit_summary

if [[ "${matrix}" == "[]" ]]; then
    echo "nothing to do, all requested versions are already released"
fi
