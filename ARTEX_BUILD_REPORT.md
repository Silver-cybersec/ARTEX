# ARTEX 本地构建与镜像静态比对报告

比对时间：2026-11-16T16:34:20Z 至 2026-11-16T16:48:43Z（HKT 为次日 00:34–00:48）。  
仓库检出：`Silver-cybersec/ARTEX`，分支 `main`，提交 `a05a886d3da624bd070f9b984025e27dfa82bdb6`。  
范围：按 Dockerfile 注释和 README「从源码编译」准备 `dist/amd64/artex`，执行 `docker build -t artex:local .`，再与 `ruoji6/artex:latest` 做静态比对。没有 `docker run`，没有启动 ARTEX、Compose 或 PostgreSQL，没有执行 `artex` 二进制。

## 1. 结论摘要

官方路径可以在本机走通：前端静态导出、`dist/amd64/artex` 和 `artex:local` 都构建成功。

自建镜像与 Docker Hub `ruoji6/artex:latest` 不一致。两边的多架构索引 digest 不同。已核实相同的部分是：Python 基础镜像的 4 个文件系统层、入口/命令/端口/环境变量/工作目录/数据卷、`/app/start.sh` 字节、最终 dpkg 285 个包的版本、全局 npm 文件树、Playwright 浏览器文件树。已核实不同的部分是：`/app/artex` 字节、`skills/` 里 3 个路径、OCI 标签、镜像创建时间，以及第 5 层及之后的 rootfs diff ID。Hub 镜像标签指向 `RuoJi6/ARTEX` 的 `v0.3.30`（提交 `6997a4661921395072290becc50380db8dacb04e`），比本次构建的 `a05a886` 超前 35 个提交；发布二进制还带有 CI `build.sh` 的 `-trimpath` 和 stripped 特征，Dockerfile 注释里的 `go build` 没有这些参数。

## 2. 构建步骤、提交与耗时

### 2.1 使用的提交

| 项 | 值 |
| --- | --- |
| 本次构建提交 | `a05a886d3da624bd070f9b984025e27dfa82bdb6` |
| 提交说明 | `fix: support traffic ID copying over HTTP` |
| 提交时间 | 2026-11-09T08:17:03Z |
| `git describe --tags --always` | `a05a886`（本检出没有 tag） |
| 构建时 `vcs.modified` | `false` |

Hub 镜像上的源码身份来自镜像标签和二进制 buildinfo，不是本次检出：

| 项 | 值 |
| --- | --- |
| 标签 `org.opencontainers.image.source` | `https://github.com/RuoJi6/ARTEX` |
| 标签 `org.opencontainers.image.revision` | `6997a4661921395072290becc50380db8dacb04e` |
| 标签 `org.opencontainers.image.version` | `v0.3.30` |
| 该提交说明 | `chore(release): prepare v0.3.30 release notes` |
| 该提交时间 | 2026-11-14T13:19:39Z |
| 附注标签 `v0.3.30` | 标签对象 `54b07581dc3df1f17ee83661c283889431699765`，指向上述提交；tagger 时间 2026-11-14T13:19:42Z |
| GitHub compare `a05a886...6997a466` | `status=ahead`，`ahead_by=35`，`behind_by=0` |

`6997a466` 不在本次克隆的对象库里。上表来自镜像内 buildinfo、镜像标签，以及 GitHub API 对 `RuoJi6/ARTEX` 的只读查询。

### 2.2 工具链

宿主机是 Ubuntu 24.04.5，`x86_64`。开始时没有 Docker，本次用 Ubuntu 包安装后构建。

| 工具 | 版本 |
| --- | --- |
| Go | `go1.26.10 linux/amd64`（`go.mod` 为 `go 1.26.10`） |
| `GOPROXY` | `https://proxy.golang.org,direct` |
| `GOSUMDB` | `sum.golang.org` |
| Node / npm（宿主机，用于前端） | `v22.23.4` / `10.9.9` |
| npm registry（宿主机） | `https://registry.npmjs.org/` |
| Docker Engine / 客户端 | `29.1.3`（包 `docker.io 29.1.3-0ubuntu3~24.04.2`） |
| containerd | `2.2.1` |
| runc | `1.3.4-0ubuntu1~24.04.1` |
| Buildx | `github.com/docker/buildx 0.30.1`（包 `0.30.1-0ubuntu1~24.04.1`） |
| Dockerfile 前端 | `docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e` |

安装 Buildx 之后，`docker build` 实际走 `docker buildx build`。构建日志第一行是 `#0 building with "default" instance using docker driver`。

### 2.3 命令

README 方式四要求 `npm ci` 再 `npm run build:static`。Dockerfile 注释要求把 `web/out` 拷到 `server/webui/dist`，再按下面的 Go 命令产出 `dist/amd64/artex`，最后 `docker build -t artex:local .`。仓库没有提交空目录 `server/webui`（`server/webui/dist/` 在 `.gitignore` 中），所以在注释里的 `cp` 之前创建了父目录。Go 命令本身没有改。

```bash
cd web && npm ci && npm run build:static && cd ..
mkdir -p server/webui
cp -r web/out server/webui/dist
CGO_ENABLED=0 GOARCH=amd64 go build -tags embedui -o dist/amd64/artex ./cmd/artex
docker build --progress=plain -t artex:local .
```

`--progress=plain` 只用于留下完整日志。标签仍是 `artex:local`，Dockerfile 未改。宿主机是 linux/amd64，因此 `GOOS` 用 Go 默认值 `linux`，与注释一致；buildinfo 中为 `GOOS=linux`、`GOARCH=amd64`、`CGO_ENABLED=0`、`-tags=embedui`。注释中的命令没有 `-trimpath`，也没有 `-ldflags`。

随后只拉取、不运行：

```bash
docker pull ruoji6/artex:latest
```

### 2.4 耗时

| 阶段 | 开始 (UTC) | 结束 (UTC) | 结果 |
| --- | --- | --- | --- |
| 安装 Docker（环境前置） | 2026-11-16T16:34:20Z | 2026-11-16T16:35:07Z | apt 退出码 0 |
| `npm ci` | 2026-11-16T16:34:20Z | 2026-11-16T16:34:33Z | 退出码 0；npm 输出 “added 744 packages … in 13s” |
| `npm run build:static` | 紧接上一阶段 | 2026-11-16T16:35:03Z | 退出码 0；Next.js 16.2.9 日志为编译 19.5s、TypeScript 8.9s、34 个静态页 359ms |
| 第一次 `go build` | 2026-11-16T16:37:02Z | 2026-11-16T16:37:06Z | 退出码 1，耗时 4 秒。当时嵌入目录还不存在 |
| 成功的 `go build` | 2026-11-16T16:39:09Z | 2026-11-16T16:39:32Z | 退出码 0，日志 `elapsed_seconds=23`。模块已在失败那次下载过，这 23 秒不是空缓存时间 |
| `docker build` | 2026-11-16T16:42:34Z | 2026-11-16T16:43:47Z | 退出码 0，日志 `elapsed_seconds=73` |
| `docker pull ruoji6/artex:latest` | 2026-11-16T16:46:31Z | 2026-11-16T16:46:39Z | 退出码 0，日志 `elapsed_seconds=8`。基础层已在本地构建时下载，这 8 秒不是空缓存全量拉取时间 |

从 `npm ci` 开始到 `docker build` 结束的墙钟是 9 分 27 秒（16:34:20Z–16:43:47Z），包含失败编译和步骤间隔。

### 2.5 失败摘录与成功产物

第一次 `go build` 失败位置是 `server/webui_embed.go` 的 `//go:embed all:webui/dist`。原文：

```text
server/webui_embed.go:18:12: pattern all:webui/dist: no matching files found
elapsed_seconds=4
=== go build exit 1 2026-11-16T16:37:06Z ===
```

补上 `mkdir` 和 `cp` 后，同一条 Go 命令退出码 0。`npm ci` 有一条非致命输出，退出码仍是 0：

```text
> artex-web@2.2.0 prepare
> husky

.git can't be found
added 744 packages, and audited 745 packages in 13s
```

成功产物：

| 产物 | 测量值 |
| --- | --- |
| `web/out` | 420 个文件，含 `index.html` |
| `server/webui/dist` | 420 个文件，不是嵌套的 `dist/out` |
| `dist/amd64/artex` | 55,004,016 字节，mode `0755`，sha256 `da821896370921249fda436242523f3d9f24a2b7f0f76ed606030d379e707faa` |
| 文件类型 | `file`：ELF 64-bit x86-64，statically linked，with debug_info, not stripped |
| 镜像内 `/app/artex` | 与上面的大小、mode、sha256 相同 |
| 本地镜像 ID（含 attestation 的索引） | `sha256:7fc04f1af63c72fe8cff149a9be94858e6780793b2e7f1e63b2859672fc0b8d3` |

`docker images` 显示 `artex:local` 为 2.48GB。`docker image inspect` 的 `Size` 字段是 681,042,138。这是两个不同字段，本报告不把它们换算成同一个数。

构建日志里的本地镜像摘要：

| 对象 | digest |
| --- | --- |
| 平台镜像 manifest | `sha256:1a46f8459db8c89289a13a58211f674fe501340d227aa802fe037181c21671ce` |
| 镜像 config | `sha256:54c8d31430e60586d6980ad74245b5bb9a7164bb992c12128240d405178b3003` |
| attestation manifest | `sha256:00cd52e502f574162f4b711cf81da47bedf418a8fada36741c8c3d73931b14b1` |
| manifest list（与 inspect ID 相同） | `sha256:7fc04f1af63c72fe8cff149a9be94858e6780793b2e7f1e63b2859672fc0b8d3` |

## 3. 供应链清单

未锁定的判断标准：Dockerfile 或脚本写的是浮动标签、`@latest`、未写版本的包名，或没有校验和。构建当时解析到的版本记在「本次解析」列。

### 3.1 基础镜像

Dockerfile 写的是 `FROM python:3.12-slim-bookworm`，没有 digest。

| 项 | 值 |
| --- | --- |
| 多架构索引 | `python:3.12-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df` |
| 本次 amd64 平台 manifest | `sha256:0f086103b026048cc50cb5da25ec435c023c5241a83fc44daea593377abc61c4` |
| 该平台 manifest 的 config | `sha256:313cf8f190a1abab00472c1f0c950c10486c22114bcd8aef2a8198fb587a6d18` |
| 平台注解版本 | `3.12.16-slim-bookworm` |
| 平台注解创建时间 | 2026-11-05T07:52:18Z |
| 注解中的上级镜像 | `debian:bookworm-slim` |
| 注解中的上级 digest | `sha256:c67e92c8099ba22853ab4cfda7cfb494d253d6012ca82dee98ba8976772af018` |
| 镜像环境变量 `PYTHON_VERSION` | `3.12.16` |
| 镜像环境变量 `PYTHON_SHA256` | `b5796915dc45ff745cfb4e990a7e7c93d6f546328a102ce31448d69ebc37575c` |

BuildKit 日志中的 `FROM` 行使用的是索引 digest `sha256:935c3c5b…`。amd64 manifest 的 4 个压缩层与 Hub amd64 manifest 的前 4 层逐个相同，顺序也相同：

| # | 压缩层 digest |
| --- | --- |
| 0 | `sha256:dd051e1b8c92ff101fa3071ab97ea4924885942f15644e01c3dc095764e863e3` |
| 1 | `sha256:a47be7bff94f52aefb243d8b245b01c74976150bb88de60875c5eb7ac964f91e` |
| 2 | `sha256:8691b22c22a3e005c632ab6bc07b085b98dae9cc02d1d84de175849f997439c7` |
| 3 | `sha256:88d15687540999237909e04714b1393c610db9dc2e13d82acd6356fa9bf8f092` |

`debian:bookworm-slim` 的 digest 只来自 Python 镜像注解，本次没有单独拉取 Debian 镜像。

`docker-compose.yml` 里还有 `postgres:16-alpine`，同样没有 digest。本次没有拉取它。

### 3.2 Dockerfile 前端镜像

`# syntax=docker/dockerfile:1` 没有 digest。本次解析为 `docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e`。它只参与构建，不进入最终镜像的 rootfs。

### 3.3 apt

Dockerfile 的包名都没有版本。构建日志里的源是：

- `http://deb.debian.org/debian bookworm`
- `http://deb.debian.org/debian bookworm-updates`
- `http://deb.debian.org/debian-security bookworm-security`

日志使用的是 `http://deb.debian.org`，不是 `https`。Dockerfile 没有把包版本或 `snapshot.debian.org` 日期写死。apt 仍会验证 Debian 仓库签名；这不等于版本锁定。

Dockerfile 点名的包在最终镜像 dpkg 中的版本如下。`ca-certificates` 和 `tzdata` 的构建日志原文是 already the newest version，版本取自最终 dpkg。

| 包 | 本次与 Hub 的 dpkg 版本（两边相同） | Dockerfile 是否锁版本 |
| --- | --- | --- |
| ca-certificates | `20250419~deb12u2` | 否 |
| ripgrep | `13.0.0-4+b2` | 否 |
| curl | `7.88.1-10+deb12u15` | 否 |
| wget | `1.21.3-1+deb12u1` | 否 |
| vim | `2:9.0.1378-2+deb12u2` | 否 |
| git | `1:2.39.5-0+deb12u3` | 否 |
| jq | `1.6-2.1+deb12u3` | 否 |
| unzip | `6.0-28+deb12u1` | 否 |
| tzdata | `2026f-0+deb12u1` | 否 |
| dnsutils | `1:9.18.49-1~deb12u3` | 否 |
| iputils-ping | `3:20221126-1+deb12u1` | 否 |
| netcat-openbsd | `1.219-1` | 否 |
| inetutils-telnet | `2:2.4-2+deb12u3` | 否 |
| whois | `5.5.17` | 否 |
| nmap | `7.93+dfsg1-1` | 否 |
| nodejs | `22.23.5-1nodesource1` | 否，见下一节 |

这些包的依赖也没有在 Dockerfile 里锁版本。构建日志里 `Setting up` 出现 180 次。最终镜像已安装包是 285 个；与 Hub 镜像逐包比较，包集合相同，版本差异 0。285 这个数包含基础镜像自带的包，不只是本次 `apt-get install` 新装的包。

`playwright install --with-deps chromium` 会再跑一轮 apt。那些依赖同样没有版本锁，并落在 npm/Playwright 那一层。它们已经包含在上述 285 个包的零差异结果里。

### 3.4 NodeSource

Dockerfile 执行：

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y --no-install-recommends nodejs
```

`setup_22.x` 是浮动主版本脚本，管道进 shell，Dockerfile 没有校验和。本次日志里的仓库是 `https://deb.nodesource.com/node_22.x`，装到的包是 `nodejs 22.23.5-1nodesource1`。镜像内 npm 日志出现 “New major version of npm available! 10.9.9 -> 12.2.2”，说明该 Node 包带的 npm 是 10.9.9。Hub 镜像的 dpkg 版本与本次相同。Hub 构建当时的下载 URL 没有留在镜像里，未从 Hub 日志核实。

宿主编译前端用的是 Node `v22.23.4`，与镜像里的 `22.23.5-1nodesource1` 不是同一个补丁版本。CI 的 `actions/setup-node` 写的是 `node-version: "22"`，也没有锁补丁号。

### 3.5 npm 与 Playwright

Dockerfile 写的是：

```bash
npm install -g @playwright/mcp@latest @playwright/cli@latest playwright@latest
playwright install --with-deps chromium
```

三个包都是 `@latest`，镜像构建没有 lockfile，Dockerfile 没有校验和。构建日志原文是 `added 8 packages in 2s`，没有打印解析版本。版本是构建后从镜像里的 `package.json` 读出的：

| 包 | 解析版本 | 锁定情况 |
| --- | --- | --- |
| `playwright` | `1.65.1` | Dockerfile 为 `@latest` |
| `@playwright/mcp` | `0.0.85` | Dockerfile 为 `@latest` |
| `@playwright/cli` | `0.1.24` | Dockerfile 为 `@latest` |

安装位置是 `/usr/lib/node_modules`。两边各有 205 个 `package.json`，按路径比较版本差异为 0。按文件内容计算的树（2264 个文件，67,526,999 字节）sha256 都是 `8ef3f9537f4c55c9097fd14c935bc20249ad818ecc8c7884b2532eff61295a3b`。

本次构建日志中的浏览器下载：

| 组件 | 日志中的版本 | URL | 日志中的体积 |
| --- | --- | --- | --- |
| Chrome for Testing | `159.0.8154.6`（playwright chromium `v1255`） | `https://cdn.playwright.dev/builds/cft/159.0.8154.6/linux64/chrome-linux64.zip` | 199.3 MiB |
| Chrome Headless Shell | `159.0.8154.6`（`v1255`） | `https://cdn.playwright.dev/builds/cft/159.0.8154.6/linux64/chrome-headless-shell-linux64.zip` | 125.7 MiB |
| FFmpeg | playwright ffmpeg `v1013` | `https://cdn.playwright.dev/dbazure/download/playwright/builds/ffmpeg/1013/ffmpeg-linux.zip` | 2.2 MiB |

日志没有记录校验和比对。浏览器落在 `/root/.cache/ms-playwright/`，目录为 `chromium-1255`、`chromium_headless_shell-1255`、`ffmpeg-1013`。两边该目录都是 597 个文件、731,820,047 字节，内容树 sha256 都是 `f8b36d0e04144a558bd9b501e5aff42e75ac22a2b4cd2ea78e8ce3c46ae6ce7b`。Hub 镜像的字节与本次相同；Hub 当时的 URL 未单独保留，未从 Hub 日志核实。

镜像构建日志没有打印 npm registry。没有在镜像里执行 `npm config`。未核实项见第 6 节。

### 3.6 pip

Dockerfile 没有 `pip install`。基础镜像自带 Python 3.12.16。本次没有导出 `site-packages` 清单。

### 3.7 宿主机上的前端和 Go 模块

前端 `web/package-lock.json` 是 lockfileVersion 3，包来自 `https://registry.npmjs.org/`，锁文件带 `integrity`。`package.json` 里的依赖范围仍是 `^`，实际安装版本由锁文件决定。本次 `npm ci` 装到的直接相关版本：`next@16.2.9`、`react@19.2.7`、`typescript@5.9.3`。`artex-web` 自身版本是 `2.2.0`。

Go 模块由 `go.mod` / `go.sum` 锁定，校验数据库是 `sum.golang.org`。这只覆盖本次 `go build`。镜像里的工具链不在这一步编译。

### 3.8 未锁定或无校验和汇总

- `python:3.12-slim-bookworm`：浮动标签。
- `docker/dockerfile:1`：浮动标签。
- `postgres:16-alpine`：只出现在 Compose 中，浮动标签，本次未拉取。
- Dockerfile 中的 apt 包名：无版本。
- `https://deb.nodesource.com/setup_22.x`：浮动脚本，无校验和，并管道执行。
- `@playwright/mcp@latest`、`@playwright/cli@latest`、`playwright@latest`：浮动版本，无锁文件，Dockerfile 无校验和。
- Playwright 浏览器压缩包：Dockerfile 无校验和，构建日志无校验和记录。
- CI 与 README 的 Node.js `22`：只锁主版本。

已锁定的部分：`web/package-lock.json`（含 integrity），`go.sum`，以及 Python 镜像环境变量里公布的 `PYTHON_SHA256`（那是基础镜像自己的 CPython 源码校验值，不是本 Dockerfile 新增的锁）。

## 4. 镜像比对

文件取出方式：对每个镜像 `docker create`（inspect 状态为 `created`），`docker cp` 拷出文件，再 `docker rm`。没有 `docker start`，没有 `docker run`。`go version -m` 和 `file` 只读二进制，没有执行 `artex`。

### 4.1 digest

| 对象 | digest |
| --- | --- |
| 本地 `artex:local` 索引 / inspect ID | `sha256:7fc04f1af63c72fe8cff149a9be94858e6780793b2e7f1e63b2859672fc0b8d3` |
| 本地平台 manifest | `sha256:1a46f8459db8c89289a13a58211f674fe501340d227aa802fe037181c21671ce` |
| 本地 config | `sha256:54c8d31430e60586d6980ad74245b5bb9a7164bb992c12128240d405178b3003` |
| Hub `ruoji6/artex:latest` 索引 | `sha256:b4848e321d5599f5a5d8de7a28e7e31b694db4281e5f4548d1aa09df59c44e14` |
| Hub linux/amd64 manifest | `sha256:7489873da0ad027a077bfaee1333b38c20f0940264996d1c6725ecac2d7dfa4c` |
| Hub amd64 config | `sha256:4a3a9fc16acd824173d66bcbe8a0d47f7a2dbe0959d9adc6473002479c2a4343`（9072 字节） |
| Hub linux/arm64 manifest | `sha256:33b5717f393f6038ba5d24a48b4f6e1f4dc2dbd6951060a9172e83e6fa3c3178` |

Hub 索引还带有两个 attestation manifest：`sha256:1e12b43372d8a3a58790339d722f314ec3bd907db996f4faa2ad85232b21da93`（指向 amd64）和 `sha256:e5d0a969ce040952c7b2c9bcc839c8a1f797915262b7cb58f8ada5375cd8df30`（指向 arm64）。本次没有解这些 attestation 的内容。

`docker pull` 打印的 Digest 与 Hub 索引相同。本机是 amd64，后续 rootfs 和文件比对针对的是已拉到本地的 amd64 镜像，不是 arm64。

### 4.2 层数与 rootfs

两边 `docker history` 都是 23 条。两边 `RootFS.Layers` 都是 11 条。23 与 11 的差别来自 ENV、CMD、EXPOSE 等不产生文件系统差异的历史记录；本报告同时保留这两个数。

前 4 个 rootfs diff ID 相同，对应基础镜像：

| # | diff ID |
| --- | --- |
| 0 | `sha256:1d7b9dd8778ebc4d9bf2f64436dd358640718cb349f5640b33bebaea4ffd62c2` |
| 1 | `sha256:a3cfe73133965fb536427fde3fe66b2949ea6178f568733760bf45f5c8b5c405` |
| 2 | `sha256:5e63f01f0cee6291b52c44ffeee48c9eb7b94cdb19478259bcfce37db9eb680e` |
| 3 | `sha256:311a92d269bd002ca4ff3d801c6320df734027d3b425ff1ec860368f12b07a26` |

第 4 层起 diff ID 不同：

| # | 本地 | Hub |
| --- | --- | --- |
| 4 | `sha256:e966a5eaf81d6e8625206449b11efaea525e17cc932cd247d7e49a2693e17b9b` | `sha256:7680a894485c4b9de376b4b64c6e11c6cf35515f763887d781d7267288707d55` |
| 5 | `sha256:697011ceff600057957be462c571f3db2b33f874b642ac94d805372ccdff4591` | `sha256:06174539c6d8b0abe45b937bd4ec6965b27e4cec366521fb299aca9feb73efa4` |
| 6 | `sha256:52a7ff13a4425a9a7f8402e24f5f07eb07758a9a039591a79ad863043bb3e1d3` | `sha256:38ae0843f18d27199bf9a21c8879638661b088be02b0c30c898c66916cdb5681` |
| 7 | `sha256:ff2d5bbbc0c74e33bbb2cc641a60a8ef5d105772bc489731e3e850a453a933c4` | `sha256:b7e1a07d72603c170fb282d5c40c7d9544a812b8d50e9a79ae0638844d4d60d7` |
| 8 | `sha256:148ee0257904cb5df5cf0c73afbe9bd14d31902d23e1b149098dd2e47c1d65a5` | `sha256:abdf35be525458e6fc616dff00e61d2dc8f1d519eae8bb2b33a8dfb31bd8a462` |
| 9 | `sha256:5f70bf18a086007016e948b04aed3b82103a36bea41755b6cddfaf10ace3c6ef` | `sha256:8ba5bd35b098d24a24e3cbc26edf81686a6e184379991e3268b965e3440b1a6a` |
| 10 | `sha256:f2a723b3e21abd0ea4cd58763b2d7ebc48bd8be58f5559e3a0b23078596c2473` | `sha256:98653c7db15f4520e954a89f50b4c9c026fcf2e0d47925190cb42456e5d69674` |

本地第 9 层是空 tar 的固定 diff ID `sha256:5f70bf18a086007016e948b04aed3b82103a36bea41755b6cddfaf10ace3c6ef`。Hub 的第 9 层不是这个值。

`docker history` 显示的体积（工具自身的舍入）里，只有 3 条不同，指令文本全部相同：

| 指令 | 本地 | Hub |
| --- | --- | --- |
| `COPY skills/ /app/skills/` | 279kB | 291kB |
| `RUN chmod +x /app/artex /app/start.sh` | 4.1kB | 43.5MB |
| `COPY dist/amd64/artex /app/artex` | 55MB | 43.5MB |

apt 层两边都显示 472MB，npm/Playwright 层两边都显示 1.13GB。显示体积相同，diff ID 仍然不同。`docker images` 的总显示值是本地 2.48GB、Hub 2.51GB。inspect `Size` 是本地 681,042,138、Hub 686,991,647。

镜像创建时间：本地 `2026-11-16T16:43:11.770464174Z`，Hub `2026-11-14T13:23:32.217532355Z`。

### 4.3 history

23 条 `CreatedBy` 逐字相同。与本次构建相关的几条是：

```text
CMD ["-addr" ":8787" "-proxy" ":8788"]
ENTRYPOINT ["/app/start.sh"]
EXPOSE [8787/tcp 8788/tcp]
VOLUME [/app/data]
COPY skills/ /app/skills/ # buildkit
RUN |1 TARGETARCH=amd64 /bin/sh -c chmod +x /app/artex /app/start.sh # buildkit
COPY start.sh /app/start.sh # buildkit
COPY dist/amd64/artex /app/artex # buildkit
ENV TZ=Asia/Shanghai
WORKDIR /app
RUN |1 TARGETARCH=amd64 /bin/sh -c npm install -g @playwright/mcp@latest @playwright/cli@latest playwright@latest && playwright-cli --help && playwright install --with-deps chromium && rm -rf /var/lib/apt/lists/* # buildkit
RUN |1 TARGETARCH=amd64 /bin/sh -c apt-get update && apt-get install -y --no-install-recommends ca-certificates ripgrep curl wget vim git jq unzip tzdata dnsutils iputils-ping netcat-openbsd inetutils-telnet whois nmap && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y --no-install-recommends nodejs && rm -rf /var/lib/apt/lists/* # buildkit
```

指令文本一致，说明 Hub amd64 镜像使用的 Dockerfile 步骤与当前仓库这份 Dockerfile 相同。层 digest 的差异来自层内容或元数据，不是来自另一份指令。

### 4.4 关键文件与运行配置

| 项 | 本地 `artex:local` | Hub `ruoji6/artex:latest`（amd64） |
| --- | --- | --- |
| `/app/artex` sha256 | `da821896370921249fda436242523f3d9f24a2b7f0f76ed606030d379e707faa` | `3f5accc83f6b8c27eb0b30963be7a3b451bdc1b163980d2244f4367ee8fc069b` |
| `/app/artex` 大小 | 55,004,016 | 43,503,742 |
| 最终 mode | `0755` | `0755` |
| `file` | statically linked，not stripped | statically linked，stripped |
| Go | `go1.26.10` | `go1.26.10` |
| buildinfo | `-tags=embedui`，无 `-trimpath`，`vcs.revision=a05a886d3da624bd070f9b984025e27dfa82bdb6`，`vcs.modified=false` | `-tags=embedui`，`-trimpath=true`，`vcs.revision=6997a4661921395072290becc50380db8dacb04e`，`vcs.modified=false` |
| 模块版本字符串 | `v0.0.0-20261109081703-a05a886d3da6` | `v0.0.0-20261114131939-6997a4661921` |
| 直接依赖 | 50 个 | 48 个 |
| `/app/start.sh` sha256 | `60a83fa328b156f3cb7874950b638862c0719c1f9d6e5915b1181e4daebbce6c` | 相同 |
| `/app/start.sh` 大小 / mode | 2448 字节，`0755` | 相同 |
| 入口 | `["/app/start.sh"]` | 相同 |
| 命令 | `["-addr", ":8787", "-proxy", ":8788"]` | 相同 |
| User | Config 中没有 User 字段 | 相同 |
| 端口 | `8787/tcp`、`8788/tcp` | 相同 |
| 工作目录 | `/app` | 相同 |
| 数据卷 | `/app/data` | 相同 |
| 环境变量 | 见下 | 逐项相同 |
| Labels | 无 | 有 4 个 OCI 标签，见 2.1 |

两边的环境变量都是：

```text
PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LANG=C.UTF-8
GPG_KEY=7169605F62C751356D054A26A821E680E5FA6305
PYTHON_VERSION=3.12.16
PYTHON_SHA256=b5796915dc45ff745cfb4e990a7e7c93d6f546328a102ce31448d69ebc37575c
TZ=Asia/Shanghai
```

`GPG_KEY` 是官方 Python 镜像带的公钥指纹，不是本次注入的私钥。`TZ` 来自 Dockerfile 的 `ENV TZ=Asia/Shanghai`。其余来自基础镜像。

`/app/start.sh` 与仓库根目录 `start.sh` 的 sha256 相同。本地镜像的 `skills/` 内容树 sha256 为 `710711f36a864c32cef24dd933065209afcd9996d85fe23ee0bcf291a75487d0`，与仓库 `skills/` 相同（21 个文件，198,167 字节）。Hub 为 `ed63dd0b93e3d1e0932712edd473bd651d1c7a2a0be2901b3c69e33f6037d3e7`（22 个文件，210,661 字节）。Hub 多出 `api-recon/scripts/test_user_agent.py`。内容不同的两个文件是 `api-recon/scripts/harvest_static.py`（本地 8569 字节，Hub 11819 字节）和 `api-recon/scripts/spider_mpa.py`（本地 5884 字节，Hub 9078 字节）。

Go 依赖 buildinfo 差异：

| 模块 | 本地二进制 | Hub 二进制 |
| --- | --- | --- |
| `github.com/lqqyt2423/go-mitmproxy` | `v1.9.2` | `v1.9.5` |
| `golang.org/x/crypto` | `v0.55.0` | `v0.58.0` |
| `golang.org/x/net` | `v0.58.0` | `v0.61.0` |
| `golang.org/x/sync` | `v0.22.0` | `v0.24.0` |
| `golang.org/x/sys` | `v0.47.0` | `v0.49.0` |
| `golang.org/x/text` | `v0.41.0` | `v0.43.0` |
| `github.com/satori/go.uuid` | `v1.2.0` | buildinfo 中无此模块 |
| `go.uber.org/atomic` | `v1.11.0` | buildinfo 中无此模块 |

本地二进制里能搜到符号名 `main.version`，搜不到字节串 `0.3.30`。Hub 二进制搜不到符号名 `main.version`（与 stripped 一致），能搜到字节串 `0.3.30`。`go version -m` 没有在 Hub 二进制里打印 `-ldflags` 行。源码 `cmd/artex/main.go` 的默认值是 `var version = "dev"`，注释写明发布时用 `-ldflags "-X main.version=<tag>"`。`build.sh` 会传 `-trimpath` 和 `-ldflags "-s -w -buildid= -X main.version=..."`。字节串 `0.3.30` 出现在 Hub 二进制中，与标签 `v0.3.30` 和 `build.sh` 去掉前缀 `v` 后的版本一致；本次没有把该字节串反汇编到具体符号，所以不能单靠搜索证明它一定来自 `-X`。

抽样 mtime（内容相同的文件，时间不同）：

| 文件 | 本地 mtime (UTC) | Hub mtime (UTC) |
| --- | --- | --- |
| Playwright `chrome`（两边都是 311,672,136 字节） | 2026-11-16 16:43:07 | 2026-11-14 13:23:25 |
| `/app/start.sh` | 拷出后的 mtime 戳 `1794837913` | `1794662561` |

### 4.5 不一致的原因

1. 源码提交不同。本地二进制的 `vcs.revision` 是 `a05a886`，Hub 是 `6997a466`，后者在 `RuoJi6/ARTEX` 上超前 35 个提交。这直接解释二进制、嵌入的前端、Go 依赖版本和 `skills/` 三处文件差异。`skills/` 是镜像从构建上下文 `COPY` 的，不是运行时生成的。
2. 编译参数不同。Dockerfile 注释的 `go build` 没有 `-trimpath` 和 `-ldflags`。本地 `file` 结果是 not stripped。Hub 是 stripped，并且 buildinfo 有 `-trimpath=true`。这与 `.github/workflows/release.yml` 调用 `build.sh` 的参数一致。体积 55,004,016 与 43,503,742 的差距与「一份保留调试信息、一份 stripped」相符。
3. OCI 标签只由 CI 的 `docker/build-push-action` 写入。当前 Dockerfile 没有 `LABEL`，所以本地镜像没有这些标签。
4. apt、npm 和浏览器的最终文件内容本次是对齐的，但对应 rootfs diff ID 仍然不同。抽样文件的 mtime 不同，层创建时间也不同。diff ID 计算的是层 tar，包含时间戳等元数据。本次没有把这两层的 tar 逐项重新打包，因此「差异只来自 mtime」这一点未完全核实；包版本和文件内容已经核实为相同。
5. `chmod` 层体积差异的可能原因：本地 `go build` 产物已经是 `0755`，`chmod +x` 不再改这个大文件，该层只有 4.1kB。Hub 的 `chmod` 层显示 43.5MB，与它的 `COPY artex` 层显示体积相同，符合「COPY 时文件没有可执行位，随后 `chmod` 把整个文件再写入一层」。GitHub Actions 的 artifact 下载有可能丢掉可执行位，发布工作流正是把 artifact 下载到 `dist/${arch}` 再构建。Hub COPY 层里的原始权限位没有单独拆出来，这一解释未完全核实。两边最终 `/app/artex` 都是 `0755`。
6. 本地第 9 层是空层 diff，Hub 对应位置不是。这与上一条的层内容不同有关。空层在历史中的精确对应指令未单独核实。

## 5. 可复现加固建议

以下只作为仓库可以改的方向。本次没有改 Dockerfile，也没有创建 `.env`，更没有启动 Compose。

1. 把基础镜像写成 digest。本次解析到的索引是 `python:3.12-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df`。若只锁 amd64 平台清单，对应 `sha256:0f086103b026048cc50cb5da25ec435c023c5241a83fc44daea593377abc61c4`。多架构发布应锁索引 digest，并在升级时同时更新 amd64 与 arm64。
2. 把语法行写成 `# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e`。
3. 停止执行 `curl … setup_22.x | bash -`。改为安装已经记录的 `nodejs=22.23.5-1nodesource1`，并校验该 deb 的校验和；或者改用带 digest 的 Node 官方镜像拷贝 `node` 与 `npm`。
4. 把 Playwright 三条命令从 `@latest` 改成本次实际解析到的 `playwright@1.65.1`、`@playwright/mcp@0.0.85`、`@playwright/cli@0.1.24`，并提交 lockfile。浏览器修订号会跟着 `playwright` 版本走；本次是 chromium `1255` / Chrome for Testing `159.0.8154.6`、ffmpeg `1013`。
5. apt 包写上第 3.3 节的版本，或把源换成带日期的 `snapshot.debian.org`。现在两边版本碰巧一致，不代表下一次 `apt-get update` 仍会一致。
6. 若目标是复现 Hub 里的二进制，需要同时满足三件事：检出 `6997a466`（标签 `v0.3.30`），用 `build.sh` 的 `-trimpath` 和 `-ldflags "-s -w -buildid= -X main.version=0.3.30"`，再把产物放到 `dist/amd64/artex`。只按 Dockerfile 注释编译，得到的是未 strip、版本变量保持源码默认值的二进制。
7. 使用 BuildKit 的 `COPY --chmod=755`，避免 `chmod +x` 在大文件上再产生一层。发布工作流下载 artifact 后也应检查可执行位。
8. 把 CI 已有的 `org.opencontainers.image.*` 标签写进 Dockerfile 或构建参数，否则本地镜像与发布镜像的 config digest 即使文件系统相同也不会相同。
9. 使用本地镜像时，只在 `.env` 里写这两行。`docker-compose.yml` 的镜像行是 `${ARTEX_IMAGE:-ruoji6/artex}:${ARTEX_TAG:-latest}`，因此这两行会选中 `artex:local`：

```bash
ARTEX_IMAGE=artex
ARTEX_TAG=local
```

本次没有写 `.env`，没有执行 `docker compose`。

## 6. 未覆盖项

- 没有执行 `artex`，包括没有执行 `--version`。入口脚本的拉起行为、HTTP 健康检查和内嵌前端是否可访问都没有运行时验证。
- 没有 `docker run`，没有启动 Compose、PostgreSQL 或镜像内的其他进程。
- 没有构建 linux/arm64，也没有导出 Hub arm64 镜像里的文件。arm64 只记录了索引中的 manifest digest。
- 没有把 apt 层和 npm 层的 tar 重新导出做逐文件元数据比对。文件内容哈希已比对，层 diff ID 仍不同的剩余原因未完全核实。
- 没有拆开 Hub 的 `COPY artex` 层查看 chmod 之前的权限位。
- 没有把 `0.3.30` 这个字节串定位到 Hub 二进制里的具体符号。`go version -m` 没有打印 `-ldflags`。
- 没有在镜像内执行 `npm config get registry`，因此镜像构建时的 npm registry URL 未核实。
- 没有导出 Python `site-packages`。Dockerfile 没有 pip 步骤。
- 没有运行 syft 或 dive。包版本来自镜像内 `/var/lib/dpkg/status` 和 `package.json`。
- 没有验证 Hub 镜像签名，没有解 attestation 正文。
- 没有拉取 `postgres:16-alpine`，没有记录它的 digest。
- 没有用 `build.sh` 再编一版二进制去做第三次比对。
- 宿主机 Node 是 `22.23.4`。2026-11-14 那次 CI 实际解析到的 Node 补丁号未从 Actions 日志读取。
- `debian:bookworm-slim` 只引用了 Python 镜像注解中的 digest，没有单独拉取核对。
