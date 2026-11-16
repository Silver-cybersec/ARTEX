# ARTEX 锁定版构建记录

本文件记录 `cursor/artex-pinned-build` 上的锁定构建。没有执行 `artex`，没有 `docker run`，没有启动 Compose、PostgreSQL 或其他服务，没有连接外部目标。镜像内文件是用 `docker create`（状态为 `created`）后 `docker cp` 取出，再 `docker rm`。

锁定改动在提交 `2c47c10db4e2bcbd699cede36a3a86d10159c560`。二进制的 `vcs.revision` 就是这个提交。本记录是随后追加的文档。

## 1. 构建环境

| 项 | 实测值 |
| --- | --- |
| 虚拟机操作系统 | Ubuntu 24.04.5 LTS（`/etc/os-release` 的 `PRETTY_NAME`） |
| 内核 | `Linux cursor 6.12.113+ #1 SMP PREEMPT_DYNAMIC Mon Nov 16 16:06:22 UTC 2026 x86_64 GNU/Linux` |
| CPU | `lscpu`：架构 `x86_64`，4 个逻辑 CPU，厂商 `GenuineIntel`，型号字符串 `Intel(R) Xeon(R) Processor`。`lscpu` 没有给出更具体的型号编号 |
| Go | `go1.26.10 linux/amd64`。`go.mod` 为 `go 1.26.10` |
| Go 模块源 | `GOPROXY=https://proxy.golang.org,direct`，`GOSUMDB=sum.golang.org` |
| 宿主机 Node / npm | `v22.23.4` / `10.9.9`。`build.sh` 用它们编译前端 |
| 前端锁文件里的直接版本 | `next@16.2.9`、`react@19.2.7`、`typescript@5.9.3`（`web/package-lock.json`） |
| rsync | `3.2.7`，协议 31，Ubuntu 包 `3.2.7-1ubuntu1.5`。开始时没有 rsync，为了跑 `build.sh` 才安装 |
| Docker Engine | `29.1.3`（包 `docker.io 29.1.3-0ubuntu3~24.04.2`） |
| Buildx / BuildKit 前端 | Buildx `0.30.1`（包 `0.30.1-0ubuntu1~24.04.1`）。构建日志使用 `docker` driver。语法镜像 `docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e` |
| containerd | `2.2.1-0ubuntu1~24.04.4` |
| runc | `1.3.4-0ubuntu1~24.04.1` |
| 存储驱动 | `overlayfs` |
| 镜像内 Node / npm | `v22.23.5` / `10.9.9`（构建日志：`/tmp/node.tar.gz: OK`，随后 `v22.23.5` 和 `10.9.9`） |

## 2. 构建命令与时间

时间用 `TZ=Asia/Hong_Kong`。成功的二进制构建：

```bash
ARTEX_OUTPUT=dist/amd64/artex ./build.sh --target linux/amd64
```

`build.sh` 自己执行了 `npm ci`、`npm run build:static`，以及：

```text
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -tags embedui -trimpath \
  -ldflags "-s -w -buildid= -X main.version=2c47c10" -o dist/amd64/artex ./cmd/artex
```

版本号 `2c47c10` 来自 `git describe --tags --always --dirty`。本仓库没有 tag，干净工作区得到的就是该缩写。UPX 被脚本跳过。

| 阶段 | 开始 (HKT) | 结束 (HKT) | 结果 |
| --- | --- | --- | --- |
| 第一次 `build.sh` | 2026-11-17 02:10:40 | 2026-11-17 02:10:40 | 退出码 1，耗时 0 秒。原文：`未检测到 rsync` |
| 安装 rsync 后的 `build.sh` | 2026-11-17 02:10:50 | 2026-11-17 02:12:13 | 退出码 0，`elapsed_seconds=83`。其中 `npm ci` 输出 “added 744 packages … in 19s”。husky 打印 `.git can't be found`，安装仍退出 0 |
| 第一次镜像构建 | 2026-11-17 02:12:51 | 2026-11-17 02:14:43 | 退出码 0，`elapsed_seconds=112` |
| 第二次镜像构建 | 2026-11-17 02:15:09 | 2026-11-17 02:16:27 | 退出码 0，`elapsed_seconds=78` |

两次镜像构建使用同一条命令，只是标签不同，并且都加了 `--no-cache`，避免第二次命中第一次的层缓存：

```bash
docker build \
  --build-arg SOURCE_DATE_EPOCH=1794839650 \
  --provenance=false --sbom=false \
  --no-cache --progress=plain \
  -t artex:pinned-1 .
```

第二次把标签换成 `artex:pinned-2`。`1794839650` 等于 `2026-11-16T14:34:10Z`，与 Debian 主归档快照 `20261116T143410Z` 的时间相同。

同一组 Go 参数又执行了一次，输出到另一个路径。构建缓存是热的，耗时 1 秒。sha256 与 `dist/amd64/artex` 相同。这不是一次清空缓存的重编译。

### 网络源

| 用途 | 实际访问的源 |
| --- | --- |
| Debian bookworm 与 bookworm-updates | `https://snapshot.debian.org/archive/debian/20261116T143410Z` |
| Debian security | `https://snapshot.debian.org/archive/debian-security/20261116T155657Z` |
| Node 官方包与 `SHASUMS256.txt` | `https://nodejs.org/dist/v22.23.5/`。另从 `https://nodejs.org/download/release/v22.23.5/SHASUMS256.txt` 再取了一次，两份校验文件的 sha256 都是 `658770bd465343e4bf441d22e89e7d944244b37041695f3f2a85b53d1a84b53f` |
| Playwright npm 包 | lockfile 中的 `resolved` 均为 `https://registry.npmjs.org/` |
| 浏览器 | 构建日志：`https://cdn.playwright.dev/builds/cft/159.0.8154.6/linux64/chrome-linux64.zip`、`https://cdn.playwright.dev/builds/cft/159.0.8154.6/linux64/chrome-headless-shell-linux64.zip`、`https://cdn.playwright.dev/dbazure/download/playwright/builds/ffmpeg/1013/ffmpeg-linux.zip` |
| 前端与 Go | 前端 `npm ci` 使用 `https://registry.npmjs.org/`。Go 使用上面的 `GOPROXY` 与 `sum.golang.org` |
| 基础镜像与 Postgres 索引 | Docker Hub。Postgres 只读了清单，没有 `docker pull`，也没有启动 |
| 宿主机 rsync | `http://archive.ubuntu.com/ubuntu` 的 noble / noble-updates |

## 3. 锁定清单

| 组件 | 原写法 | 锁定值 | 校验方式 |
| --- | --- | --- | --- |
| Python 基础镜像 | `python:3.12-slim-bookworm` | 多架构索引 `sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df` | 镜像 digest。BuildKit 日志按这个 digest 取元数据 |
| Dockerfile 前端 | `docker/dockerfile:1` | `sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e` | 语法行中的 digest |
| Debian 主归档 | `deb.debian.org` 的 bookworm 与 bookworm-updates，浮动 | 快照 `20261116T143410Z`。bookworm-updates 的 Release 日期是 `Mon, 16 Nov 2026 14:13:10 UTC` | 快照时间戳。`[check-valid-until=no]`。apt 仍用基础镜像里的 Debian 仓库签名验证 Release |
| Debian security | `deb.debian.org/debian-security` bookworm-security，浮动 | 快照 `20261116T155657Z`。Release 日期 `Mon, 16 Nov 2026 15:56:20 UTC`，`Valid-Until` `Mon, 23 Nov 2026 15:56:20 UTC` | 同上 |
| apt 包名 | 无版本 | 不写 `包=版本`。本次 amd64 镜像里解析到的版本见下表 | 快照把索引冻住。多架构 Dockerfile 若写死 amd64 的 `+bN`，arm64 可能对不上，所以没有逐包写版本 |
| Node.js | `curl https://deb.nodesource.com/setup_22.x \| bash -` 再装浮动 `nodejs` | `22.23.5` 官方 `tar.gz`。amd64 sha256 `c54118104acc524633b5abe106bbf44a53126ec8b4e5fa105cb92b5d7de8a1a1`。arm64 sha256 `8bd3dc69eee8f3f226315a80d7d1d4faccf217a4c8fae500168ac2e38f3bdba3` | 构建时 `sha256sum -c`。日志为 `/tmp/node.tar.gz: OK`。本机把 amd64 包下载了两次，两次 sha256 都等于 `SHASUMS256.txt` 里的那一行。arm64 包没有在这台 x86_64 机器上下载，其 sha256 只抄自同一份 `SHASUMS256.txt` |
| `playwright` | `@latest` | `1.65.1` | `package-lock.json` lockfileVersion 3 的 `integrity`。`npm ci` 按它校验 |
| `@playwright/mcp` | `@latest` | `0.0.85` | 同上 |
| `@playwright/cli` | `@latest` | `0.1.24` | 同上 |
| 这两个包带上的传递依赖 | 安装时由 npm 现算 | lockfile 固定为 `playwright` / `playwright-core` 的 `1.66.0-alpha-1794252756000`（cli）和 `1.66.0-alpha-2026-11-09`（mcp） | lockfile `integrity`。它们是这两个包声明的依赖，不是另选的稳定版 |
| Chromium / FFmpeg | `playwright install` 跟着当时的 `@latest` | `playwright@1.65.1` 自带的 `playwright-core@1.65.1` 的 `browsers.json`：chromium 与 headless shell revision `1255`、`browserVersion` `159.0.8154.6`，ffmpeg revision `1013`。构建日志下载的就是这几个修订号 | 修订号写在已锁定的包里。该 `browsers.json` 没有 zip 的 sha256。在 `playwright-core` 的下载函数里没有找到对 zip 做 sha256 比对的代码 |
| PostgreSQL | `postgres:16-alpine` | 多架构索引 `sha256:81e77a4833487b8132fe4b00bedd39dc3f74b8641e387f19312a48f7de218c2e`。amd64 清单 `sha256:a2f7e20374cd8fd8ed4a588b79549e10589bea7b1686e77922f5ac741b80b8a1`，注解版本 `16.16-alpine3.24`，创建时间 `2026-11-12T20:57:43Z` | 登记 digest。本次只做了 `docker buildx imagetools inspect`，没有拉取，也没有启动 |
| Go 模块 | `go.mod` / `go.sum` | 未改版本，继续用现有 `go.sum` | `sum.golang.org` |
| 前端 npm | `web/package-lock.json` | 未改锁文件。`npm ci` 装入 744 个包 | lockfile `integrity` |
| 编译参数 | Dockerfile 注释里的普通 `go build` | `build.sh` 的 `-trimpath` 与 `-ldflags "-s -w -buildid= -X main.version=2c47c10"` | 产物 `file` 为 stripped。二进制中有字节串 `2c47c10`。`go version -m` 有 `-trimpath=true`，没有打印 `-ldflags` 行 |

本次 amd64 镜像里，Dockerfile 点名的 apt 包版本如下。它们和 2026-11-16 那次浮动 `deb.debian.org` 构建的同名包版本相同：

| 包 | 版本 |
| --- | --- |
| ca-certificates | `20250419~deb12u2` |
| ripgrep | `13.0.0-4+b2` |
| curl | `7.88.1-10+deb12u15` |
| wget | `1.21.3-1+deb12u1` |
| vim | `2:9.0.1378-2+deb12u2` |
| git | `1:2.39.5-0+deb12u3` |
| jq | `1.6-2.1+deb12u3` |
| unzip | `6.0-28+deb12u1` |
| tzdata | `2026f-0+deb12u1` |
| dnsutils | `1:9.18.49-1~deb12u3` |
| iputils-ping | `3:20221126-1+deb12u1` |
| netcat-openbsd | `1.219-1` |
| inetutils-telnet | `2:2.4-2+deb12u3` |
| whois | `5.5.17` |
| nmap | `7.93+dfsg1-1` |

最终 dpkg 已安装包 261 个。上次浮动镜像是 285 个。两边同名包的版本差异为 0。浮动镜像多出的 24 个包是 `apt-transport-https`、`dirmngr`、`gnupg`、`gnupg-l10n`、`gnupg-utils`、`gpg`、`gpg-agent`、`gpg-wks-client`、`gpg-wks-server`、`gpgconf`、`gpgsm`、`libassuan0`、`libksba8`、`libnpth0`、`libpython3-stdlib`、`libpython3.11-minimal`、`libpython3.11-stdlib`、`media-types`、`nodejs`（`22.23.5-1nodesource1`）、`pinentry-curses`、`python3`、`python3-minimal`、`python3.11`、`python3.11-minimal`。这次不再安装 NodeSource 的 deb。

## 4. 产物与两次镜像是否一致

宿主机二进制与两次镜像里的 `/app/artex` 是同一个文件：

| 项 | 值 |
| --- | --- |
| sha256 | `bccb9bcea13455b3cbf94c9ee1f3a105c926d010d0f4986ca181afc3db6f0c0c` |
| 大小 | 42,430,590 字节 |
| 权限 | `0755` |
| `file` | ELF 64-bit x86-64，statically linked，stripped |
| Go | `go1.26.10` |
| 模块版本字符串 | `v0.0.0-20261116181028-2c47c10db4e2` |
| `vcs.revision` | `2c47c10db4e2bcbd699cede36a3a86d10159c560` |
| `vcs.time` | `2026-11-16T18:10:28Z` |
| `vcs.modified` | `false` |
| `-trimpath` | `true` |
| `CGO_ENABLED` | `0` |

两次 `docker build --no-cache` 的镜像 digest 不一致。

| 项 | `artex:pinned-1` | `artex:pinned-2` |
| --- | --- | --- |
| 镜像 ID / manifest | `sha256:df65b864df6aebfe55bb09779724363f0e95555a1434418296bdf4b7c9abde99` | `sha256:698cbc806c90aeab74e5a2671ebcb90d48669e97ea0ad7805471b0b5dc5b2969` |
| 导出的 config digest | `sha256:d1572d769d5319a1eef5dfb8df2c9422be9fff1f7ed1633ecb9fa3c7d8548716` | `sha256:541a3fe7e9b8857c1f3e1fa5d42133324929b755a2f73161126bf13ae63c90e0` |
| inspect `Created` | `2026-11-16T14:34:10Z` | `2026-11-16T14:34:10Z` |
| inspect `Size` | 646,976,035 | 646,976,591 |
| `docker images` 显示 | 2.34GB | 2.34GB |
| rootfs 层数 | 13 | 13 |
| 入口、命令、环境变量、端口、工作目录、数据卷 | 相同 | 相同 |

13 层里，第 0–3、7、9 层的 diff ID 相同，第 4、5、6、8、10、11、12 层不同。`docker history` 的 30 条指令相同，工具显示的每层体积也相同；体积显示有舍入，不能据此说层字节相同。

从两个未启动的容器里抽出的这些文件，内容 sha256 相同：`/var/lib/dpkg/status`（233,245 字节）、`/usr/local/bin/node`（124,909,296 字节）、`/app/artex`、`/app/start.sh`、`/opt/playwright-tools/package-lock.json`、Playwright 的 `chrome`（311,672,136 字节）。

mtime 并不都相同：

| 文件 | 第一次 | 第二次 |
| --- | --- | --- |
| `/var/lib/dpkg/status` | 2026-11-16T18:13:52Z | 2026-11-16T18:15:43Z |
| `chrome` | 2026-11-16T18:13:55Z | 2026-11-16T18:15:46Z |
| `/usr/local/bin/node` | 两边都是 2026-11-11T11:01:11Z | 同左 |
| `/app/artex`、`start.sh`、lockfile | 两边 mtime 相同 | 同左 |

`dpkg status` 与 `chrome` 的 mtime 相差 111 秒，落在两次构建的墙钟之间。`SOURCE_DATE_EPOCH` 把镜像 config 的 `Created` 固定成了 `2026-11-16T14:34:10Z`，但没有把这些 RUN 步骤写出的文件 mtime 改成同一个值。层 diff ID 计算的是带元数据的 tar，所以镜像 digest 不同。COPY 层的 diff ID 也不同，但抽出的 `/app/artex` 等内容与 mtime 相同；这些层里目录项的 mtime 没有逐层拆 tar，未完全核实。

因此：二进制两次编译的 sha256 相同；两次镜像的配置字段和抽查文件内容相同；两次镜像 digest 不相同。

## 5. 这次没有锁定的东西

- apt 没有写成 `包=版本`。原因：`ripgrep` 这类包的 `+bN` 是按架构做的 binNMU，把这次 amd64 版本写进同一份 Dockerfile 可能让 arm64 构建失败。锁定手段是两个快照时间戳。amd64 实际版本已列在第 3 节。
- 浏览器 zip 没有单独的 sha256。`browsers.json` 只钉修订号和版本号，下载函数里没有看到 sha256 比对。CDN 若替换同一修订号上的文件，构建结果会变。本次两次构建抽出的 `chrome` 内容相同。
- `SHASUMS256.txt` 没有做 OpenPGP 签名校验。做了的是：两份官方校验文件彼此一致，并且 amd64 压缩包的 sha256 与其中一行一致，构建时 `sha256sum -c` 通过。
- arm64 的 Node 压缩包没有在本机下载。sha256 来自同一份 `SHASUMS256.txt`。本次镜像只构建了 linux/amd64。
- 宿主编译前端的 Node 是 `v22.23.4`，不是镜像里的 `22.23.5`。原因：`build.sh` 调用的是 PATH 上的 `node`，本机原有 `22.23.4`，没有为了前端再换一套 Node。镜像内的 Node 已锁定。
- Go 工具链二进制的发布校验和没有写进仓库。版本由 `go.mod` 的 `go 1.26.10` 声明，本机正好是这个版本。
- 两次镜像 digest 没有做到相同。原因是 RUN 层文件 mtime 仍随墙钟变化，见第 4 节。
- Postgres 镜像没有拉取、没有运行。digest 只来自当时的登记清单。
