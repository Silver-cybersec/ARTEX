# 供应链补查 v4（只读）

基准 SHA：`253a8eeac3b278cd4ff383674a31a0edcc34e143`（上游 https://github.com/RuoJi6/ARTEX ）。已有长文见 `audit/supply-chain.md`，这里只补八项缺口。未安装依赖，未拉镜像层，未跑脚本或 CI。层内容与未读源码不是安全。

「已确认」只表示该项里的缺口或通告命中在文件或查询结果里成立，不是确认依赖已被植入恶意代码。

| 项 | 结论 |
|---|---|
| 1 清单与 lockfile（含间接） | 未发现问题 |
| 2 版本钉、校验和、git／URL 直装 | 已确认 |
| 3 仿冒名、安装钩子、非官方源 | 可疑 |
| 4 容器镜像来源、tag、digest | 已确认 |
| 5 子模块、下载脚本、运行时远程拉取 | 已确认 |
| 6 CI：SHA 钉扎、密钥、危险触发 | 已确认 |
| 7 公开漏洞库与恶意包库 | 已确认 |
| 8 主要依赖维护状态 | 未发现问题 |

## 1. 清单与 lockfile

结论：未发现问题。

- Go：`go.mod` 直接依赖，`go.sum` 含间接模块与 `h1:`（`go.sum` 第 1 行起）。无 `replace`（`go.mod` 全文无该指令）。
- 前端：`web/package.json` 加 `web/package-lock.json`（lockfileVersion 3，798 个 `node_modules` 条目，均有 integrity）。
- 技能：`skills/api-recon/scripts/package.json` 第 2–8 行只依赖 `puppeteer-core`；同目录 `package-lock.json` 有 85 个传递包。
- Python：`skills/api-recon/scripts/*.py` 只用标准库，无 `requirements.txt` / `pyproject.toml`。无第三方包，故无 lockfile。
- 无 `Cargo.toml`。仓库根无 `.gitmodules`。

## 2. 版本钉、校验和、git／URL 直装

结论：已确认（锁文件之外存在未钉版本；锁内校验和在，未见 git／URL 直装）。

- `web/package.json` 用 `^` 范围；锁文件把版本和 integrity 钉死。`go.sum` 有 `h1:`。本单未向 `sum.golang.org` 重算，校验和是否与官方库一致对 Go 为未核实。
- 两份 npm 锁的 `resolved` 都没有 `git+` 或 GitHub tarball。`go.mod` 无伪版本直装；`go.sum` 里 8 个伪版本是传递模块的普通版本号，不是 URL 替换。
- 未钉版本已在树中：`Dockerfile` 第 29 行 `@playwright/mcp@latest`、`@playwright/cli@latest`、`playwright@latest`；`docker-compose.yml` 第 18 行默认 tag `latest`；`.env.example` 第 4 行 `ARTEX_TAG=latest`。这些解析结果未核实。

## 3. 仿冒名、安装钩子、非官方源

结论：可疑。

- 直接依赖名与已知上游同名。未做全量编辑距离。技能清单名是 `api-recon-runtime`（`package.json` 第 2 行），锁根名是 `spa-api-recon-runtime`（`package-lock.json` 第 2 行）。名称不一致，不像对知名包的仿冒。
- 非官方源：技能锁 85 条 `resolved` 都在 `registry.npmmirror.com`（首条 `package-lock.json` 第 16 行）。2026-11-26 11:31 香港时间（UTC+8；记录 UTC `2026-11-26T03:31:04Z`）用 `https://registry.npmjs.org/<name>/<version>` 对照这 85 个 integrity，85 个一致、0 个不一致。当前记录的哈希与官方源相同；锁仍指向镜像站，后续重装若改哈希则另说。
- 安装钩子：`web/package.json` 第 15 行 `"prepare": "husky"`，只在本仓装 git hook。`web/package-lock.json` 第 10179 行 `sharp@0.34.5` 带 `hasInstallScript: true`。钩子正文在包内，本仓没有，未核实。前端锁其余条目未见 `preinstall` / `install` / `postinstall`。技能锁无安装钩子。

## 4. 容器镜像

结论：已确认（tag 未固定到 digest）。层内容未拉取，未核实。

| 镜像 | 位置 | tag | digest |
|---|---|---|---|
| `postgres:16-alpine` | `docker-compose.yml` 第 3 行；`.github/workflows/release.yml` 第 207 行 | 浮动次版本 | 无 |
| `ruoji6/artex`（默认可被环境变量改掉） | `docker-compose.yml` 第 18 行；`.env.example` 第 3–4 行 | 默认 `latest` | 无 |
| `python:3.12-slim-bookworm` | `Dockerfile` 第 13 行 | 浮动 | 无 |
| `artex-bench:latest` | `docker-compose.bench.yml` 第 16 行 | `latest` | 无；`Dockerfile.bench` 不在本树 |

来源分别是 Docker Hub 官方库、`ruoji6/artex`、Docker Hub `python`。未向仓库核对镜像清单。

## 5. 子模块、下载脚本、运行时拉取

结论：已确认（存在无校验和的管道安装）。

- 子模块：无 `.gitmodules`。
- `Dockerfile` 第 21 行：`curl -fsSL https://deb.nodesource.com/setup_22.x | bash -`，无校验和。第 31 行 `playwright install --with-deps chromium`，构建时拉浏览器，版本随第 29 行的 `@latest`。
- `install.sh` 第 22 行：`curl -fsSL https://get.docker.com | sh`。仅在选择自动安装 Docker 时走到。本单未执行。
- 运行时：页面自更新从写死的 `RuoJi6/ARTEX` 拉 Release，并核对 SHA256（`selfupdate/github.go` 第 18–32 行）。未下载发布包。未在本树看到模型权重、Ollama 或 Hugging Face 拉取。用户配置的 LLM／MCP 地址由部署者填写。`norma` 内部是否再拉远程工具：未核实。
- `skills/playwright-cli/SKILL.md` 第 354 行写 `npm install -g @playwright/cli@latest`，是技能说明，不是仓库钩子。

## 6. CI

结论：已确认（动作未钉提交 SHA；工作流含冒烟口令字面量）。

- 触发：`release.yml` 第 2–10 行是 `workflow_dispatch` 与 `push` tags `v*`。`demo.yml` 第 3–23 行是 `release: published`、`workflow_call`、`workflow_dispatch`。未见 `pull_request_target` 或 `workflow_run`。
- 动作全部是 tag，不是提交 SHA：`actions/checkout@v4`、`actions/setup-node@v4`、`actions/setup-go@v5`、`actions/upload-artifact@v4`、`actions/download-artifact@v4`、`actions/github-script@v7`、`docker/setup-buildx-action@v3`、`docker/login-action@v3`、`docker/build-push-action@v6`、`softprops/action-gh-release@v2`（`release.yml` 第 166 行）。本地复用是 `release.yml` 第 188 行 `uses: ./.github/workflows/demo.yml`。第三方动作源码未读。
- 密钥：`DOCKERHUB_USERNAME`、`DOCKERHUB_TOKEN`、`VERCEL_TOKEN` 来自 Actions secrets（`release.yml` 第 228–229、193 行），YAML 不写它们的值。冒烟得到的登录令牌有 `::add-mask::`（第 254 行）。第 251 行把一次性冒烟口令直接写在工作流里。不抄录该口令。它不是 Docker Hub 或 Vercel 的生产密钥，但是仓库明文。
- 发布 job 把 `contents` 升到 `write`（`release.yml` 第 126–127 行），用于创建 Release。默认权限是 `contents: read`（第 12–13 行）。

## 7. 公开漏洞库与恶意包库

查询沿用 2026-11-26 09:37 香港时间（UTC+8；UTC `2026-11-26T01:37:25Z`）的 `https://api.osv.dev/v1/querybatch`：958 个锁版本，35 行命中，无 `MAL-`。去重后 34 个包版本（`ip-address@10.2.0` 在两份锁里重复）。编号出现次数 157，不重复通告 142。影响版本指这次查询的锁版本，不是通告的完整影响区间。可达性未在本文件重做。

### 依赖是否恶意

结论：未发现问题（本次 OSV 结果没有恶意包编号）。

这不等于源码已审、也不等于镜像层已查。`norma` v0.4.3 在该次查询中未命中，源码仍未读。

### 已知漏洞

结论：已确认（下列锁版本被 OSV 返回通告）。

直接依赖：

| 依赖 | 锁版本 | 位置 | 编号 |
|---|---|---|---|
| `golang.org/x/net` | v0.61.0 | `go.mod` 第 15 行 | GO-2026-6860，GO-2026-6866 |
| `golang.org/x/crypto` | v0.58.0 | `go.mod` 第 14 行 | GO-2026-5932 |
| `github.com/klauspost/compress` | v1.18.6 | `go.mod` 第 10 行 | GHSA-259r-337f-4rfw，GO-2026-5841，GO-2026-6865 |
| `next` | 16.2.9 | `web/package.json` 第 50 行 | GHSA-2464-fhr4-w9xw，GHSA-2xp9-vwfh-vxw4，GHSA-39w2-rjm5-chcv，GHSA-4633-3j49-mh5q，GHSA-4c39-4ccg-62r3，GHSA-4jqv-mc3x-m676，GHSA-673q-mjm6-r5xr，GHSA-68g3-v927-f742，GHSA-6gpp-xcg3-4w24，GHSA-7qx7-33qx-rqx2，GHSA-89xv-2m56-2m9x，GHSA-955p-x3mx-jcvp，GHSA-cjq9-62q9-8jv4，GHSA-f3mh-rxg3-f5g2，GHSA-f87g-xv8r-7p7x，GHSA-m99w-x7hq-7vfj，GHSA-mcj8-r9mp-w47p，GHSA-p293-qw3h-jr36，GHSA-p3m5-59mp-jv5r，GHSA-p9j2-gv94-2wf4，GHSA-pc58-hwjq-p385，GHSA-q8wf-6r8g-63ch，GHSA-rhh4-g77r-r9qj，GHSA-vc7v-qv4w-wrv8，GHSA-vcvr-r3jv-pc5j |
| `zod` | 4.4.3 | `web/package.json` 第 70 行 | GHSA-mrhx-c7xc-m3w5 |

`go.mod` 中本次未命中的直接模块：`norma` v0.4.3、`jwt/v5` v5.3.1、`uuid` v1.6.0、`pgx/v5` v5.10.0、`go-mitmproxy` v1.9.5、`dns` v1.1.72、`dnsx` v1.2.3、`x/text` v0.43.0、`sqlite` v1.52.0、`mvdan.cc/sh/v3` v3.10.0。

`go.sum` 里更旧或间接、且命中的版本：`x/crypto` v0.55.0（GO-2026-5932，GO-2026-6354，GO-2026-6355）；`x/net` v0.58.0（GO-2026-6603，GO-2026-6610，GO-2026-6611，GO-2026-6612，GO-2026-6617，GO-2026-6860，GO-2026-6866）；`brotli` v1.2.1（GO-2026-6888）；`gorilla/websocket` v1.5.3（GO-2026-6278）。未运行 `go list -m all`，旧行是否进入构建未核实。

传递 npm（锁版本＝命中版本）：

| 包@版本 | 编号 |
|---|---|
| `@hono/node-server@1.19.14` | GHSA-frvp-7c67-39w9，GHSA-jpvv-r467-5p4w，GHSA-rmxm-3fg6-px4f |
| `hono@4.12.27` | GHSA-3gg2-335m-rxc6，GHSA-46wx-v44x-9hh2，GHSA-4h7h-rv7c-7m2v，GHSA-4m76-xfj5-7975，GHSA-54fx-42gc-7vw4，GHSA-5r4p-p66f-jhc7，GHSA-79qm-7rj5-m7r9，GHSA-8j4g-w8fx-2239，GHSA-crvj-82cr-hjcx，GHSA-f23p-vx2j-j53r，GHSA-g6gw-c38x-mqfc，GHSA-gqvv-2mrq-wpjv，GHSA-h7mg-cq63-vhpq，GHSA-hxh3-vqpv-xpqv |
| `undici@7.28.0` | GHSA-2gqq-gqf2-x968，GHSA-2jfj-6hjv-fm6j，GHSA-2m5v-pch6-74hx，GHSA-3wwx-pv8p-q78v，GHSA-3xpg-4rpp-hhhm，GHSA-4cwx-7wf7-3272，GHSA-4qv8-2p9j-2685，GHSA-4w7w-5xrc-9h26，GHSA-55wc-3pg8-jfw6，GHSA-8436-99hf-9mmv，GHSA-8xcm-r25x-g524，GHSA-9fm3-97px-rjf6，GHSA-f72v-6w45-q472，GHSA-jr45-8vmc-qm54，GHSA-m8rv-5g2x-5cg5，GHSA-pmjh-fq2x-6v4x，GHSA-qrxm-fqhp-jwvm，GHSA-r53p-7pc4-xj5r，GHSA-rfgv-xxqx-mfg5，GHSA-rx4f-c7p8-82vq，GHSA-v3r7-h72x-cjcm，GHSA-w293-vg96-wgc3，GHSA-xjj6-f33q-929c |
| `@modelcontextprotocol/sdk@1.29.0` | GHSA-22jm-h49p-29qw，GHSA-46jr-4wx8-v453，GHSA-6prh-2h8m-c8cw，GHSA-6qxp-vccf-f47h，GHSA-f897-62hf-6gxq，GHSA-rvq5-wwqv-78pq |
| `fast-uri@3.1.3` | GHSA-333x-w4r6-6crp，GHSA-5jgf-p345-68v8，GHSA-7p8r-x3mc-p8w7，GHSA-f65p-4m7j-42xc，GHSA-fph4-wmhf-6fwf，GHSA-hrr3-gc8f-f4qj，GHSA-jqff-g426-hqxp，GHSA-qw65-cvwx-89v3，GHSA-v2hh-gcrm-f6hx，GHSA-w74x-v6f9-j3xg，GHSA-wjr9-j795-jxcr，GHSA-xhq7-xmqj-769h |
| `postcss@8.4.31` | GHSA-6g55-p6wh-862q，GHSA-fxqj-rqcc-2cmp，GHSA-qx2v-qp2m-jg93，GHSA-r28c-9q8g-f849 |
| `postcss@8.5.16` | GHSA-fxqj-rqcc-2cmp，GHSA-r28c-9q8g-f849 |
| `sharp@0.34.5` | GHSA-f88m-g3jw-g9cj，GHSA-rgj7-g3m4-5g8c，GHSA-wq5f-xc86-pv6w |
| `ip-address@10.2.0` | GHSA-22jq-vg5j-6vgg，GHSA-2vr4-cq9g-pvrc，GHSA-4xrf-jv44-h6hh，GHSA-h3mg-xc3c-68pw，GHSA-j6r3-76f7-8jcv，GHSA-mwp4-54f8-5fhr，GHSA-rpw4-54j3-4h4q，GHSA-rxp7-6hxx-x8q5 |
| `brace-expansion@5.0.7` | GHSA-6j4f-fj2g-mc7p，GHSA-mh99-v99m-4gvg，GHSA-q2hr-2g5m-vwhr，GHSA-qhr7-859c-m2p7，GHSA-rgw5-rvv9-x895 |
| `systeminformation@5.31.11` | GHSA-3f7j-7jwc-fxfj，GHSA-4vjg-vx72-qq4g，GHSA-7648-jmwf-vw7j |
| `basic-ftp@5.3.1` | GHSA-5pm8-86m8-9m6r，GHSA-c475-qrg2-pj4r，GHSA-r4jh-29pc-gfqr |
| `qs@6.15.3` | GHSA-4mjr-xmp4-gh2g，GHSA-6pq8-jhm2-2vcw，GHSA-x5fp-wj9c-mxmx |
| `browserslist@4.28.4` | GHSA-73wf-gq98-2v4g，GHSA-c83g-rgw3-j3cx |
| `js-yaml@4.3.0` | GHSA-2883-xcg3-v3hh，GHSA-5p4m-2wfm-xmqj |
| `nanoid@3.3.15` | GHSA-28wg-ghj8-5hjv，GHSA-2v37-7h3g-55p8 |
| `extract-zip@2.0.1` | GHSA-7pqw-9j4j-h8q3，GHSA-jmr9-qjv8-65gv |
| `zod@3.25.76`、`zod@3.23.8` | 均为 GHSA-mrhx-c7xc-m3w5 |
| `body-parser@2.3.0` | GHSA-27r3-jxmh-p828 |
| `minimatch@10.2.5` | GHSA-g3hv-75wg-m249 |
| `postcss-selector-parser@7.1.4` | GHSA-rj75-hqrm-r3gf |
| `proxy-addr@2.0.7` | GHSA-jqcg-44mw-7w3h |
| `source-map-js@1.2.1` | GHSA-68fv-2mgg-jv7q |
| `baseline-browser-mapping@2.10.40` | GHSA-w5vr-8v7q-w6rv |

镜像内 `@latest` 当时装到的包不在上述查询里，未核实。

## 8. 主要依赖维护状态

结论：未发现问题（所查仓库均未归档，所查 npm 版本均无 deprecated）。

查询时间 2026-11-26 11:30 香港时间（UTC+8；UTC `2026-11-26T03:30:16Z`）。Go 用 `https://proxy.golang.org/<module>/@latest`。npm 用 `https://registry.npmjs.org/<name>/latest` 与同路径下的锁版本。GitHub 用 `https://api.github.com/repos/<owner>/<repo>`。

| 依赖 | 锁版本 | 索引上的最新版与时间（UTC） | 仓库 | 归档 |
|---|---|---|---|---|
| `norma` | v0.4.3 | v0.4.4，2026-10-13T12:46:07Z | Autumn-27/Norma，pushed 2026-11-24T10:19:17Z | 否 |
| `jwt/v5` | v5.3.1 | 同为 v5.3.1，2026-01-28T19:58:13Z | golang-jwt/jwt，pushed 2026-11-09T15:36:18Z | 否 |
| `pgx/v5` | v5.10.0 | v5.13.0，2026-11-11T18:26:18Z | jackc/pgx，pushed 2026-11-22T13:57:27Z | 否 |
| `compress` | v1.18.6 | v1.20.5，2026-11-19T20:46:28Z | klauspost/compress，pushed 2026-11-25T16:51:47Z | 否 |
| `go-mitmproxy` | v1.9.5 | 同为 v1.9.5，2026-11-12T09:05:57Z | lqqyt2423/go-mitmproxy，pushed 2026-11-12T09:06:16Z | 否 |
| `dns` | v1.1.72 | v1.1.73，2026-08-19T05:07:32Z | miekg/dns，pushed 2026-11-03T10:02:13Z | 否 |
| `dnsx` | v1.2.3 | v1.3.1，2026-08-31T05:20:03Z | projectdiscovery/dnsx，pushed 2026-11-23T02:43:52Z | 否 |
| `x/crypto` | v0.58.0 | v0.59.0，2026-11-11T07:23:42Z | 模块代理，无单独 GitHub 归档字段 | 未按 GitHub 仓核实 |
| `x/net` | v0.61.0 | v0.63.0，2026-11-17T18:09:36Z | 同上 | 未按 GitHub 仓核实 |
| `x/text` | v0.43.0 | v0.44.0，2026-11-09T16:29:39Z | 同上 | 未按 GitHub 仓核实 |
| `sqlite` | v1.52.0 | v1.63.0，2026-11-22T13:14:16Z | modernc-org/sqlite，pushed 2026-11-23T15:45:58Z | 否 |
| `sh/v3` | v3.10.0 | v3.14.1，2026-09-06T14:51:11Z | mvdan/sh，pushed 2026-11-25T14:51:32Z | 否 |
| `uuid` | v1.6.0 | 同为 v1.6.0，2024-01-23T18:54:04Z | google/uuid，pushed 2024-11-14T17:05:06Z | 否。最新版就是锁版本，发版旧 |
| `next` | 16.2.9 | 16.4.6，无 deprecated | vercel/next.js，pushed 2026-11-26T03:27:41Z | 否 |
| `react` | 19.2.7 | 19.3.1，无 deprecated | facebook/react，pushed 2026-11-25T21:50:28Z | 否 |
| `zod` | 4.4.3 | 4.6.7，无 deprecated | colinhacks/zod，pushed 2026-11-22T20:47:43Z | 否 |
| `gorilla/websocket`（间接） | v1.5.3 | 同为 v1.5.3，2024-06-14T03:18:03Z | gorilla/websocket，pushed 2025-03-19T13:29:08Z | 否。最新版即锁版本，提交偏旧 |

`x/crypto`、`x/net`、`x/text` 只核了模块代理上的最新版，没有把 `golang/go` 子目录仓的归档状态单独打开，这三项仓库归档为未核实。其余上表仓库的 `archived` 均为 false。
