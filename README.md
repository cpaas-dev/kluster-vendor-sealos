# kluster-vendor-sealos

把上游 sealos 的二进制与 lvscare 镜像重新打包成一个多架构 OCI 镜像，用于离线 / 内网环境分发。

[![Release](https://github.com/cpaas-dev/kluster-vendor-sealos/actions/workflows/release.yml/badge.svg)](https://github.com/cpaas-dev/kluster-vendor-sealos/actions/workflows/release.yml)
[![Scan upstream](https://github.com/cpaas-dev/kluster-vendor-sealos/actions/workflows/scan-upstream.yml/badge.svg)](https://github.com/cpaas-dev/kluster-vendor-sealos/actions/workflows/scan-upstream.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-linux%2Famd64%20%7C%20linux%2Farm64-informational)

```bash
docker pull ghcr.io/cpaas-dev/kluster-vendor-sealos:v5.1.1
```

## 这是什么

离线部署 sealos 集群，需要：

- GitHub Release 上的 sealos 发布件（`sealos` / `sealctl` / `lvscare` / `image-cri-shim`）
- `ghcr.io` 上的 lvscare 镜像，sealos 起 HA 时以静态 Pod 方式运行

本仓库把它们塞进同一个镜像：

- 二进制：按目标架构提供，附构建时生成的 `.sha256sum`
- 镜像：`lvscare`，以 OCI layout 目录落盘，保留完整多架构 index
- 工具：[`oras`](https://github.com/oras-project/oras)，方便直接把 layout 推进到自部署 registry（也推荐使用 zot 来启动一个镜像仓库服务）

## 镜像内容

```plain
/bin/oras                                     # oras CLI，目标架构

/cpaas/vendor/sealos/
├── sealos             sealos.sha256sum       # 目标架构
├── sealctl            sealctl.sha256sum
├── lvscare            lvscare.sha256sum
├── image-cri-shim     image-cri-shim.sha256sum
└── LvscareImageList                          # 运行时需要的 lvscare 镜像引用

/cpaas/vendor/sealos-images/                  # OCI layout 目录
└── labring/lvscare/
```

关于二进制：

```bash
cd /cpaas/vendor/sealos

# 单个
sha256sum -c sealos.sha256sum

# 全部
sha256sum -c *.sha256sum
```

- 取自上游 `sealos_<ver>_linux_<arch>.tar.gz`，原样落盘；上游 tarball 是扁平结构，
  里面只有 `README.md` 和四个二进制，README 不打进镜像
- **上游不发布校验和**：sealos 的 Release 只有 `.tar.gz` / `.deb` / `.rpm`，没有
  `checksums.txt` 或 `.sha256sum`，所以构建时无法比对上游校验和。镜像里的
  `<bin>.sha256sum` 是构建时自行生成的，只能证明"和构建当时下到的字节一致"，
  不构成上游来源证明。这一点和
  [kluster-vendor-containerd](https://github.com/cpaas-dev/kluster-vendor-containerd)
  不同，那边有上游 `.sha256sum` 可比
- `<bin>.sha256sum` 记的是不带路径的文件名，所以在该目录下 `sha256sum -c` 直接可用
- 只含目标架构。`linux/arm64` 的镜像里只有 arm64 的 sealos
- 不含 CRI（containerd）、CNI plugins、Kubernetes 组件，sealos 上游 tarball 本来也不带

关于镜像：

- `LvscareImageList` 一行文本，内容是 `ghcr.io/labring/lvscare:<ver>`，tag 跟 sealos
  版本一致。它不参与 `*.sha256sum` 校验
- layout 目录里保留的是完整 index，amd64 / arm64 都在。也就是说 arm64 镜像里同样带着
  amd64 的 lvscare，可用于多架构的集群
- 推进自部署 registry：

  ```bash
  oras cp --from-oci-layout \
    /cpaas/vendor/sealos-images/labring/lvscare:v5.1.1 \
    my-registry.internal/labring/lvscare:v5.1.1
  ```

## 文档

- [自定义构建](docs/BUILD_YOUR_OWN.md) —— build-args、下载加速、私有 registry
- [发布流程](docs/RELEASE.md) —— tag 规则、定时扫描、本地调试脚本
- [贡献指南](docs/CONTRIBUTING.md)

## 相关仓库

- Sealos <https://github.com/labring/sealos>
- OCI registry client <https://github.com/oras-project/oras>
- Containerd 分发 <https://github.com/cpaas-dev/kluster-vendor-containerd>
- Kubernetes 分发 <https://github.com/cpaas-dev/kluster-vendor-kubernetes>

## 许可

本仓库的构建脚本以 Apache-2.0 发布。打包进镜像的上游产物各自遵循其原始许可：
Sealos（Apache-2.0）、ORAS（Apache-2.0）。
