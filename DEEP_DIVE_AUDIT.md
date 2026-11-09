# ARTEX 只读细查

这是对 `origin/cursor/security-audit-7c64` 上 `SECURITY_AUDIT.md`（提交 `d839a5d`，审计对象 `main` 的 `a05a886d3da624bd070f9b984025e27dfa82bdb6`）的复核补充。本文只新增这一份文档，不改产品代码。

读取时间是 2026-11-09。只做了静态阅读：源码、Dockerfile、lock、GitHub Release 资产、Docker Registry 的 manifest 与层。层在临时目录解包后用 `file`、`sha256sum` 和 Go buildinfo 读取。没有运行镜像、二进制或仓库程序，没有 `go build` / `npm ci`，没有向任何 ARTEX 实例发请求。

原审计把风险写成高、中、低、信息，并把没取回的对象写成「未确认」。下面每项给出一句结论，以及对该定级的影响：维持、上调、下调或无法确认。

## 1. 结论摘要

1. **Release 与 `ruoji6/artex:latest` 可以追溯到上游标签 `v0.3.27` / 提交 `459a4842374c6cc0f53a716d41eca907449ccbdd`，不能追溯到当前 `main` `a05a886`。** Linux amd64 与 arm64 的镜像内二进制和对应 Release zip 里的二进制字节相同；`/app` 里没有源码树之外的第二份程序。镜像里多出来的是 Dockerfile 声明过的基础镜像、apt 包、Node、Playwright 和 Chromium。原审计把 `ruoji6/artex:latest` 定为高，并把 Release 二进制列为未确认。本次把「这份当前产物无法追溯」**下调**为已核实；把「`latest` 无 digest、不能当成不可变的已审计产物」**维持**高。内嵌前端没有在本次重编，逐字节是否等于该提交的 `npm run build:static`，**无法确认**。

2. **默认 Docker Compose 部署下，空库时 `POST /api/auth/init` 不需要管理员令牌，也不经过默认关闭的 Basic Auth；`settings` 里出现非空的 `auth.password_hash` 之后该入口关闭。** 镜像默认命令、Compose 端口和当前源码一致，发布提交与当前 `main` 的认证源码 blob 相同。原审计第 7 节已描述这一行为且未单列更高或更低的等级。本次**维持**。

## 2. 逐项细查

### 2.1 Release 二进制与 Docker Hub 镜像

状态：**已核实**（产物与 `v0.3.27` 的对应关系）；**有冲突**（与当前 `main` 不是同一提交）；**无法确认**（内嵌前端未重编）。

#### 发布物是哪一次

上游 `RuoJi6/ARTEX` 的最新正式 Release 是 `v0.3.27`，发布时间 2026-11-05T09:11:51Z，页面写明发布提交 `459a4842374c6cc0f53a716d41eca907449ccbdd`。带注记的标签对象是 `ef2e8e57182fe01d6f3cb1965d72143fd812ea4e`，剥开后仍是 `459a484`。这个提交是当前 `main` 的祖先。其后还有三笔提交，所以当前 `main` 比镜像新：

| 提交 | 说明 |
| --- | --- |
| `8ee94f2` | feat: expose traffic IDs and filter finding statistics |
| `9fe993f` | Merge pull request #126 |
| `a05a886` | fix: support traffic ID copying over HTTP |

本 fork `Silver-cybersec/ARTEX` 没有 GitHub Release。默认 Compose 拉的是上游 Docker Hub 仓库。

`SHA256SUMS` 自身哈希 `aedd384635d94d27b869e01ad669e1466cbc156884a93746fae7136c37753c9f`，与 Release API 的 asset digest 一致。五个 zip 都在本机重算通过：

| 资产 | sha256 |
| --- | --- |
| `artex-0.3.27-linux-amd64.zip` | `929c98ef2fb07d51d0939989ad177350a9e8c50b6b87e8cf32acd6908f82e390` |
| `artex-0.3.27-linux-arm64.zip` | `5a14fcd9a10cc52686411323a100b5abe076bf6d894e95ae6bcc33ab54271782` |
| `artex-0.3.27-darwin-amd64.zip` | `fcd347f9bacef2de8a1fbc1535a170fdfa138316a9c65d282c5b6cf350e35ba8` |
| `artex-0.3.27-darwin-arm64.zip` | `4e40603ea69571525f834cf0776619fc3c04bec674f10cee27d5d044712ab91a` |
| `artex-0.3.27-windows-amd64.zip` | `033772bf116eeebda5b6b000e10cd5f84016c267d3252f6b4a1141aed0adbc1f` |

#### 二进制如何指回源码

`build.sh` 第 100–101 行去掉标签的 `v` 前缀，第 219–224 行以 `-tags embedui -trimpath -ldflags "-s -w -buildid= -X main.version=…"` 编译。`cmd/artex/main.go` 第 25–27 行的默认字符串是 `dev`。标签树上的源码没有字面量 `0.3.27`。Linux amd64 二进制里该字符串只作为独立的 `0.3.27` 出现一次（另外两处是依赖数据里的 CIDR 片段）。buildinfo 没有回显 `-X` 那一行，版本串与构建脚本的对应是据此推断的。

五份程序都用 `go version -m` 读取 buildinfo，没有执行：

| 文件 | sha256 | Go | 系统 | `vcs.revision` | `vcs.modified` |
| --- | --- | --- | --- | --- | --- |
| Linux amd64 `artex` | `fc6684f563e0ceb629335419325898bcc996eac81e3d89f932e87bff6b92d77f` | go1.26.10 | linux/amd64 | `459a4842374c6cc0f53a716d41eca907449ccbdd` | false |
| Linux arm64 `artex` | `064ad62f2c0ad7b95e08d21152fbaa68e90b455b78679173e784d12dcfa8e90c` | go1.26.10 | linux/arm64 | 同上 | false |
| Darwin amd64 | `60ddc3700530d2104a83bb35ac42749eb4efd036c046cc9d4d54de7659c21eb7` | go1.26.10 | darwin/amd64 | 同上 | false |
| Darwin arm64 | `d38db80655c94d1d1649bfca00cc940262bec747dac9aa4a00a27dae6bf038ff` | go1.26.10 | darwin/arm64 | 同上 | false |
| Windows amd64 `artex.exe` | `2345276e7d0fc9e5215c70a56b752d2f743d6171084ca2088065499788bc94ca` | go1.26.10 | windows/amd64 | 同上 | false |

共同的模块版本是 `github.com/Autumn-27/artex v0.0.0-20261105083707-459a4842374c`，`vcs.time` 为 `2026-11-05T08:37:07Z`。路径是 `github.com/Autumn-27/artex/cmd/artex`，构建标签 `embedui`，`CGO_ENABLED=0`，`-trimpath=true`。Linux amd64 与 arm64 的 50 条 `dep` 及 `h1` 完全相同，并且与该提交的 `go.sum` 逐条一致。`go.mod` / `go.sum` 从该提交到当前 `main` 没有差异。

`file` 结果：Linux 是静态链接、已 strip 的 ELF；Darwin 是 Mach-O；Windows 由 buildinfo 的 `GOOS=windows` 标识。这些文件都没有被执行。

zip 里除二进制以外的文件与 `git archive 459a484` 的 `skills/`、`start.sh`、`config.example.json`、`README.md` 一致。Windows 包带的是 `start.bat` 而不是 `start.sh`，与 `build.sh` 第 178–183 行一致。仓库 blob 按 `.gitattributes` 的 `*.bat text eol=crlf` 在检出时使用 CRLF；规范化换行后与包内 `start.bat` 相同。

`vcs.modified=false` 只说明被 Git 跟踪的工作区是干净的。`.gitignore` 第 47 行忽略 `/server/webui/dist/`，而正式构建会把前端静态导出放进这个目录再以 `embedui` 打进二进制。因此 buildinfo 不能单独证明内嵌页面的字节等于该提交的前端源码。`.github/workflows/release.yml` 第 48–68、90–107 行的设计是先在该提交上 `npm run build:static`，再交叉编译。对应的 GitHub Actions 运行 `41999435653` 结论为 success，`headSha` 就是 `459a484`，事件是标签 `v0.3.27` 的 push。本次没有重跑这条流水线，所以前端字节仍是无法确认。

#### 镜像 digest

2026-11-09 读取时，`latest` 与 `v0.3.27` 的 OCI index digest 相同：

`sha256:1ef7c47b7197b277524cf5992a6c0e444623f1a47d3d115debc8fe4d951c8061`

其中的平台 manifest：

| 平台 | manifest digest |
| --- | --- |
| linux/amd64 | `sha256:f7d7e986d75a525ab259c9f355a0ff4a7ac9d770074fb82f0fbd53742d752a58` |
| linux/arm64 | `sha256:3b5e1d5db927e5526ff9e8a18d1c99f7f7274686cbcfb9ae7d6b6c0f3dc7d53b` |

`v0.3.27-amd64` 与 `v0.3.27-arm64` 的 index 指向同一对平台 manifest。manifest 字节的 sha256 与 Registry 返回的 `Docker-Content-Digest` 一致，11 个 amd64 层和抽查的 arm64 应用层也都重新计算通过。

amd64 镜像配置 `sha256:a800d541c8fde61949c53f0664883f6db581f174504c5103993929a7ea322967`，创建时间 `2026-11-05T09:08:39.127311343Z`。arm64 配置创建时间 `2026-11-05T09:08:38.753737506Z`。两边标签都是：

- `org.opencontainers.image.source=https://github.com/RuoJi6/ARTEX`
- `org.opencontainers.image.version=v0.3.27`
- `org.opencontainers.image.revision=459a4842374c6cc0f53a716d41eca907449ccbdd`
- `org.opencontainers.image.licenses=AGPL-3.0`

这与 `release.yml` 第 267–271 行要写入的标签一致。配置里的入口是 `["/app/start.sh"]`，命令是 `["-addr", ":8787", "-proxy", ":8788"]`，工作目录 `/app`，`User` 为空（沿用基础镜像的 root），卷是 `/app/data`，暴露 8787/tcp 和 8788/tcp。与 `Dockerfile` 第 36–47 行一致。

amd64 的 SLSA provenance 层 `sha256:78ef6b13b881f41c4063e94a705f199186af727e13d86511642ac71b677da85b` 是未签名的 in-toto statement，predicate 为 `https://slsa.dev/provenance/v1`。subject 的 digest 就是上面的 amd64 manifest。builder id 为 `https://github.com/RuoJi6/ARTEX/actions/runs/41999435653/attempts/1`。该运行的 `docker (amd64, ubuntu-24.04)` 作业在 09:07:25Z 到 09:11:16Z 成功，`docker-publish` 在 09:11:18Z 到 09:11:39Z 成功。statement 自身的时间只有大约一秒，对应的是证明生成，不是整次镜像构建。层内没有 DSSE 签名封套，因此这是与 Actions 记录对上的来源说明，不是密码学校验过的签名。arm64 provenance 同样指向这个 tag、这个 revision 和同一次 workflow。

#### 镜像里的程序与 Release 的比对

amd64 层 `sha256:d7a6607d578a6db081208b1ca3e33d1238649c4cccb851b00197a4bd2c5fe5a0` 放入 `/app/artex`（模式 `0644`），下一层 `sha256:625598dcdfdf2a92b52f69163b9ee9d643630163bf5993556233afcbdcffcf46` 是 `chmod +x` 之后的同一文件（模式 `0755`）。两层的文件内容哈希都是 `fc6684f563e0ceb629335419325898bcc996eac81e3d89f932e87bff6b92d77f`，等于 Release 的 Linux amd64 二进制。

arm64 层 `sha256:c680250662aedeb92f32f0fe24309b219d8248e6d81c882e42c6aa52070521f2` 与 `sha256:736e7a07e785f0c943a9248ad0f9a8b28c7949a7e98761967a513b7e420330ee` 的文件内容哈希都是 `064ad62f2c0ad7b95e08d21152fbaa68e90b455b78679173e784d12dcfa8e90c`，等于 Release 的 Linux arm64 二进制。

`/app/start.sh` 在两个架构上都是 `60a83fa328b156f3cb7874950b638862c0719c1f9d6e5915b1181e4daebbce6c`，等于标签上的 `start.sh`。skills 21 个文件在 amd64 层 `sha256:490f3cfeec9bb886db6d5915c4e285988c3ed34e4c3113658b46ed71aee5a93b` 和 arm64 层 `sha256:fa0d4e8a21a383df86020b064b06555cee130c04394ef4d9dd2a5604a12fbf84` 中都与 Release、也与该提交的 `skills/` 一致。最终 `/app` 只有 `artex`、`start.sh` 和这三份 skill。镜像没有带上 zip 里的 `README.md` 和 `config.example.json`；`Dockerfile` 本来就没有复制它们。

#### 源码树里没有、镜像里有的内容

这些都出现在镜像层中，仓库源码树里没有对应文件。它们能对上 Dockerfile 或官方基础镜像，没有另见一份未声明的可执行入口。

| 内容 | 证据 | 状态 |
| --- | --- | --- |
| 官方 `python:3.12-slim-bookworm` 的四个层 | 与 provenance 记录的 index `sha256:e697c81897302a4c4333bade000d98038fbb21eb064f8ee1fd42d02ebcd9d337` 下的 amd64 manifest `sha256:623674a14ef93d052bb9b0de4dbf5f28eb578a35263838941cc8aa43213c1487` 层 digest 完全相同。镜像配置里的 `PYTHON_VERSION=3.12.16` 和 `PYTHON_SHA256` 与该官方配置一致，只多了 Dockerfile 设置的 `TZ=Asia/Shanghai` | 已核实是该历史官方 digest。当天浮动标签 `3.12-slim-bookworm` 的 index 已变为 `sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df`，层已不同 |
| apt 增加的 83 个包 | 在官方 Python 之后的层里。直接对应 Dockerfile 第 17–22 行的工具：`ripgrep 13.0.0-4+b2`、`curl`、`wget`、`vim`、`git`、`jq`、`unzip`、`dnsutils`、`iputils-ping`、`netcat-openbsd`、`inetutils-telnet`、`whois`、`nmap 7.93+dfsg1-1`，以及 `nodejs 22.23.4-1nodesource1`。其余是这些包拉进来的库。`/usr/bin/node` 内有版本串 `v22.23.4` | 已核实与 Dockerfile 的包名相符。包版本没有钉死，NodeSource 脚本正文仍未按构建当时的字节核对 |
| 全局 npm 与浏览器 | 见第 3 节。浏览器目录只有 `chromium-1248`、`chromium_headless_shell-1248`、`ffmpeg-1013`，外加 npm 缓存和一份安装日志 | 已核实来自构建当时的 `@latest` 解析，不是源码里的另一份锁定树 |
| Debian 自带的 cron、systemd 单元和锁定的 shadow | 在基础层。shadow 中账号口令字段均为锁定状态。后来的层没有新增用户、没有 `.ssh`、没有云凭据目录。容器入口仍是 `/app/start.sh`，不是 systemd | 已核实没有 ARTEX 自己安装的持久化单元 |

二进制字符串里，源码主机名之外还能看到的 URL 属于两类：锁定依赖 `norma` 的搜索端点（`html.duckduckgo.com`、`api.search.brave.com`、`api.tavily.com`，原审计 1.2 已读过该模块），以及打进前端包的库错误页（`nextjs.org`、`reactflow.dev`、`redux.js.org`、`base-ui.com`、Immer 的 `bit.ly` 文档链接）。`www.ibm.com` 出现在一份 XHTML DTD 地址中，夹在 Go 密码学库的错误文本旁边。没有私钥头，没有 GitHub token 前缀，没有 Slack token 前缀。字节序列 `AKIA` 出现在一段编码表中间，不是访问密钥的形式。

### 2.2 `/api/auth/init` 在默认部署下的认证

状态：**已核实**。发布提交与当前 `main` 的 `server/auth.go`、`server/basic_auth.go`、`Dockerfile`、`docker-compose.yml` blob 相同。`server/server.go` 在这两点之间的差异只在发现统计处理，不在路由和中间件。

#### 默认部署实际听在哪里

仓库文档中的 Docker 路径使用 `docker-compose.yml` 和 `.env.example`：

- `.env.example` 第 3–4 行默认 `ARTEX_IMAGE=ruoji6/artex`、`ARTEX_TAG=latest`。
- `docker-compose.yml` 第 18 行使用这个镜像；第 24 行把 Postgres DSN 注入容器；第 32 行把容器 8787 发布到宿主的 8787，映射里没有宿主地址，因此是宿主的所有网卡。8788 只映射到 `127.0.0.1`。
- 镜像命令把进程绑到 `:8787`。`cmd/artex/main.go` 第 55–57 行的二进制默认值也是 `-addr :8787`。`config.example.json` 只有数据库和 skill 目录，没有监听地址。
- README 第 122、130–136 行把装好后的入口写成 `http://localhost:8787`，并写明首次进入 `/setup` 设置管理员密码。

因此「默认部署」指：按 Compose 拉起当前 `latest`、连接该文件里的 Postgres、使用空数据卷。镜像若单独运行且不发布端口，容器内仍监听所有网卡，但宿主网络访问不到；那不是 Compose 默认。

#### 请求到达处理函数之前经过什么

`server/server.go` 第 1144–1148 行的包装顺序是：业务 mux，外面是 `requireAuth`，再外面是 CORS，最外面是 `requireBasicAuth`。`POST /api/auth/init` 注册在第 795 行，方法限定为 POST。

`requireAuth`（`server/auth.go` 第 120–126 行）对整个 `/api/auth/` 前缀直接放行，不读令牌。`authInit`（第 157–205 行）自身也不调用 `verifyJWT`。同一前缀下的改密处理函数在第 216–218 行另外检查了令牌；初始化函数没有这一步。

`requireBasicAuth`（`server/basic_auth.go` 第 125–132 行）在配置 `Enabled` 为 false 时直接放行。`load`（第 46–70 行）在数据库没有 `auth.http_basic` 时保持零值，`Enabled` 为 false。`db/schema.sql` 第 356–360 行只建 `settings` 表，不插入该键，也不插入 `auth.password_hash`。启用 Basic Auth 的接口在 `server/server.go` 第 802–803 行，不在 `/api/auth/` 放行名单里，所以要先有管理员 JWT。空库上不存在先打开 Basic Auth、再挡住第一次初始化的默认路径。

CORS（`server/server.go` 第 4491–4514 行）不检查身份。它不构成这道门。

数据库未连接时，`server/server_mgmt.go` 第 69–73 行的 `pg()` 返回 503。默认 Compose 会等 Postgres 健康后再启动应用，并提供 DSN，因此会走到真正的初始化逻辑。

#### 什么时候关闭

关闭条件是 `settings` 中键 `auth.password_hash` 的值非空：

- 第 163–170 行：读到非空哈希返回 403，正文表示密码已设置。
- 第 164–166 行：读失败返回 503，不把故障当成未初始化。这保持了原审计已经记录的修复。
- 第 188–198 行：真正写入使用 `InsertSettingIfAbsent`（`db/settings.go` 第 63–78 行），冲突时不覆盖，并同样返回 403。
- 改密（`server/auth.go` 第 254 行）和 `reset-password.sh` 第 143–145 行都是 upsert 一个新哈希，键还在，初始化入口保持关闭。
- 仓库产品代码没有删除这个键的语句。删掉该行，或换掉空的 Postgres 卷，入口会重新打开。重启本身不会重新打开，因为值在 `pgdata` 卷里。

`GET /api/auth/status`（第 144–154 行）同样不在令牌检查之内，只报告 `initialized` 是否为真。前端 `web/src/app/(auth)/login/page.tsx` 第 55–56 行在未初始化时转到 `/setup`，`setup/page.tsx` 第 50 行再调用初始化接口。页面校验不是服务器上的门。

`.github/workflows/release.yml` 第 239–257 行的镜像冒烟步骤，在任何管理员令牌出现之前就访问这条路由，用来确认新容器能完成首次设置。这里只把它当作设计意图的源码证据，不复述该步骤的请求。

## 3. 供应链补充

这一节只补充本次从 Release 和镜像里新看到的锁定情况。原审计已经在同一天核对过 `go.sum` 与 npm lock，并查过 OSV。本次没有重装依赖。

### 3.1 版本锁定与校验和

| 对象 | 锁定方式 | 本次核对 | 来源 |
| --- | --- | --- | --- |
| Release zip | 同一 Release 中的 `SHA256SUMS` | 五个 zip 的本机 sha256 与 SUMS、与 GitHub asset digest 一致 | `RuoJi6/ARTEX` 标签 `v0.3.27` 的 Actions 运行 `41999435653` |
| 镜像程序 | 没有写进 Compose 的 digest。当天 `latest` 碰巧等于 `v0.3.27` 的 index | 两个 Linux 二进制与上表 Release 文件字节相同 | 同上一次发布 |
| Go 模块 | `go.sum` 的 `h1` | buildinfo 中 50 个模块的版本和 `h1` 与该提交的 `go.sum` 一致 | 模块路径与原审计相同，主模块构建用的是 go1.26.10 |
| 基础镜像 | Dockerfile 第 13 行只有标签 | 这一份镜像的层等于官方 index `sha256:e697c818…` 的 amd64 manifest。当天同名标签已经换过层 | `library/python` |
| Dockerfile 里的三个 `@latest` | 无 lock、无 digest | 构建日志写明当时解析为下面的版本，并且文件与 registry tarball 一致 | `registry.npmjs.org` |
| Node | `setup_22.x` 后安装 Node 22 主版本 | 装上的包是 `nodejs 22.23.4-1nodesource1`。脚本在构建当时的正文没有留在镜像里 | 包版本后缀表明是 NodeSource 包 |

镜像内 npm 安装日志（`/root/.npm/_logs/2026-11-05T09_08_16_835Z-debug-0.log`）记录从 `https://registry.npmjs.org` 取得：

| 包 | 镜像中的版本 | registry `dist.integrity` | 与镜像中文件比对 |
| --- | --- | --- | --- |
| `@playwright/cli` | 0.1.23 | `sha512-+TuHfVgpK1SIlwyV7bcZ9SRRhnVOAIwJwxZCgEh5LWkZuyGfSYnHNx8J7H78dhCwMyLkJtGb/j5XICjzEKzrfg==` | tarball 16 个文件全部一致，sha512 一致 |
| `@playwright/mcp` | 0.0.84 | `sha512-weqLrA7/D8MJzNV9/t3Hnjp100tS2sxFXKeb2gH6Nhktqmdfvx5qRA9AZ5Mhjnre1jY0wltsrRK5VZS5NBgcvw==` | 7 个文件全部一致 |
| `playwright` | 1.64.1（全局入口） | `sha512-HCrVhHr5QQuwYoswEUGTb7gGp522yflbv/ST8nF4sFWGuLjQCt17Q/EubpGGSNKYn1tsTCPZxqHhHCfVURu7UA==` | 60 个文件全部一致 |
| `playwright` | `1.65.0-alpha-2026-10-30`（cli 与 mcp 各自的依赖副本） | `sha512-dmAJMVHKzHvMQjn+XDcaq/pxaZ0W6n8i78rwTM+VGRtQ3WBF5ZiSdB1yL/cyoYUGUMwg3jxN65KqC9cERaCbIg==` | 两份副本共 60 个文件，彼此相同且与 tarball 一致 |
| `playwright-core` | 1.64.1 | `sha512-BC4s8y6SEVA6Q1rSxZTto8hI1KUI3xXlHGZgvGqP4IqPdI/a6FX9H29IDNz7vKo9l21b6LfYosScPL6M3xxyDQ==` | 115 个文件全部一致 |
| `playwright-core` | `1.65.0-alpha-2026-10-30` | `sha512-LPMw8B/HRQKMcJeXTqWSrkB/AfCKKmbDQMbu0p7zg8MgibOWaKMjZWR/StAtrQkOxvOmZEju1o1TnPgdoOCwrg==` | 两份副本共 116 个文件，彼此相同且与 tarball 一致 |

维护者名称是 `pavelfeldman`、`yurys`、`dgozman-ms`、`microsoft-oss-releases`、`microsoft1es`。这些包的 scripts 列表里没有 `install` 或 `postinstall`。全局 `playwright@1.64.1` 的 `browsers.json` 把 Chromium 修订号写成 1248、浏览器版本 `156.0.8078.4`，与镜像里的 `chromium-1248` 目录一致。

当天 registry 的 `latest` 已是 `playwright@1.65.0` 和 `playwright-core@1.65.0`，而 `@playwright/cli` 与 `@playwright/mcp` 的 latest 仍是镜像里的 0.1.23 和 0.0.84。按现在的 Dockerfile 重编，顶层 `playwright@latest` 会变成另一个版本。cli/mcp 仍会带上它们依赖字段里写死的 alpha。这就是原审计说 `@latest` 未锁定的具体内容：这一份镜像已经能对上官方 tarball，下一次构建不再受这次字节约束。

### 3.2 OSV / GHSA / 恶意包记录

2026-11-09 对 `https://api.osv.dev/v1/querybatch` 的查询：

- 上面六个 npm 版本：各 0 条。没有 `MAL-*`。
- buildinfo 里的 50 个 Go 模块版本：46 个为 0 条。有记录的仍是原审计 1.6 的那一组，编号没有增减：`golang.org/x/crypto@v0.55.0` 的 `GO-2026-5932`、`GO-2026-6354`、`GO-2026-6355`；`golang.org/x/net@v0.58.0` 的 `GO-2026-6603`、`6610`、`6611`、`6612`、`6617`、`6860`、`6866`；`github.com/klauspost/compress@v1.18.6` 的 `GHSA-259r-337f-4rfw`、`GO-2026-5841`、`GO-2026-6865`；`github.com/andybalholm/brotli@v1.2.1` 的 `GO-2026-6888`。没有 `MAL-*`。
- `github.com/golang-jwt/jwt/v5@v5.3.1`、`pgx`、`sqlite`、`norma`、`go-mitmproxy`、`dnsx` 这次仍是 0 条。

GHSA 编号来自上述 OSV 结果，没有另调 GitHub Advisory REST。Socket.dev 一类需要密钥的商业恶意包库没有查询，那一部分维持无法确认。apt 包没有逐个做 OSV。这些已知漏洞记录描述的是锁定版本上的公开缺陷，不是本次在镜像里新发现的仿冒包。

对原审计供应链定级的影响：**维持**。新证据把「镜像层完全没看过」收窄了，但 Compose 仍使用无 digest 的 `latest`，Dockerfile 仍使用无 lock 的 `@latest`，而且这次实际解析进了一份 Playwright alpha。

## 4. 未确认项与原因

- 内嵌前端的逐字节内容。`server/webui/dist/` 被 gitignore，本次没有执行 `npm run build:static` 或 `go build`，不能把二进制里的页面和该提交的源码重新对一遍。
- SLSA statement 的密码学签名。层里只有 JSON，没有签名封套。与 Actions 运行记录的对应是已核实的旁证。
- 构建当时 `https://deb.nodesource.com/setup_22.x` 的脚本正文。镜像只留下安装结果 `nodejs 22.23.4-1nodesource1`。今天再取脚本也不能证明就是 2026-11-05 管道进 shell 的那一份。
- CPython 源码包没有重新下载。镜像里的 `PYTHON_SHA256` 与对应官方镜像配置相同；对 `python.org` 上两个猜测的校验文件名请求返回 404，所以没有独立重算这个哈希。
- 今天之后 `latest` 是否还会指向 `sha256:1ef7c47b…`。本文只证明读取当时它与 `v0.3.27` 相同。
- Darwin 与 Windows 程序不在 Docker 镜像里。它们的 buildinfo 已指向同一提交，但没有镜像层可以比对。
- 商业恶意包库，以及 apt / NodeSource 包的逐条 CVE。
- 空库上的接口行为没有对真实进程复测。结论来自源码、镜像命令和该提交的 blob 同一性。按本次规则，没有启动容器或二进制。

## 5. 方法与读取过的 URL

做了的事：读本仓库源码与 `git archive 459a484`；用 GitHub CLI 读 Release 与 Actions 元数据；下载五个 Release zip 和 `SHA256SUMS`，解包后计算哈希、用 `file` 和 `go version -m` 读 buildinfo、用字符串扫描看版本与 URL。对 Docker Hub 只调用了 Registry 的 token、manifest 和 blob 接口，校验 digest 后在本地解包层。对 npm 下载了上述六个 tarball 并与镜像内文件逐个比 sha256。对 OSV 使用了 `querybatch`。

没有做的事：没有 `docker run`、没有执行任何 `artex`、没有运行仓库脚本、没有 `npm install` 或 `go test`、没有访问任何部署好的 8787 端口。

读取过的 URL：

- `https://github.com/RuoJi6/ARTEX/releases/tag/v0.3.27`
- `https://github.com/RuoJi6/ARTEX/releases/download/v0.3.27/SHA256SUMS`
- `https://github.com/RuoJi6/ARTEX/releases/download/v0.3.27/artex-0.3.27-linux-amd64.zip`
- `https://github.com/RuoJi6/ARTEX/releases/download/v0.3.27/artex-0.3.27-linux-arm64.zip`
- `https://github.com/RuoJi6/ARTEX/releases/download/v0.3.27/artex-0.3.27-darwin-amd64.zip`
- `https://github.com/RuoJi6/ARTEX/releases/download/v0.3.27/artex-0.3.27-darwin-arm64.zip`
- `https://github.com/RuoJi6/ARTEX/releases/download/v0.3.27/artex-0.3.27-windows-amd64.zip`
- `https://github.com/RuoJi6/ARTEX/actions/runs/41999435653`
- `https://hub.docker.com/v2/repositories/ruoji6/artex/tags?page_size=25`
- `https://auth.docker.io/token?service=registry.docker.io&scope=repository:ruoji6/artex:pull`
- `https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/python:pull`
- `https://registry-1.docker.io/v2/ruoji6/artex/manifests/latest`
- `https://registry-1.docker.io/v2/ruoji6/artex/manifests/v0.3.27`
- `https://registry-1.docker.io/v2/ruoji6/artex/manifests/v0.3.27-amd64`
- `https://registry-1.docker.io/v2/ruoji6/artex/manifests/v0.3.27-arm64`
- `https://registry-1.docker.io/v2/ruoji6/artex/manifests/sha256:f7d7e986d75a525ab259c9f355a0ff4a7ac9d770074fb82f0fbd53742d752a58`
- `https://registry-1.docker.io/v2/ruoji6/artex/manifests/sha256:3b5e1d5db927e5526ff9e8a18d1c99f7f7274686cbcfb9ae7d6b6c0f3dc7d53b`
- `https://registry-1.docker.io/v2/ruoji6/artex/manifests/sha256:1f94fdff598e0b8b9f82bf6e2c791a8d33222ba215f3452f8931e508be935b0a`
- `https://registry-1.docker.io/v2/ruoji6/artex/manifests/sha256:98a0e46bb90731a780a44c8fc3fb01fe587fe56e12711f78bff98da908e3202a`
- `https://registry-1.docker.io/v2/ruoji6/artex/blobs/` 下该 amd64 manifest 的 config、11 个层，以及 arm64 的 config、provenance 和四个应用层
- `https://registry-1.docker.io/v2/library/python/manifests/sha256:e697c81897302a4c4333bade000d98038fbb21eb064f8ee1fd42d02ebcd9d337`
- `https://registry-1.docker.io/v2/library/python/manifests/sha256:623674a14ef93d052bb9b0de4dbf5f28eb578a35263838941cc8aa43213c1487`
- `https://registry-1.docker.io/v2/library/python/manifests/3.12-slim-bookworm`
- `https://registry-1.docker.io/v2/library/python/manifests/sha256:0f086103b026048cc50cb5da25ec435c023c5241a83fc44daea593377abc61c4`
- `https://registry-1.docker.io/v2/library/python/blobs/sha256:37ccb536022bb36c4570856b55ebfa85bf07827e3c2fa3eba37f0dac62eebc05`
- `https://registry.npmjs.org/@playwright/cli/0.1.23`
- `https://registry.npmjs.org/@playwright/mcp/0.0.84`
- `https://registry.npmjs.org/playwright/1.64.1`
- `https://registry.npmjs.org/playwright/1.65.0-alpha-2026-10-30`
- `https://registry.npmjs.org/playwright-core/1.64.1`
- `https://registry.npmjs.org/playwright-core/1.65.0-alpha-2026-10-30`
- `https://registry.npmjs.org/@playwright/cli/latest`
- `https://registry.npmjs.org/@playwright/mcp/latest`
- `https://registry.npmjs.org/playwright/latest`
- `https://registry.npmjs.org/playwright-core/latest`
- `https://registry.npmjs.org/@playwright/cli/-/cli-0.1.23.tgz`
- `https://registry.npmjs.org/@playwright/mcp/-/mcp-0.0.84.tgz`
- `https://registry.npmjs.org/playwright/-/playwright-1.64.1.tgz`
- `https://registry.npmjs.org/playwright/-/playwright-1.65.0-alpha-2026-10-30.tgz`
- `https://registry.npmjs.org/playwright-core/-/playwright-core-1.64.1.tgz`
- `https://registry.npmjs.org/playwright-core/-/playwright-core-1.65.0-alpha-2026-10-30.tgz`
- `https://api.osv.dev/v1/querybatch`
- `https://www.python.org/ftp/python/3.12.16/Python-3.12.16.tgz.sha256`（404）
- `https://www.python.org/ftp/python/3.12.16/Python-3.12.16.tar.xz.sha256`（404）
