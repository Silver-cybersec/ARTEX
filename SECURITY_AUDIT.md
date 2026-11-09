# ARTEX 静态安全审计

审计对象是当前检出的 `main`，提交 `a05a886d3da624bd070f9b984025e27dfa82bdb6`。该提交同时是 `Silver-cybersec/ARTEX` 和上游 `RuoJi6/ARTEX` 在 2026-11-09 的 `main` 顶端，这次检出没有相对上游多出来的提交。

审计方式是只读静态阅读：没有运行仓库里的程序、安装脚本、二进制或 Docker 镜像，没有执行 `npm ci`、`go build`、`go mod download`，也没有对任何真实目标发请求。依赖结论来自仓库里的清单和 lock，以及 2026-11-09 对 `sum.golang.org`、`registry.npmjs.org`、`proxy.golang.org` 和 OSV（`api.osv.dev`）的查询。`github.com/Autumn-27/norma@v0.4.3` 的模块 zip 从官方模块代理下载到临时目录后只做了文本阅读，没有执行。

风险等级：高、中、低、信息。看不到或没有取回内容的项写成「未确认」，不把它写成恶意或无害。

## 结论

**有可疑点待确认**

已经读过的仓库源码，以及校验和能对上官方记录的 Go 模块和 npm 包里，没有发现隐藏回传、混淆载荷，也没有 OSV 恶意包记录（本次查询没有 `MAL-*`）。

这个结论覆盖不到安装时才会取回、而这次没有取回内容的对象：`https://get.docker.com` 的安装脚本、NodeSource 的 `setup_22.x`、Dockerfile 里三个 `@latest` npm 包和随后下载的 Chromium、没有钉 digest 的容器镜像，以及页面一键更新会下载的上游 Release 二进制。这些都是未确认。

另外，锁定版本上有公开漏洞记录。那是已知 CVE，不是仓库里另藏的一份后门。

## 1. 供应链

这一章只回答「拉取依赖时会拿到什么，以及这次能确认到哪一步」。

### 1.1 仓库里会触发的外部拉取

| 来源 | 会拉取什么 | 版本是否锁定 | 校验 | 谁会触发 |
| --- | --- | --- | --- | --- |
| `go.mod` / `go.sum` | 74 个 Go 模块 | 是，`go.sum` 有每个模块的 `h1` | 2026-11-09 与 `sum.golang.org` 全部一致 | `go build`、`./install.sh` 的本地编译、`./build.sh` |
| `go.mod` 第 3 行 `go 1.26.10` | 官方 Go 工具链（本地版本更低且 `GOTOOLCHAIN=auto` 时） | 语言版本写了 1.26.10，仓库没有 `toolchain` 行 | 工具链走官方校验和数据库 | 同上 |
| `web/package.json` + `web/package-lock.json` | 直接依赖见 1.3，加上 795 个带 `resolved` 的包（含传递依赖） | lockfileVersion 3，每个包有版本和 `integrity` | 795 个 `integrity` 与当天 `registry.npmjs.org` 上同版本一致 | `npm ci`、`./install.sh`、`./update.sh`、`./build.sh`、CI |
| `web/package.json` 的 `prepare` | 不下载新代码；`npm ci` 会执行 `husky`，钩子内容在仓库里 | 不适用 | 不适用 | `npm ci` / `npm install` |
| `skills/api-recon/scripts/package.json` + lock | `puppeteer-core` 及其 85 个包 | 有版本和 `integrity` | `integrity` 与 npmjs 官方一致；`resolved` 主机是镜像 | 只有在该目录执行 `npm install` / `npm ci` 时 |
| `Dockerfile` | 基础镜像、Debian 包、NodeSource 脚本、三个全局 npm 包、Chromium | 见 1.4、1.5 | 镜像和 `@latest` 没有 digest / lock | `docker build` |
| `docker-compose.yml` | `postgres:16-alpine`、`${ARTEX_IMAGE:-ruoji6/artex}:${ARTEX_TAG:-latest}` | 标签，没有 digest | 无 | `docker compose pull/up`、`./install.sh` 的 Docker 路径 |
| `docker-compose.bench.yml` | 指向仓库中不存在的 `Dockerfile.bench` 和 `bench/.env` | 未确认 | 未确认 | 该 compose 被执行时 |
| `install.sh` | `https://get.docker.com` | 无版本、无哈希 | 无 | 选择 Docker 安装且本机没有 Docker、并回答 `y` 时 |
| `skills/playwright-cli/SKILL.md` | `npm install -g @playwright/cli@latest` | `@latest` | 无 | 按该 skill 安装 CLI 时 |
| `db/db.go` 播种的 browser MCP | `npx @playwright/mcp` | 无版本 | 无 | 用户启用该 MCP 后，启动发现或调用时 |
| `selfupdate` | `https://api.github.com/repos/RuoJi6/ARTEX/releases/latest` 及对应 zip | 运行时的最新正式版 | Release 里的 `SHA256SUMS`，与 zip 同一发布 | 已登录页面加载时只查询版本；用户点击更新才下载 |
| Git submodule、`requirements*.txt`、`poetry.lock`、`Pipfile`、`Cargo.lock`、`vendor/` | 无 | — | — | 不会从这些入口拉取 |

没有发现 `replace` 指令、`GOPROXY` 私有地址、短链，或 lock 里指向 `file:`、`git+`、`unpkg`、`jsDelivr` 的包。

### 1.2 Go 模块

`go.mod` 模块路径是 `github.com/Autumn-27/artex`（第 1 行），Go 版本 `1.26.10`（第 3 行）。直接依赖：

| 模块 | 锁定版本 | 来源 | 说明 |
| --- | --- | --- | --- |
| `github.com/Autumn-27/norma` | v0.4.3 | 作者个人仓库，Apache-2.0 | 智能体运行时，含 Bash。见下方 |
| `github.com/lqqyt2423/go-mitmproxy` | v1.9.2 | 个人仓库上的公开 MITM 库 | 本地流量记录代理 |
| `github.com/projectdiscovery/dnsx` | v1.2.3 | projectdiscovery | 资产富化用的 DNS 库 |
| `github.com/miekg/dns` | v1.1.72 | 公开 DNS 库 | dnsx 的底层依赖 |
| `github.com/jackc/pgx/v5` | v5.10.0 | 公开 PostgreSQL 驱动 | |
| `github.com/golang-jwt/jwt/v5` | v5.3.1 | 公开 JWT 库 | 本次 OSV 无记录 |
| `golang.org/x/crypto` | v0.55.0 | Go 官方扩展 | 有 OSV 记录，见 1.7 |
| `golang.org/x/net` | v0.58.0 | Go 官方扩展 | 有 OSV 记录，见 1.7 |
| `golang.org/x/text` | v0.41.0 | Go 官方扩展 | 本次 OSV 无记录 |
| `modernc.org/sqlite` | v1.52.0 | 公开纯 Go SQLite | |
| `mvdan.cc/sh/v3` | v3.10.0 | 公开 shell 解析器 | 拦截规则分析脚本 |
| `github.com/google/uuid` | v1.6.0 | 公开 | |
| `github.com/klauspost/compress` | v1.18.6 | 公开 | 有 OSV 记录，见 1.7 |

`go.sum` 里另外 61 个间接模块同样有 `h1`。2026-11-09 用大小写编码后的模块路径逐个查询 `sum.golang.org`，74 个模块的 zip 哈希和 `/go.mod` 哈希全部一致。构建时只要保持默认的 `GOSUMDB=sum.golang.org`（`build.sh` 第 20、92 行把默认值设成 `sum.golang.org`），Go 会拒绝和这条记录不一致的 zip。

`norma` 需要单独看，因为它实现了模型能调用的 shell，而且仓库作者和模块作者是同一个人（GitHub 用户 Autumn-27，仓库创建于 2026-07-20，审计时约 157 star）。核对结果：

- `go.sum` 第 1–2 行的 `h1:DnmOhJPL6OZSMnCVYO5Ujh4yVINuDarEickVi9jx1hI=` 与 `sum.golang.org` 上 `github.com/Autumn-27/norma@v0.4.3` 一致。
- 代理上的 zip 来源记录为 `https://github.com/Autumn-27/norma`，标签 `v0.4.3`，提交 `320ae32989da97dd91469bb89164cbfe87d83d5d`，发布时间 2026-09-30。
- 非测试代码里的 URL 是 `https://api.anthropic.com`、`https://api.openai.com/v1`、`https://api.deepseek.com/v1`、`https://html.duckduckgo.com/html/`、`https://api.search.brave.com/res/v1/web/search`、`https://api.tavily.com/search`。前三个是模型默认端点，后四个是搜索后端。
- `tool/bash.go` 通过 `exec.CommandContext` 执行 `bash -c`（Windows 上是 `powershell -NoProfile -NonInteractive -Command`）。`tool/task.go` 第 140–144 行的 `withEnv` 把额外环境变量追加到 `os.Environ()` 后面。因此进程里的 `ANTHROPIC_API_KEY`、`OPENAI_API_KEY`、`ARTEX_PG_DSN` 会进入 shell。这是 shell 工具的行为，不是另一段隐藏外传。
- `harness/event.go` 里的 “telemetry” 是注释里的循环原因枚举，没有外发代码。
- 没有在这份 zip 里看到读取 `~/.ssh`、浏览器 Cookie 目录或系统钥匙串的代码。

`github.com/satori/go.uuid@v1.2.0` 是间接依赖。它是已停止维护的旧 UUID 库，名字对应的是这个历史模块，不是一个新注册的仿冒包。本次 OSV 没有把它标成恶意包。

### 1.3 npm

`web/package-lock.json`：795 个 `resolved` 全部是 `https://registry.npmjs.org`，全部有 `integrity`，当天与官方 registry 的 `dist.integrity` 一致。唯一 `hasInstallScript: true` 的是可选依赖 `sharp@0.34.5`（`web/package-lock.json` 第 10107–10112 行）。该包哈希与官方 `sharp@0.34.5` 一致，所以脚本属于这份官方包；本次没有执行脚本，脚本运行时还会不会下载 libvips 预编译文件，未确认。

`web/package.json` 第 14 行 `"prepare": "husky"`。`npm ci` 会跑它。`web/.husky/pre-commit` 只执行仓库内的 `npm run generate:presets` 和 `lint-staged`，没有联网命令。

直接依赖的锁定版本、创建日期和维护者来自 2026-11-09 的 npm registry。下载量是该 API 的 `last-month`。没有发现与知名包差一个字母的包名，也没有非 ASCII 包名。

| 包 | 锁定版本 | 创建日期 | 维护者 / 仓库 | 近月下载 | 备注 |
| --- | --- | --- | --- | --- | --- |
| `next` | 16.2.9 | 2011-07-11 | vercel-release-bot；vercel | 未单列 | 直接依赖，OSV 有记录 |
| `react` / `react-dom` | 19.2.7 | 官方包 | fb、react-bot | 未单列 | 本次 OSV 无记录 |
| `zod` | 4.4.3 | 2020-03-07 | colinhacks | 未单列 | 直接依赖，OSV 有记录；树里还有 3.25.76 和 3.23.8 |
| `postcss` | 8.5.16 | 2013-11-04 | ai | 未单列 | 直接开发依赖；树里还有 8.4.31 |
| `@shadcn/react` | 0.1.0 | 2026-06-26 | shadcn；`shadcn-ui/ui` | 约 1757 万 | 官方组织。锁定的是首个 0.1.0，registry 上 latest 已是 0.3.1 |
| `shadcn` | 4.12.0 | 2024-07-09 | shadcn；`shadcn-ui/ui` | 约 5589 万 | 官方 CLI。latest 已是 4.23.0 |
| `geist` | 1.7.2 | 2015-09-19 | vercel-release-bot；`vercel/geist-font` | 约 1321 万 | Vercel 字体包 |
| `@base-ui/react` | 1.6.0 | 2025-12-11 | MUI 维护者；`mui/base-ui` | 约 8659 万 | 较新，但是 MUI 官方库 |
| `radix-ui` | 1.6.0 | 2022-08-01 | WorkOS/Radix 维护者；`radix-ui/primitives` | 约 8284 万 | |
| `tw-animate-css` | 1.4.0 | 2025-03-10 | wombosvideo；`Wombosvideo/tw-animate-css` | 约 1.61 亿 | 个人仓库，下载量高，OSV 无恶意记录 |
| `vaul` | 1.1.2 | 2023-07-22 | emilkowalski | 约 1.18 亿 | |
| `input-otp` | 1.4.2 | 2024-02-19 | guilhermerodz | 约 9939 万 | |
| `@antv/g6` | 5.1.1 | 2017-04-11 | AntV | 未单列 | |
| `@antv/graphin` | 3.0.5 | 2019-11-16 | AntV | 未单列 | |
| 其余直接依赖 | 见 lock | 2014–2024 的常见库 | CodeMirror、dnd-kit、FullCalendar、TanStack、xyflow、date-fns、lucide、tailwind、biome、husky、typescript 等 | 未逐个拉下载量 | 包名和仓库都对应各自的公开项目 |

其余直接依赖的锁定版本：`@codemirror/commands@6.11.1`、`lang-html@6.4.12`、`lang-json@6.0.2`、`language@6.13.1`、`search@6.7.2`、`state@6.7.6`、`view@6.43.15`、`@dnd-kit/core@6.3.1`、`modifiers@9.0.0`、`sortable@10.0.0`、`@fullcalendar/react@7.0.0`、`@hookform/resolvers@5.4.0`、`@tanstack/react-table@8.21.3`、`@xyflow/react@12.11.1`、`class-variance-authority@0.7.1`、`clsx@2.1.1`、`cmdk@1.1.1`、`d3-geo@3.1.1`、`date-fns@4.4.0`、`embla-carousel-react@8.6.0`、`lucide-react@1.22.0`、`next-themes@0.4.6`、`react-day-picker@10.0.1`、`react-hook-form@7.80.0`、`react-is@19.2.7`、`react-markdown@10.1.0`、`react-resizable-panels@4.12.0`、`recharts@3.8.0`、`remark-gfm@4.0.1`、`simple-icons@16.24.1`、`sonner@2.0.7`、`tailwind-merge@3.6.0`、`temporal-polyfill@1.0.1`、`topojson-client@3.1.0`、`zustand@5.0.14`、`@biomejs/biome@2.5.1`、`@tailwindcss/postcss@4.3.2`、`@types/d3-geo@3.1.0`、`@types/node@22.20.0`、`@types/react@19.2.17`、`@types/react-dom@19.2.3`、`@types/topojson-client@3.1.5`、`babel-plugin-react-compiler@1.0.0`、`husky@9.1.7`、`lint-staged@16.4.0`、`tailwindcss@4.3.2`、`ts-node@10.9.2`、`typescript@5.9.3`。

`skills/api-recon/scripts/package-lock.json` 是另一条供应链：

- 风险：中。
- 位置：该文件第 2–4 行名字是 `spa-api-recon-runtime`；`package.json` 第 2 行名字是 `api-recon-runtime`。第 16 行起 85 个 `resolved` 都是 `https://registry.npmmirror.com`。
- 证据：85 个 `integrity` 与 `registry.npmjs.org` 上同名同版本一致，其中包括 `puppeteer-core` 和 `@puppeteer/browsers@2.6.1`。没有 `hasInstallScript`。
- 判断：当前 lock 钉住的字节和官方 npm 相同。`resolved` 仍指向第三方镜像。若以后在镜像上重新生成 lock，或用忽略 `integrity` 的安装方式，内容就不再受这次核对约束。两个包名不一致，未执行 `npm ci`，是否会被 npm 拒绝，未确认。

`puppeteer-core` 只提供库，不自带浏览器。`runtime_harvest.js` 第 46 行默认去找本机 `/usr/bin/chromium`。

### 1.4 容器镜像

| 镜像 | 位置 | digest | 判断 |
| --- | --- | --- | --- |
| `python:3.12-slim-bookworm` | `Dockerfile` 第 13 行 | 无 | 官方库标签。标签会移动。镜像层内容未拉取，未确认 |
| `postgres:16-alpine` | `docker-compose.yml` 第 3 行；`.github/workflows/release.yml` 第 207 行 | 无 | 官方库标签。未拉取，未确认 |
| `ruoji6/artex:latest` | `docker-compose.yml` 第 18 行；`.env.example` 第 3–4 行默认 `ARTEX_IMAGE=ruoji6/artex`、`ARTEX_TAG=latest` | 无 | 上游个人 Docker Hub 仓库的浮动标签。这次审计没有覆盖该镜像里的二进制。风险：高（若直接 `compose pull` 而不从本仓库构建） |
| `artex-bench:latest` | `docker-compose.bench.yml` 第 13–16 行 | 无 | `Dockerfile.bench` 和 `bench/.env` 不在这个检出里。镜像内容未确认 |

`docker-compose.bench.yml` 第 23 行是 `network_mode: host`。注释写明容器使用宿主网络，并占用宿主的 8787、8788 和 5432。对应 Dockerfile 不在仓库中，实际镜像未确认；网络模式本身会让容器和宿主共用网络栈。

### 1.5 脚本和运行时动态拉取

1. `install.sh` 第 22 行：`curl -fsSL https://get.docker.com | sh`。风险：高。没有版本和哈希，脚本内容未确认。只在 Linux、本机没有 Docker、并且用户回答 `y` 时执行。同一脚本还会 `docker compose pull`（第 50 行）和 `npm ci && go build`（第 100–103 行）。
2. `Dockerfile` 第 21 行：`curl -fsSL https://deb.nodesource.com/setup_22.x | bash -`。风险：高。脚本未确认。随后 `apt-get install nodejs` 只约束 Node 22 这条主版本，不钉包版本。第 17–20 行的 apt 包（`ripgrep`、`curl`、`nmap` 等）也没有钉版本。
3. `Dockerfile` 第 29–31 行：`npm install -g @playwright/mcp@latest @playwright/cli@latest playwright@latest`，然后 `playwright install --with-deps chromium`。风险：高。三个包和浏览器二进制都是构建当时的最新版，仓库里没有 lock，也没有哈希。内容未确认。
4. `skills/playwright-cli/SKILL.md` 第 354 行把 `npm install -g @playwright/cli@latest` 写进 skill。风险：中。这是文档里的命令，不是安装脚本自动执行；模型或操作者照做时会拉取未锁定的全局包。
5. `db/db.go` 第 262–266 行播种 MCP：命令 `npx`，参数 `@playwright/mcp --headless`，`enabled=false`。风险：中。默认不启用。启用后 `npx` 可能下载未锁定的包。Docker 镜像若按当前 Dockerfile 构建，会提前装一个同样未锁定的全局包。
6. `selfupdate/github.go` 第 16–29 行把更新源写死为 `RuoJi6/ARTEX`，只允许 `api.github.com`、`github.com`、`objects.githubusercontent.com`、`release-assets.githubusercontent.com`、`raw.githubusercontent.com`。风险：中，对这个 fork 是高。页面加载会查最新正式版（`web/src/app/(main)/_components/update-badge.tsx` 第 24–27 行，挂在 `main-content.tsx` 第 85 行）。查询本身只访问 GitHub Release API，不上传本地密钥。用户确认更新后，下载的是上游仓库的 zip，并用同一 Release 的 `SHA256SUMS` 核对。校验能发现传输损坏，不能代替对上游发布者的信任。fork 上点一次更新，会换成上游二进制。本次没有下载或阅读任何 Release zip，二进制内容未确认。
7. CI 才有的拉取（本地安装不会跑）：`actions/checkout@v4`、`actions/setup-node@v4`、`actions/setup-go@v5`、`actions/upload-artifact@v4`、`actions/download-artifact@v4`、`actions/github-script@v7`、`softprops/action-gh-release@v2`、`docker/setup-buildx-action@v3`、`docker/login-action@v3`、`docker/build-push-action@v6`。这些是可变标签，不是提交 SHA。`.github/workflows/demo.yml` 第 121 行安装 `vercel@64.2.0`，有版本、没有 lock 和 `integrity`。Actions 标签和 Vercel CLI 的当前内容未确认。

### 1.6 公开漏洞和恶意包记录

查询时间 2026-11-09。OSV `querybatch` 覆盖 `go.sum` 的 74 个模块，以及两个 npm lock 里 861 个不重复的包版本。OSV 汇总了 GitHub Advisory。没有 `MAL-*` 恶意包记录。

下面这些记录打在锁定版本上。本次没有追每条公告是否能从本仓库的调用点触发，除了特别写明的以外，可达性未确认。公告标题只说明漏洞类别，不包含利用步骤。

Go：

| 模块 | 版本 | 记录 | 摘要 |
| --- | --- | --- | --- |
| `golang.org/x/crypto` | v0.55.0 | `GO-2026-5932` | `openpgp` 子包已停止维护。本仓库没有 import 它 |
| 同上 | 同上 | `GO-2026-6354` / `CVE-2026-78662`，`GO-2026-6355` / `CVE-2026-56855` | `x/crypto/ssh` 通道死锁导致的拒绝服务 |
| `golang.org/x/net` | v0.58.0 | `GO-2026-6603` / `CVE-2026-78659`，`6610` / `CVE-2026-78660`，`6611` / `CVE-2026-78669`，`6612` / `CVE-2026-78663`，`6617` / `CVE-2026-97032` | HTTP/2 内存、帧处理和崩溃类问题 |
| 同上 | 同上 | `GO-2026-6860` / `CVE-2026-78661`，`GO-2026-6866` / `CVE-2026-97045` | `x/net/html` 的 CPU 和命名空间处理 |
| `github.com/klauspost/compress` | v1.18.6 | `GHSA-259r-337f-4rfw` / `CVE-2026-63209` / `GO-2026-5841`，`GO-2026-6865` / `CVE-2026-116591` | `s2` 越界和特定帧上的 panic |
| `github.com/andybalholm/brotli` | v1.2.1 | `GO-2026-6888` | 解压特制流时的过量内存分配 |

`github.com/golang-jwt/jwt/v5@v5.3.1`、`pgx`、`sqlite`、`norma`、`go-mitmproxy`、`dnsx` 在这次查询里没有漏洞记录。

npm 直接依赖：

- `next@16.2.9`：20 条。OSV 标题包括 Image Optimization 和 `next/og` 的远程代码执行、Server Actions 拒绝服务、缓存投毒、以及 rewrite / Image Optimization 的服务端请求伪造。编号：`GHSA-2464-fhr4-w9xw`、`GHSA-2xp9-vwfh-vxw4`、`GHSA-39w2-rjm5-chcv`（`CVE-2026-94486`）、`GHSA-4633-3j49-mh5q`（`CVE-2026-64647`）、`GHSA-4c39-4ccg-62r3`（`CVE-2026-64646`）、`GHSA-4jqv-mc3x-m676`（`CVE-2026-94543`）、`GHSA-673q-mjm6-r5xr`、`GHSA-68g3-v927-f742`（`CVE-2026-64648`）、`GHSA-6gpp-xcg3-4w24`（`CVE-2026-64642`）、`GHSA-89xv-2m56-2m9x`（`CVE-2026-64649`）、`GHSA-955p-x3mx-jcvp`（`CVE-2026-64643`）、`GHSA-cjq9-62q9-8jv4`（`CVE-2026-94483`）、`GHSA-f87g-xv8r-7p7x`（`CVE-2026-94485`）、`GHSA-m99w-x7hq-7vfj`（`CVE-2026-64641`）、`GHSA-mcj8-r9mp-w47p`（`CVE-2026-94484`）、`GHSA-p293-qw3h-jr36`（`CVE-2026-75604`）、`GHSA-p3m5-59mp-jv5r`（`CVE-2026-94482`）、`GHSA-p9j2-gv94-2wf4`（`CVE-2026-64645`）、`GHSA-q8wf-6r8g-63ch`（`CVE-2026-64644`）、`GHSA-vcvr-r3jv-pc5j`。生产构建使用 `NEXT_EXPORT=1` 的静态导出（`web/package.json` 第 8 行）。这些公告有多少落在静态导出上，未确认。`npm run dev` 和 `next start` 会启动 Next 服务器。
- `postcss@8.5.16`：`GHSA-fxqj-rqcc-2cmp`（`CVE-2026-69153`）、`GHSA-r28c-9q8g-f849`（`CVE-2026-73646`）。传递依赖 `postcss@8.4.31` 另外还有 `GHSA-6g55-p6wh-862q`（`CVE-2026-45623`）和 `GHSA-qx2v-qp2m-jg93`。内容是处理不可信 CSS 时通过 `sourceMappingURL` 读取 `.map` 文件。
- `zod@4.4.3`，以及树里的 `zod@3.25.76`、`zod@3.23.8`：`GHSA-mrhx-c7xc-m3w5` / `CVE-2023-54404`，校验超大约束集合时的内存耗尽。

传递依赖里还有记录的包括 `undici@7.28.0`（22 条）、`hono@4.12.27`、`@hono/node-server@1.19.14`、`@modelcontextprotocol/sdk@1.29.0`、`fast-uri@3.1.3`、`ip-address@10.2.0`、`sharp@0.34.5`（`GHSA-f88m-g3jw-g9cj`、`GHSA-rgj7-g3m4-5g8c`、`GHSA-wq5f-xc86-pv6w`）、`qs@6.15.3`、`nanoid@3.3.15`、`js-yaml@4.3.0`、`systeminformation@5.31.11`、`body-parser@2.3.0`、`brace-expansion@5.0.7`、`browserslist@4.28.4`、`minimatch@10.2.5`、`basic-ftp@5.3.1`、`extract-zip@2.0.1`、`deepmerge@4.3.1`、`baseline-browser-mapping@2.10.40`、`postcss-selector-parser@7.1.4`、`proxy-addr@2.0.7`、`source-map-js@1.2.1`。这些是锁定版本上的已知漏洞，不是仿冒包。

### 1.7 更安全的拉取方式

1. Go：安装官方 Go 1.26.10 后用 `GOTOOLCHAIN=local`。`GOSUMDB` 保持 `sum.golang.org`，不要设 `off`。`GOPROXY` 用 `https://proxy.golang.org,direct`。构建前运行 `go mod verify`。`./build.sh` 已经默认把 `GOSUMDB` 设为 `sum.golang.org`；`./install.sh` 的 `go build` 依赖环境变量，需要自己保持这个默认值。
2. 前端：在 `web/` 使用 `npm ci`，registry 固定为 `https://registry.npmjs.org`。不要用 `npm install` 重新解析范围。`sharp` 的安装脚本属于已核对哈希的官方包；若使用 `--ignore-scripts`，需要另行确认 Next 是否还需要它。
3. `skills/api-recon/scripts`：把 lock 的 `resolved` 改到 `registry.npmjs.org` 后再 `npm ci`，或者继续使用当前 lock，但安装时不要加忽略 `integrity` 的选项。两个 `name` 字段建议先改成同一个，再安装。
4. 镜像：从 Docker Hub 官方库复制 digest，写成 `python:3.12-slim-bookworm@sha256:…` 和 `postgres:16-alpine@sha256:…`。不要使用 `ruoji6/artex:latest` 作为已审计产物；要和这次源码审计对齐，就从本仓库用锁定的 Go / npm 构建。digest 需要在拉取前从官方库读取，本文不写一个会过期的哈希。
5. 不要执行 `curl | sh`。Docker 用发行版或 Docker 官方签名的 apt 源安装。Node 用 nodejs.org 的官方包或发行版包，并核对发布哈希；若仍用 NodeSource，先保存 `setup_22.x` 再核对哈希，不要管道进 shell。
6. Dockerfile 和 skill 里的 `@playwright/mcp`、`@playwright/cli`、`playwright` 改成确切版本，并提交 lock。`playwright install` 使用该锁定版本，不再跟 `@latest`。
7. 这个 fork 在确认本地二进制就是已审计提交之前，不要使用页面一键更新。更新源写死为 `RuoJi6/ARTEX`。
8. CI 的 Action 改为完整提交 SHA。`vercel` CLI 放进 lock，或安装时带 `integrity`。

## 2. 仓库源码里的网络行为

这些是功能代码，不是 lock 之外的隐藏地址。

| 项 | 风险 | 位置 | 证据 |
| --- | --- | --- | --- |
| 启动后自动查上游版本 | 低 | `selfupdate/github.go` 第 16–19 行；`update-badge.tsx` 第 24–27 行 | 已登录主界面每次挂载请求 `/api/update/check`，后端访问 GitHub Release。不上传本地配置 |
| 出口 IP 探测的默认地址 | 低 | `server/egress_probe.go` 第 33–34 行 | 默认 `https://api.ipify.org?format=json` 和 `https://ifconfig.me/ip`。用户测试代理时才会请求，可改成自建地址 |
| DeepSeek 搜索 | 低 | `agent/deepseek_search.go` 第 17 行 | `https://api.deepseek.com/v1/tools/`。需要用户打开搜索并填写 Key |
| norma 内置搜索 | 低 | 见 1.2 | 搜索默认关闭。`server/manager.go` 第 334–335、642–643 行：默认后端是 `ddgs`，开关默认 false |
| Jev 审批模型 | 低 | `intercept/jev/client.go` 第 21 行 | 默认 `https://api.typesafe.ai`。用户配置 Key 后，拦截判定会把工具调用上下文发到该服务 |
| 通知 webhook | 低 | `notify/` 下钉钉、飞书、企业微信、邮件、通用 webhook | 地址来自用户配置。`notify/http.go` 有内网拨号限制 |
| MCP | 低 | `mcphttp/client.go` 第 95–107 行 | 只连接用户配置的 URL。`insecure=true` 时关闭 TLS 校验。默认 ScopeSentry 和 browser MCP 都是禁用且没有 URL（`db/schema.sql` 第 877–878 行，`db/db.go` 第 262–266 行） |
| 模型 API | 低 | `agent/provider.go` 第 147–169 行；`docker-compose.yml` 第 25–30 行 | `ANTHROPIC_API_KEY`、`OPENAI_API_KEY` 和自定义 Base URL 来自环境变量或界面。没有写死第三方密钥 |
| DNS 富化 | 信息 | `enrich/enrich.go` 第 67–71 行；dnsx v1.2.3 的 `DefaultResolvers` | 解析器是 1.1.1.1、8.8.8.8、9.9.9.9、208.67.222.222 及其备用。`enrich.New` 在 `server/manager.go` 第 670 行启动，但仓库里没有调用 `ResolveDomain` / `ProbeSite` 的代码。会不会在初始化时发包，未确认 |

`web/src/app/(main)/_components/sidebar/sidebar-support-card.tsx` 第 16 行有 `https://x.com/arhamkhnz`。`app-sidebar.tsx` 第 23 行 import 了该组件，第 39–62 行的 JSX 没有渲染它。这是模板残留链接，当前界面不会打开。

没有发现写死的个人 webhook、遥测域名或可疑 IP。源码和测试里的 IP 是文档示例、回环地址或测试夹具。

## 3. 混淆、动态执行和二进制

仓库内非图片文件没有 NUL 字节。二进制只有 PNG、ICO 和 SVG 截图/图标，没有 ELF、EXE、DLL、WASM、pyc 或压缩包。

长 base64 扫描只命中 `sidequestion/CONTEXT_BUDGET.md` 里的一段 GitHub URL，不是载荷。代码里的 base64 用于分页游标（`db/chat_mentions.go`）、邮件和钉钉/飞书签名（`notify/email.go`、`dingtalk.go`、`feishu.go`）以及前端 JWT payload 的展示解码（`web/src/lib/auth.ts` 第 39 行）。

`exec.Command` 出现在三处产品代码：`server/customtool.go` 第 398 行运行用户保存的 Python 工具；`selfupdate/bootstrap.go` 第 184 行对已暂存的新二进制执行 `-h` 冒烟；`intercept` 用 `LookPath` 找本机解释器做静态检查。`intercept` 里的 `eval` 是要拦截的 shell 关键字，不是 `eval` 一段隐藏字符串。

`skills/api-recon/scripts/runtime_harvest.js` 和 `preload.js` 是可读的前端侦察模板。前者第 35 行设置 `NODE_TLS_REJECT_UNAUTHORIZED=0`，运行时关闭 Node 的 TLS 校验。这是技能脚本的显式行为，只在操作者执行该脚本时生效。

## 4. 凭证和本机数据

没有发现读取浏览器配置目录、`~/.ssh` 或云元数据地址并外发的代码。`169.254.169.254` 出现在出口探测的拒绝列表里（`server/egress_probe_test.go` 第 432 行附近的用例，以及 `egress_probe.go` 对探测目标的限制）。

会接触密钥的路径：

- 风险：高（使用模型 shell 时）。`norma` 的 Bash 继承整个进程环境，见 1.2。`server/customtool.go` 第 400 行的自定义 Python 同样 `append(os.Environ(), …)`。数据库 URL 和模型 Key 若在环境里，模型执行的命令可以读到。
- 风险：中。`server/auth.go` 第 48–83 行在可执行文件旁边写 `jwt.key`，权限 `0600`。这是本机会话签名密钥，不是外发。
- 风险：低。任务过程中发现的目标凭据存在数据库里，由 `agent/credentials.go` 整理。提示词要求不登录、不外发。整理结果是否只留在本地数据库，取决于用户随后有没有把它们放进会外发的工具参数。
- `docker-compose.yml` 第 24 行把含数据库口令的 DSN 放进容器环境。这是部署方式，不是隐藏读取。

## 5. 持久化、提权和自更新

没有发现 crontab、systemd、LaunchAgent、注册表或计划任务安装代码。`start.sh` / `start.bat` 是前台守护循环，只在用户执行它时复用退出码 75 重启，不注册系统服务。

自更新是显式功能，见 1.5 第 6 条。`selfupdate.Bootstrap` 在 `cmd/artex/main.go` 第 75–78 行、监听端口之前运行：若上次已经暂存了新二进制，启动时会替换并再次退出。替换前有哈希和 `-h` 冒烟；连续启动失败会回滚。它不会在无人点击更新时自己去下载。

没有发现提权代码。Dockerfile 以 root 运行基础镜像里的命令，这是该 Dockerfile 的默认用户，未单独创建非特权用户。

## 6. Git 历史

714 个提交。作者集中在 `Autumn-27 <53844290+Autumn-27@users.noreply.github.com>`（338+43）和 `RuoJi6` / `ji ruo`（136+90+39）。这与模块路径、`norma` 作者和上游仓库一致。没有 git submodule。最大的一次是初始提交 `0ef8561`（287 个文件，约 7 万行插入）。

需要点名的身份：

- `FileShare Developer <developer@example.com>`，`c76d0f4`，2026-10-10。12 个文件，内容是流量目标和 LLM 会话删除。该 diff 里没有 URL、`curl` 或编码载荷。邮箱是占位域名，提交内容看起来是正常功能。为什么用这个邮箱，未确认。
- `artex-bot@local`、`artex@local`、`artex代码编写 <artex@local>` 共 7 个提交，2026-10-26 至 10-27。文件是任务计时、自动标题和 Repeater 界面。没有额外网络地址。身份是本地占位，未确认对应的 GitHub 账号。
- `r00t <24542600+adeljck@users.noreply.github.com>` 的 `f5c99f4` 是已合并的 Windows 路径修复（PR #18），两文件。
- `a642403` 只在 README 增加了 `https://github.com/oritera/Cairn` 链接。

没有发现某一笔提交突然塞入混淆脚本或陌生二进制。历史作者里的占位邮箱是身份未确认，不是已证实的投毒提交。

## 7. 作为渗透工具的风险边界

这是产品设计，不是供应链里的隐藏行为。默认启动不会自己挑一个公网目标去打；它会在本机打开服务，并在用户创建任务且配置了模型之后，按任务描述执行命令。

- 监听：`cmd/artex/main.go` 第 55–57 行默认 `-addr :8787`（所有网卡）和 `-proxy 127.0.0.1:8788`。8787 在首次设置管理员密码前，`/api/auth/init` 不需要令牌（`server/auth.go` 第 157–170 行）。谁能访问这个端口，谁就能设下第一组管理密码。Basic Auth 默认关闭（`server/basic_auth.go` 第 46–58 行，库里没有配置时 `Enabled` 为 false）。`/api/health` 在 Basic Auth 关闭时不需要登录，只返回 `{"ok":true}`（`server/server.go` 第 1153–1156 行）。
- 本地 MITM：只要 `-proxy` 非空，`server/manager.go` 第 604–635 行就会启动记录代理并生成 `data/traffic/_ca`。流量捕获开关默认关闭（第 639 行），它控制的是模型是否被注入代理，代理端口本身仍在监听。没有发现把 CA 装进系统信任库的代码。
- 任务：`server/server.go` 第 1816–1820 行，创建任务时若没有「稍后启动」的日程，会立刻进入引擎。不强制填写授权范围。模型提示词要求只打授权目标（`agent/promptcatalog.go` 第 47 行），这是提示，不是执行前的强制校验。`guard/guard.go` 第 4–7 行写明原来的授权范围机制已移除。
- 重启：`server/server.go` 第 349–357 行会重新跑未结束、且不在队列里的任务。进程重启后，上次没暂停的任务会继续。
- 并发：默认 3 个 worker（`server/manager.go` 第 339、468–479 行）。渗透 agent 默认打开交互式 shell（`db/db.go` 第 214–215、248–255 行）。
- 拦截：默认进入拦截的工具是 Bash、WebFetch、web_search、shell_open、shell_send、Write、Edit、MultiEdit（`intercept/intercept.go` 第 143–147 行）。内置规则默认拒绝 `rm -rf`、格式化、`dd` 写磁盘、fork 炸弹、关机、DROP/TRUNCATE、部分 DELETE 路径（`db/db.go` 第 364–535、603–615 行）。数据外传管道规则默认关闭（第 542–544、565–571 行）。规则是正则，用户可以停用。未命中规则时，LLM 兜底判定默认关闭（`intercept/intercept.go` 第 350 行），调用直接放行。
- 资产拦截默认只拦 `.gov`、`.gov.cn`、`.edu`、`.edu.cn`（`db/db.go` 第 303–306 行）。其他目标没有默认黑名单。
- 破坏性：模型拥有 Bash、写文件、自定义命令/Python/HTTP 工具。内置规则挡住一部分删除和磁盘破坏命令，挡不住读取环境变量、向任务目标发请求、写入工作目录，也挡不住用户关掉规则之后的操作。OPSEC 提示默认关闭（`server/server.go` 第 215 行，缺省 false）。
- Docker Compose 把 8787 映射到宿主所有网卡，8788 只映射到 `127.0.0.1`（`docker-compose.yml` 第 31–33 行）。

## 未确认

- `https://get.docker.com` 和 `https://deb.nodesource.com/setup_22.x` 的脚本正文。
- `python:3.12-slim-bookworm`、`postgres:16-alpine`、`ruoji6/artex:latest` 的镜像层，以及不在仓库里的 `Dockerfile.bench`。
- `@playwright/mcp@latest`、`@playwright/cli@latest`、`playwright@latest` 和 `playwright install` 在构建当时解析到的字节。
- `RuoJi6/ARTEX` Release zip 里的二进制。
- GitHub Actions 可变标签和 `vercel@64.2.0` 的当前内容。
- `sharp@0.34.5` 安装脚本执行时是否再下载文件。包哈希已与官方 registry 一致。
- `dnsx.New` 初始化时是否发包。
- Next.js 20 条公告里有多少适用于 `NEXT_EXPORT=1` 静态导出。
- Go 漏洞记录里除 `openpgp` 以外的可达性。本仓库没有 import `golang.org/x/crypto/openpgp`。
- 占位邮箱 `developer@example.com` 和 `artex-bot@local` 的真实操作者。

## 审计没有做的事

没有运行测试、没有把模块装进本仓库的构建缓存、没有起数据库、没有打开 Web 界面、没有核对 Docker Hub 上某个 digest 的镜像配置。OSV 结果只代表 2026-11-09 的公开记录。商业恶意包库（例如 Socket.dev）没有查询。
