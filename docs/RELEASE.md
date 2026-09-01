## 发布流程

发布 = 一个多架构镜像 + 一个 GitHub Release，由 GitHub Actions 完成。

- 镜像：`ghcr.io/cpaas-dev/kluster-vendor-sealos:<版本>`
- Release：tag 与上游版本号一致，notes 里记录镜像引用、上游 sealos 版本与离线镜像清单

## Tag 规则

`vX.Y.Z` 是一个 manifest list，同时含 `linux/amd64` 与 `linux/arm64`。

```bash
docker pull ghcr.io/cpaas-dev/kluster-vendor-sealos:v5.1.1
docker buildx imagetools inspect ghcr.io/cpaas-dev/kluster-vendor-sealos:v5.1.1
```

## 定时扫描（自动）

`.github/workflows/scan-upstream.yml` 每天 3 次（北京时间 11:43 / 19:43 / 03:43）
扫描 <https://github.com/labring/sealos> 的 Release：

- 取上游最近 5 个正式 release（由 `TRACKED_RELEASES` 控制），按发布时间倒序，不按 minor 分组
- 排除 `draft` / `prerelease`，并要求 tag 严格匹配 `vX.Y.Z`，所以 `rc` / `alpha` / `beta` 不会被构建
- 这 5 个里本仓库还没发过的，才进构建矩阵

sealos 上游 rc / beta 发得很密、正式版很稀疏，`per_page=100` 拿到的 100 条里正式版
可能只有个位数，5 个的窗口够用。

## 手动补发

`.github/workflows/release.yml` 可以 `workflow_dispatch`，`versions` 填逗号分隔的版本
列表。已经有 Release 的版本会被跳过，不会覆盖。

## 调试

本地调试例子：

```bash
# 扫描未发布版本
GH_REPO=cpaas-dev/kluster-vendor-sealos \
  .github/scripts/scan_upstream.bash

# 解析版本矩阵
GH_REPO=cpaas-dev/kluster-vendor-sealos \
  VERSIONS=v5.1.1,v5.1.0 .github/scripts/resolve_versions.bash
```
