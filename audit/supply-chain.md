# 供应链（RuoJi6/ARTEX @ 253a8eeac3b278cd4ff383674a31a0edcc34e143）

结论：锁文件里的包版本在本次 OSV 查询中没有恶意包通告。镜像与安装脚本仍使用无 digest 的标签，以及无校验和的远程脚本。未拉取镜像层，不能写成层内容安全。未审计依赖源码，不能写成依赖已确认无恶意。

查询时间：2026-11-26 09:37 香港时间（UTC+8；记录到的 UTC 为 2026-11-26T01:37:25Z）。接口：`https://api.osv.dev/v1/querybatch`，通告摘要用 `https://api.osv.dev/v1/vulns/{id}`。未运行仓库里的安装脚本，未 `npm install`，未 `go mod download`。

## 依赖是否恶意

结论：958 个已查询包版本中，恶意包编号（`MAL-`）为 0。这只说明公开 OSV 通告库没有把这些版本标成恶意包。

- 查询范围：`go.sum` 中 81 个模块版本（不含 `/go.mod` 校验行）；`web/package-lock.json`；`skills/api-recon/scripts/package-lock.json`。合计 958。命中漏洞通告的包版本 35 个，通告 ID 142 个，均无 `MAL-` 前缀。
- 直接依赖抽查未见明显仿冒名（`jwt`、`pgx`、`next`、`react`、`dnsx` 等与上游项目同名）。未做全量编辑距离比对，仿冒检测记为未完成。
- `github.com/Autumn-27/norma` v0.4.3：OSV 未命中。`proxy.golang.org` 的 `v0.4.3.info` 与 GitHub 附注 tag 都指向提交 `320ae32989da97dd91469bb89164cbfe87d83d5d`。tag 时间 2026-09-30 09:12 香港时间（API 原始值 2026-09-30T01:12:56Z）。公开仓 `Autumn-27/Norma` 查询时未归档，默认分支 `main` 的 `pushed_at` 为 2026-11-24 18:19 香港时间（API `2026-11-24T10:19:17Z`），晚于本单基准，但 go.mod 钉的是 v0.4.3 不是浮动分支。智能体工具执行在该模块中。本单未读其源码，不把它写成无恶意。
- 未逐包阅读 npm `postinstall`。本仓自己的安装钩子是 `web/package.json` 第 15 行 `"prepare": "husky"`，作用是本地 git hook，不是远程脚本。
- 其余漏洞通告见下一节。有通告不等于本程序里已经能触发。

## 语言包与锁文件

结论：Go 与前端都有锁。`go.mod` 直接版本里，与本树引用路径最接近的通告是 `x/net` 的 html 问题。`next@16.2.9` 的高危通告是否落在静态导出上，未确认。

- `go.mod` 无 `replace`，无 GOPROXY / GOSUMDB 覆盖。`go.sum` 含 `h1:` 行。本单未向 `sum.golang.org` 复核。
- 相对旧基准 `a05a886d`，直接要求变为：`x/crypto` v0.55.0→v0.58.0，`x/net` v0.58.0→v0.61.0，`x/text` v0.41.0→v0.43.0，`go-mitmproxy` v1.9.2→v1.9.5。`go.sum` 仍保留旧版本校验行。未运行 `go list -m all`，不能把旧行写成当前构建选中的版本。
- 当前 `go.mod` 版本的 OSV 命中（2026-11-26 09:37 香港时间）：
  - `golang.org/x/net` v0.61.0：GO-2026-6860、GO-2026-6866。摘要为 html 解析复杂度与原始文本命名空间。本树 `internal/webfetch/webfetch.go` 第 23 行引用 `golang.org/x/net/html`。见 F-07。可利用性未验证。
  - `golang.org/x/crypto` v0.58.0：GO-2026-5932。摘要为 `openpgp` 子包无人维护。本树未检索到 `openpgp` 引用。不把整模块写成已确认可利用。
  - `github.com/klauspost/compress` v1.18.6：GHSA-259r-337f-4rfw、GO-2026-5841、GO-2026-6865。摘要指向 `compress/s2` 与帧处理。本树引用的是 `klauspost/compress/zstd`（备份与技能包）。未确认 zstd 路径受影响。
- `go.sum` 里另有命中、但是间接或旧版本行：`brotli` v1.2.1（GO-2026-6888）、`gorilla/websocket` v1.5.3（GO-2026-6278）、`x/crypto` v0.55.0、`x/net` v0.58.0。不单独升为产品漏洞。
- `jwt/v5` v5.3.1、`pgx` v5.10.0、`dnsx` v1.2.3、`sqlite` v1.52.0、`norma` v0.4.3：本次查询未命中。
- npm：`web/package.json` 使用 `^` 范围；`web/package-lock.json` 为 lockfileVersion 3，含 integrity。本单未重算 integrity。
- 直接包 `next@16.2.9`：25 条 GHSA。摘要中含图像优化、Server Actions、`next/og` 的未认证远程代码执行表述。`web/next.config.mjs` 在 `NEXT_EXPORT=1` 时 `output: "export"`，镜像文档是静态文件交给 Go。`package.json` 仍有 `next start`。可达性未确认，见 F-08。不把通告原文扩写成利用步骤。
- 直接包 `zod@4.4.3`：GHSA-mrhx-c7xc-m3w5，摘要为超大集合校验的内存消耗。未确认调用方是否把不可信超大输入送入该路径。
- 传递 npm 命中（未逐一做可达性）：`@hono/node-server`、`hono`、`undici`、`postcss`、`@modelcontextprotocol/sdk`、`fast-uri`、`body-parser`、`qs`、`sharp`、`systeminformation`、`basic-ftp`、`nanoid`、`minimatch`、`brace-expansion`、`js-yaml`、`ip-address`、`browserslist`、`proxy-addr`、`extract-zip`、`source-map-js`、`postcss-selector-parser`、`baseline-browser-mapping`。技能锁 `puppeteer-core` 的传递树包含在上述 958 次查询内；该包自身未出现在命中列表。
- 未查询：锁文件之外的可选下载、镜像内 `npm install -g @latest` 当时解析到的版本、Playwright 浏览器二进制。

## 容器镜像

结论：标签都未钉 digest。应用镜像默认 `latest`。层内容未拉取，安全状态未核实。

| 镜像 | 位置 | tag | digest | 说明 |
|---|---|---|---|---|
| `postgres:16-alpine` | `docker-compose.yml` 第 3 行 | 浮动次版本标签 | 无 | 未拉取 |
| `${ARTEX_IMAGE:-ruoji6/artex}:${ARTEX_TAG:-latest}` | `docker-compose.yml` 第 18 行；`.env.example` 第 3–4 行 | 默认 `latest` | 无 | 未拉取。README 称由本仓 Actions 推到 Docker Hub |
| `python:3.12-slim-bookworm` | `Dockerfile` 第 13 行 | 浮动标签 | 无 | 未拉取。构建时再装 nmap、Node、Playwright |
| `artex-bench:latest` | `docker-compose.bench.yml` 第 16 行 | `latest` | 无 | `Dockerfile.bench` 不在本树，镜像无法按本树重建 |

`Dockerfile` 第 21 行：`curl -fsSL https://deb.nodesource.com/setup_22.x | bash -`，无校验和。第 29 行：`npm install -g @playwright/mcp@latest @playwright/cli@latest playwright@latest`，无锁。镜像无 `USER`。未见 `docker.sock` 挂载。

## 子模块、脚本与 CI

结论：无 git 子模块。两处管道执行远程安装脚本。CI 动作多数为 GitHub 官方，有一个第三方动作只钉 tag。

- 子模块：`git submodule status` 为空。
- `install.sh` 第 22 行：`curl -fsSL https://get.docker.com | sh`。无校验和。只在操作者选择自动安装 Docker 时走到。本单未执行。
- `update.sh` 使用本机 `docker compose pull` 与 `git pull`，没有管道脚本。
- `skills/playwright-cli/SKILL.md` 文档中有 `npm install -g @playwright/cli@latest`。这是技能说明，不是仓库安装钩子。
- 自更新下载限定 GitHub 主机并核对 SHA256SUMS（`selfupdate/github.go`、`selfupdate/stage.go`）。发布资产本身的供应链取决于 GitHub Release，本单未下载发布包。
- Actions：`actions/checkout@v4`、`actions/setup-go@v5`、`actions/setup-node@v4`、`docker/*@v3` 或 `@v6`，以及 `softprops/action-gh-release@v2`。均为 tag，不是 commit SHA。未把第三方动作标成恶意，也未审计其源码。

## 未核实

- 全部镜像层与构建时 `@latest` 的实际解析结果。
- `norma` 及其他模块的源码是否含未公开的恶意逻辑。
- npm 包安装脚本全文。
- `sum.golang.org` 与 lockfile integrity 的重新计算。
- 传递依赖里每条 GHSA 的可达性。
