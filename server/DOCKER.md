# 血潮守望 Docker 部署包

支持 **Linux x86_64 / amd64**，不适用于 ARM 服务器。运行需要 Docker Engine 和 Docker Compose v2；服务器不需要另装 Python 或 Godot，也不需要项目源码。

包内镜像：

- `crimson-tide-server:1.0.1`：Python 账号/云存档 API、Godot 4.7.2、预导入游戏资源和房间工作进程。
- `caddy:2.10-alpine`：HTTPS 反向代理和自动证书续期。

## 1. 上传并解压

上传 `crimson-tide-docker-linux-amd64.zip` 到服务器。在准备部署的目录执行：

```bash
unzip crimson-tide-docker-linux-amd64.zip -d crimson-tide
cd crimson-tide
```

目录应包含：

```text
images-linux-amd64.tar.gz
SHA256SUMS
compose.yaml
.env.example
server/Caddyfile.docker
README.md
```

检查架构和 Docker：

```bash
uname -m
docker version
docker compose version
```

`uname -m` 应为 `x86_64`。以下 Docker 命令需要有 Docker 权限的用户执行，必要时加 `sudo`。

## 2. 导入镜像

```bash
sha256sum -c SHA256SUMS
docker load -i images-linux-amd64.tar.gz
docker image ls crimson-tide-server
```

镜像在本地打包时已经构建完成，不要在部署包目录运行 `docker build`。

## 3. 配置自己的域名

将实际域名（例如 `game.yourdomain.com`）的 DNS A 记录指向服务器公网 IPv4。若有 AAAA 记录，它也必须能访问同一台服务器。使用 Cloudflare 等服务时，此域名设置为“仅 DNS”，因为游戏房间需要直接通过 UDP 连接服务器。

```bash
cp .env.example .env
nano .env
```

例如：

```dotenv
SERVER_DOMAIN=game.yourdomain.com
```

这里不写 `https://`、端口或路径。这个值既用于申请 HTTPS 证书，也作为玩家连接房间的地址。`example.com` 是占位值，不能直接使用。

## 4. 开放端口

在云服务器安全组以及主机防火墙中放行：

| 端口 | 协议 | 用途 |
|---|---|---|
| 80 | TCP | HTTPS 自动证书验证和 HTTP 跳转 |
| 443 | TCP | 注册、登录、云存档和房间 API |
| 24900–24915 | UDP | 最多 16 个服务器房间，每房间最多 4 人 |

8080 仅绑定本机回环地址，不需要向公网开放。此部署方式也不需要开放原 IP 直连的 24872 端口。已有 SSH 规则保持不变。

如果已启用 UFW，可以添加：

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 24900:24915/udp
```

## 5. 一条命令启动

```bash
docker compose --profile https up -d --no-build --pull never
```

API、游戏房间和 HTTPS 会一起启动，容器异常退出后会自动重启。Caddy 申请证书需要访问互联网。

查看状态：

```bash
docker compose --profile https ps
docker compose --profile https logs --tail=100
curl http://127.0.0.1:8080/health
curl https://game.yourdomain.com/health
```

健康接口应返回 `{"status":"ok"}`。首次申请证书可能需要稍等片刻。

如果服务器已有 Nginx/Caddy 占用 80/443，只启动游戏服务：

```bash
docker compose up -d --no-build --pull never server
```

让现有反向代理把实际 HTTPS 域名转发至 `http://127.0.0.1:8080`。原有代理若也运行在容器里，需要接入相同 Docker 网络并转发到 `server:8080`，容器里的 `127.0.0.1` 不是宿主机。

## 6. 配置游戏客户端

在游戏可执行文件旁放置 `game.cfg`：

```ini
[server]
api_url="https://game.yourdomain.com"
request_timeout=12.0
```

客户端需使用与镜像对应的这份项目版本。打开游戏，注册或游客登录 → 创建 / 加入房间 → 服务器房间。创建者将六位房间号分享给其他玩家即可。

## 从 1.0.0 更新到 1.0.1

1.0.1 修复创建服务器房间后无法进入营地的问题：房间进程的 RPC 节点路径现在与游戏客户端一致。客户端使用提交 `781fe62` 或更新版本。

将新版部署包上传到服务器并解压到一个临时目录。以下命令在**原部署目录**执行，将 `/tmp/crimson-tide-update` 替换为新版部署包的解压目录：

```bash
# 验证并导入新版镜像
(cd /tmp/crimson-tide-update && sha256sum -c SHA256SUMS)
docker load -i /tmp/crimson-tide-update/images-linux-amd64.tar.gz

# 备份账号和云存档
docker compose exec -T server python -c "import sqlite3; src=sqlite3.connect('/data/accounts.sqlite3'); dst=sqlite3.connect('/data/accounts.backup.sqlite3'); src.backup(dst); dst.close(); src.close()"
docker compose cp server:/data/accounts.backup.sqlite3 ./accounts.backup.sqlite3

# 保留原来的 .env、域名、数据卷和 HTTPS 配置，仅更新服务镜像
cp compose.yaml compose.yaml.before-1.0.1
sed -i 's/crimson-tide-server:1.0.0/crimson-tide-server:1.0.1/g' compose.yaml
docker compose up -d --no-build --pull never --force-recreate server
docker compose ps server
curl --fail http://127.0.0.1:8080/health
docker compose logs --tail=100 server
```

更新会结束现有房间，完成后重新创建房间即可；账号、云存档和证书卷保留。不要执行 `down -v`。镜像中已包含代码，单独 `git pull` 或 `docker restart` 不会替换旧镜像。

## 数据与日常管理

账号和云存档保存在 Docker 命名卷 `crimson-tide_game-data`，服务进程以 UID/GID `10001` 运行。替换镜像、重启和普通 `docker compose down` 不会删除数据。不要执行 `docker compose down -v`，它会删除数据卷。

```bash
# 查看日志（Ctrl+C 只退出日志查看）
docker compose logs -f server

# 更改 .env 后应用配置
docker compose --profile https up -d --no-build --pull never

# 停止，保留账号、存档和证书数据
docker compose --profile https down

# 再次启动
docker compose --profile https up -d --no-build --pull never
```

停止或更新服务会结束正在进行的房间，玩家需要重新建房。

使用 SQLite 在线备份，不必停服：

```bash
docker compose exec -T server python -c "import sqlite3; src=sqlite3.connect('/data/accounts.sqlite3'); dst=sqlite3.connect('/data/accounts.backup.sqlite3'); src.backup(dst); dst.close(); src.close()"
docker compose cp server:/data/accounts.backup.sqlite3 ./accounts.backup.sqlite3
```

把备份另存到其他位置。`/data/room-*/worker.log` 是房间诊断日志，可通过容器查看；结束房间的日志会保留。

## 故障排查

- HTTPS 无法访问：检查 DNS、80/443 安全组规则、端口占用，以及 `docker compose logs caddy`。
- 可以登录但进不去房间：检查 UDP 24900–24915 是否映射和放行、域名是否仅 DNS、`.env` 中地址是否为公网可达地址。
- 创建房间失败：检查 `docker compose logs server`，以及容器 `/data/room-*/worker.log`。
- `exec format error`：确认服务器是 x86_64，而非 ARM。
- 修改域名后没有变化：重新执行 `docker compose --profile https up -d --no-build --pull never`，并修改客户端 `game.cfg`。

## 源码构建与验证（仅开发者）

在完整项目根目录运行：

```bash
docker build --platform linux/amd64 --target test -t crimson-tide-server:test .
docker build --platform linux/amd64 --target runtime -t crimson-tide-server:1.0.1 .
python tools/package_server.py --skip-build
```

构建会从 Godot 官方发布页下载 4.7.2 并验证官方 SHA-512 校验和，再在 Linux 环境导入资源；不会打包本机账号数据库、存档、Git 历史或 Windows 导出文件。

本次验证：容器内 583 项规则测试、账号/云存档/四人房间/游戏 UI 流程通过；另用四个 Windows Godot 客户端通过容器映射的 UDP 端口接入 Linux 房间，验证准备、快照、技能和房主移交，验证 SIGTERM 正常退出及重启后账号/云存档保留。公网 DNS 与真实证书签发需要在你的服务器完成。
