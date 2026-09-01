## 打包

```bash
# 构建多架构镜像 amd64/arm64
docker buildx build --platform linux/amd64,linux/arm64 \
  -t xxx .
```

## 指定版本

```bash
docker buildx build \
  --build-arg INST_SEALOS_V=v5.1.1 \
  -t ...
```

## 下载加速

sealos 的 tarball 单个 70~80 MB，两个架构都要下，慢的话优先换源。

```bash
# 国内访问加速
docker buildx build \
  --build-arg GITHUB_URL=https://gh-proxy.org/https://github.com \
  --build-arg REGISTRY_MIRROR=ghcr.m.daocloud.io \
  -t ...

# 本地自建 Nexus 代理
docker buildx build \
  --build-arg GITHUB_URL=https://nexus-mirror.alpha-quant.tech/repository/github \
  --build-arg REGISTRY_MIRROR=nexus-mirror.alpha-quant.tech:9605 \
  --build-arg REGISTRY_MIRROR_PLAIN_HTTP=true \
  -t ...
```

Registry Mirror 支持以下 build-args：

```bash
# 仓库地址，默认 ghcr.io；只影响拉取，落盘路径始终按原始清单命名
REGISTRY_MIRROR

# HTTP 仓库
REGISTRY_MIRROR_PLAIN_HTTP=true

# 不安全仓库
REGISTRY_MIRROR_INSECURE=true
```

## 其他 build-args

```bash
# 基础镜像
BASE_IMAGE=docker.io/rockylinux/rockylinux:10.2.20260525.0

# oras 版本
INST_ORAS_V=v1.3.3

# 下载哪些架构的二进制，空格分隔。
# 最终镜像只装 TARGETARCH，这里改小只能省下载量，改小于目标架构集合会构建失败
VENDOR_ARCHES="amd64 arm64"
```
