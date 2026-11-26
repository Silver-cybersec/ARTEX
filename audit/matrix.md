# 验收矩阵（RuoJi6/ARTEX @ 253a8eeac3b278cd4ff383674a31a0edcc34e143）

阅读时间：2026-11-26 09:37 香港时间（UTC+8）完成 R1–R7。2026-11-26 10:14 香港时间起追加 R8、R9，对照完成于同日 10:15 香港时间之后。未做动态验证。用户已定的 R1–R7 保留；其后为执行中补行。

| ID | 需求 | 检查项 | 证据 | 结论 | 未覆盖 |
|---|---|---|---|---|---|
| R1 | 对用户指定的本仓、本单固定基准 SHA 做只读静态重审 | 上游 URL、默认分支、基准 SHA、提交时间（香港时间）；只读源码、清单与锁文件 | 上游 `main` 的 `git fetch` 得到 `253a8eeac3b278cd4ff383674a31a0edcc34e143`。作者 ji ruo / RuoJi6。时间 2026-11-23 18:44 香港时间（API `2026-11-23T10:44:27Z`）。树 811 文件，无子模块 | 已检出该 SHA 并只读审完本单范围。fork 默认分支 `a05a886d` 不是阅读对象 | 已删除的 Autumn-27/ARTEX、Origin 私库未读 |
| R2 | 代码安全 | 故意漏洞与部署者／宿主风险分开；危险执行、默认凭据、硬编码密钥、外传、隔离、暴露面、容器挂载；高／中／低 | `audit/findings.json`；`server/auth.go`、`cmd/artex/main.go`、`guard/guard.go`、`Dockerfile`、`docker-compose.yml` | 高 2、中 5、低 2（已确认项）。另有 1 条 Next.js 通告可达性未确认。无靶场关卡源码 | 未动态验证；`norma` 内 Bash 实现未读 |
| R3 | 架构（含相称的功能阅读） | 组件、信任边界、数据与权限流；关键流程能否被绕过的已读证据 | `server/server.go` Handler、`auth.go`、`guard.go`、`selfupdate/github.go`、README 第 5–17 行 | 单管理员控制面 + 同进程工具执行面。设密前 init 可被抢；设密后 API 要 JWT。拦截默认放行 | 未做宣称对照全表。`norma` 运行时未读。bench 镜像文件缺失 |
| R4 | 供应链，且单列「依赖是否恶意」 | 锁文件、镜像 tag/digest、子模块、curl/wget 管道、校验和、仿冒名、安装钩子、非官方源、OSV/GHSA | `audit/supply-chain.md`。OSV 958 个包版本，`MAL-` 为 0。查询 2026-11-26 09:37 香港时间 | 未发现恶意包通告。不能写成已确认无恶意。构建与安装脚本信任无校验远程脚本；镜像无 digest | 未拉取镜像层。未逐包读 install 脚本。未向 sum.golang.org 复核 |
| R5 | 精练中文报告，供日后压缩总报告 | 四份交付；每节先结论 | `audit/RERUN-20261126.md`、`matrix.md`、`findings.json`、`supply-chain.md` | 已按路径提交到 PR，未改产品代码，未改总报告 | 无本环境写不出的附件 |
| R6 | 对照旧审计基准 | `a05a886d…253a8eea`；旧高／中危标仍成立／已变化／无法再核实 | 本单 `merge-base` 等于旧 SHA；ahead 53；263 路径（184 改、79 增）。`auth.go` diff 仅为错误封装 | 旧高危「所有网卡 + 首次 init 免令牌」仍成立。「不能按默认方式部署」仍成立 | 旧报告正文不在本树；飞书未授权；未列名的旧可疑点无法再核实 |
| R7 | 不新建私库、不改产品代码、不把静态阅读写成已运行验证 | 交付物与表述 | 本分支相对基准 SHA 只计划新增 `audit/`。报告写明未动态验证 | 符合。PR 相对 fork 默认分支会带上上游 53 个提交，那是同步而非本单改产品代码 | — |
| R2a | 代码安全补行：首次设密 | init 是否仍无令牌；数据库故障是否仍被当成未设密 | `server/auth.go` 第 123–125、157–206、32–35 行；`server/server.go` 第 801 行 | 免令牌仍在。故障路径已改为 503，不放行覆盖 | 未发送请求验证 |
| R2b | 代码安全补行：执行隔离 | 未命中规则的默认动作；外泄规则默认开关；自定义代码执行 | `guard/guard.go` 第 92–97 行；`db/db.go` 第 565–571 行；`server/customtool.go` 第 399–401 行 | 默认放行。外泄规则默认关。Python 在本进程执行 | Bash 实现在未读的 `norma` |
| R2c | 代码安全补行：代理与容器 | 8788 绑定、认证、宿主挂载、运行用户 | `Dockerfile` 第 47 行；`docker-compose.yml` 第 33–41 行；`traffic/traffic.go` 第 206–210 行 | 容器内代理全网卡且无认证；宿主端口绑回环。root + `./data`、`./skills` 挂载 | 未启动容器 |
| R4a | 供应链补行：norma | 版本是否固定；代理与 tag 是否一致；OSV | `go.mod` 第 6 行；proxy.golang.org v0.4.3.info；GitHub tag v0.4.3 → `320ae32989da97dd91469bb89164cbfe87d83d5d` | 版本固定且与公开 tag 一致。OSV 未命中。源码未审 | 未读 norma 树 |
| R4b | 供应链补行：Next.js 通告 | 锁版本与生产形态是否同一类运行时 | `web/package-lock.json` 中 next@16.2.9；`web/next.config.mjs` 第 21–24 行静态导出 | 通告命中。发布路径是静态文件由 Go 提供，与通告中的 Next 服务器前提可能不一致 | 未逐条核对通告影响配置，未运行 `next start` |
| R6a | 旧基准补行：依赖版本变化 | crypto/net/mitmproxy 是否升级以及通告是否还在 | `git diff a05a886d 253a8eea -- go.mod` | 有升级。`x/net` v0.61.0 仍命中 GO-2026-6860、GO-2026-6866 | 未做 `go list -m all`，旧 `go.sum` 行是否进入构建未确认 |
| R8 | 功能与使用（2026-11-26 10:14 香港时间追加） | README／docs 宣称对照实现；安装后的命令、配置默认值、一条工作流。每条标未实测 | `audit/RERUN-20261126.md` 第 8 章。入口：`install.sh`、`start.sh`、`cmd/artex/main.go` 第 55–57 行、`/setup`、`agent/provider.go`、`server/mcp_server_tools.go` | 主路径能在源码中找到。不符：开发端口写成 5173 但 `next dev` 未指定端口。部分：Gemini、代理默认地址、数据库示例端口、备份是否含旧 `jwt.key` | 未运行。`docs/漏洞流量证据.md` 未逐项对照。norma 工具循环未读。归并与覆盖图交互未逐屏核对 |
| R9 | 编译与部署要求（同次追加） | Dockerfile／compose／Makefile／包管理器；语言、数据库、外部服务版本；硬件；外网；文档不符。每条标未实测 | `audit/RERUN-20261126.md` 第 9 章。`build.sh` 第 33–49 行，`go.mod` 第 3 行，`release.yml` 第 58、88、142、206 行，`docker-compose.yml` 第 3、18 行 | 无 Makefile。Go 1.26.10，CI 的 Node 为 22，Compose 的 Postgres 为 16-alpine。文档无 GPU／内存下限。不能称为已验证可部署 | 未执行编译、npm ci、compose 或容器。arm64 镜像只看到工作流文本。磁盘与内存占用未测。`Dockerfile.bench` 不在本树 |
