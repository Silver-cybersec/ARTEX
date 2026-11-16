# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#
# 运行镜像（不在镜像里编译）：只装常用工具，放入**预编译好的 Linux 单二进制**。
# 二进制由 CI 的 binaries job 交叉编译（纯 Go、无 QEMU），按目标架构放在
# 构建上下文的 dist/<TARGETARCH>/artex。这样多架构构建时 arm64 只需模拟 apt 层，
# 不再模拟 Next/Go 编译，速度快得多。
#
# 本地手动构建镜像时，先用 build.sh 的 -trimpath 与版本 ldflags 准备二进制：
#   ARTEX_OUTPUT=dist/amd64/artex ./build.sh --target linux/amd64
#   docker build \
#     --build-arg SOURCE_DATE_EPOCH=1794839650 \
#     --provenance=false --sbom=false \
#     -t artex:pinned .
#
# 拉取锁定见各 ARG。apt 使用 snapshot.debian.org 的时间戳，不写死每个 deb 的
# 版本号：binNMU 的 +bN 后缀按架构不同，写死 amd64 版本会让 arm64 构建失败。
FROM python:3.12-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df
ARG TARGETARCH
ARG DEBIAN_SNAPSHOT=20261116T143410Z
ARG DEBIAN_SECURITY_SNAPSHOT=20261116T155657Z
ARG NODE_VERSION=22.23.5
ARG SOURCE_DATE_EPOCH=1794839650
# 常用工具：ripgrep / curl / vim，加一批 recon 常备件（按需增删）。
# 源固定到上面的 Debian 快照。Node 使用 nodejs.org 的官方压缩包，并按
# https://nodejs.org/dist/v22.23.5/SHASUMS256.txt 中的 sha256 校验。
RUN rm -rf /etc/apt/sources.list /etc/apt/sources.list.d/* \
    && printf 'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/%s bookworm main\n\
deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/%s bookworm-updates main\n\
deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/%s bookworm-security main\n' \
      "$DEBIAN_SNAPSHOT" "$DEBIAN_SNAPSHOT" "$DEBIAN_SECURITY_SNAPSHOT" \
      > /etc/apt/sources.list \
    && apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates ripgrep curl wget vim git jq unzip \
      tzdata \
      dnsutils iputils-ping netcat-openbsd inetutils-telnet whois nmap \
    && rm -rf /var/lib/apt/lists/*
RUN set -eu; \
    case "$TARGETARCH" in \
      amd64) \
        node_arch=x64; \
        node_sha=c54118104acc524633b5abe106bbf44a53126ec8b4e5fa105cb92b5d7de8a1a1; \
        ;; \
      arm64) \
        node_arch=arm64; \
        node_sha=8bd3dc69eee8f3f226315a80d7d1d4faccf217a4c8fae500168ac2e38f3bdba3; \
        ;; \
      *) echo "unsupported TARGETARCH=$TARGETARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/node.tar.gz \
      "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.gz"; \
    echo "${node_sha}  /tmp/node.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/node.tar.gz -C /usr/local --strip-components=1; \
    rm /tmp/node.tar.gz; \
    node --version; \
    npm --version
# Playwright 三个包的版本和传递依赖由 docker/playwright-tools/package-lock.json 锁定。
# npm ci 按 lockfile 的 integrity 校验。浏览器压缩包由该版本的 Playwright 安装器下载，
# 安装器使用包内登记的校验和；Dockerfile 不再写 @latest。
COPY docker/playwright-tools/package.json docker/playwright-tools/package-lock.json /opt/playwright-tools/
WORKDIR /opt/playwright-tools
RUN npm ci \
    && ln -sfn /opt/playwright-tools/node_modules/.bin/playwright /usr/local/bin/playwright \
    && ln -sfn /opt/playwright-tools/node_modules/.bin/playwright-cli /usr/local/bin/playwright-cli \
    && playwright-cli --help \
    && playwright install --with-deps chromium \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV TZ=Asia/Shanghai
ENV PATH="/opt/playwright-tools/node_modules/.bin:${PATH}"
# 预编译好的对应架构二进制（dist/amd64/artex 或 dist/arm64/artex）
COPY --chmod=755 dist/${TARGETARCH}/artex /app/artex
# 守护启动脚本：进程退出后按退出码决定是否重新拉起，页面一键更新靠它完成换装。
# 它同时负责把 SIGTERM 转发给 artex —— docker stop 只把信号发给 PID 1，
# 不转发的话 artex 收不到、做不了优雅关闭，10 秒后被 SIGKILL 硬杀。
COPY --chmod=755 start.sh /app/start.sh
COPY skills/ /app/skills/
# data/（SQLite + jwt.key）持久化点
VOLUME ["/app/data"]
EXPOSE 8787 8788
ENTRYPOINT ["/app/start.sh"]
CMD ["-addr", ":8787", "-proxy", ":8788"]
