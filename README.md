# 麒麟系统服务安装工具

## 项目概述

用于麒麟系统（Kylin OS LoongArch64）的服务安装部署工具，支持黑区和红区的一键安装配置。

## 目录结构

```
Install_Service_QL/
├── install.sh              # 主入口脚本
├── install.conf            # 配置文件（可预配置参数）
├── README.md               # 本文档
├── lib/                    # 公共库
│   ├── common.sh           # 公共函数
│   ├── logger.sh           # 日志工具
│   └── config_loader.sh    # 配置加载工具
├── scripts/                # 安装脚本
│   ├── deploy_black.sh     # 黑区安装
│   └── deploy_red.sh       # 红区安装
├── config/                 # 配置脚本
│   ├── addnodeBlack.sh     # 黑区节点配置
│   ├── addnodeRed.sh       # 红区节点配置
│   ├── addGwUserConfig.sh  # 网关用户配置
│   ├── addFpgaConfig.sh    # 加密卡配置
│   ├── addTlsConnectConfig.sh  # TLS连接配置
│   ├── configNginx.sh      # Nginx配置脚本
│   └── safeExec.sh         # 安全执行脚本
├── sql/                    # SQL脚本目录
├── tools/                  # 工具脚本
│   ├── selectTool.sh       # 数据查询工具
│   └── update.sh           # 更新工具
├── packages/               # 安装包目录
└── templates/              # 配置模板
    ├── watchdog.ini        # watchdog配置模板
    └── nginx.conf          # Nginx配置模板
```

## 快速开始

### 1. 上传安装包

将以下安装包上传到 `/home` 目录：

**通用包（黑红区都需要）：**
- `deploy_sqlite_loongarch64.run` - SQLite安装包
- `deploy_sie_loongarch64_sqlite_UMP_V200R006B07.run` - 流媒体服务安装包

**红区专用：**
- `deploy_nginx_loongarch64.run` - Nginx安装包

### 2. 上传本项目并设置权限

```bash
cd /home/Install_Service_QL
chmod 755 install.sh scripts/*.sh config/*.sh tools/*.sh
```

### 3. 配置参数（可选）

编辑 `install.conf` 预配置参数，或在安装时交互输入：

```bash
vim install.conf
```

### 4. 运行安装程序

```bash
./install.sh
```

---

## 配置文件说明

`install.conf` 支持预配置所有安装参数。留空的参数将在安装时提示交互式输入。

### 主要配置项

| 配置项 | 说明 | 示例值 |
|--------|------|--------|
| `NODE_ID` | 节点ID | `20` |
| `DOMAIN_CODE` | 域代码 | `2c4d54e8ba` |
| `LOCAL_IP` | 本地IP | `192.168.2.156` |
| `NAT_IP` | NAT IP | `192.168.2.156` |
| `MAIN_IP` | 主节点IP（黑区） | `192.168.2.36` |
| `NAT_IP2` | NAT IP2（红区） | `192.168.16.143` |
| `ENCRYPT_TYPE` | 加密类型 | `3`=黑区, `4`=红区 |
| `GW_USER_ID` | 网关用户ID | `581212517` |
| `FPGA_AGENT_IP` | 加密卡代理IP | `192.168.55.28` |
| `NGINX_PROXY_IP` | Nginx代理目标IP | `192.168.16.254` |
| `DB_PASSWORD` | 数据库密码 | 留空则安装时输入 |

---

## 安装流程

### 黑区安装
1. 安装 SQLite → 2. 安装 SIE → 3. 配置节点 → 4. 配置网关用户 → 5. 配置加密卡 → 6. 配置 TLS（可选） → 7. 重启服务

### 红区安装
1. 安装 SQLite → 2. 安装 Nginx → 3. 配置 Nginx → 4. 安装 SIE → 5. 配置节点 → 6. 配置网关用户 → 7. 配置加密卡 → 8. 重启服务

---

## 单独脚本使用

### addnodeBlack.sh（黑区节点）
```bash
./addnodeBlack.sh <LocalIP> <NatIP> <NodeID> <MainIP> <DomainCode>
```

### addnodeRed.sh（红区节点）
```bash
./addnodeRed.sh <LocalIP> <NatIP> <NodeID> <NatIP2> <DomainCode>
```

### addGwUserConfig.sh（网关用户）
```bash
./addGwUserConfig.sh <NodeID> <EncryptType> <UserID> <DomainCode>
# EncryptType: -1=未加密, 3=黑区加密, 4=红区加密
```

### addFpgaConfig.sh（加密卡）
```bash
./addFpgaConfig.sh <AgentIP> <NegotiationPort> <NodePort> <DataPort> <ContactPort> <NodeID>
```

### configNginx.sh（Nginx配置）
```bash
./configNginx.sh -i 192.168.16.254 -r  # 修改IP并重启
./configNginx.sh -t                     # 使用模板
```

---

## 注意事项

1. 所有脚本需要以 **root** 用户运行
2. 安装前确保安装包已上传到 `/home` 目录
3. TLS 配置前需先将 p12 证书拷贝到 `/home/hy_media_server/bin` 目录

## 服务管理

```bash
service sie restart   # 重启服务
service sie status    # 查看状态
service sie stop      # 停止服务
```

## 日志

日志文件位置：`/var/log/install_service_ql.log`
