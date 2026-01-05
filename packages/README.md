# 安装包目录

此目录用于存放安装包文件。

## 目录结构

```
packages/
├── deploy_sqlite_loongarch64_v1.0.run
├── deploy_sqlite_loongarch64_v1.1.run      # ← 脚本自动使用最新版本
├── deploy_sie_loongarch64_UMP_V200R006B06.run
├── deploy_sie_loongarch64_UMP_V200R006B07.run  # ← 脚本自动使用最新版本
├── deploy_nginx_loongarch64_v1.0.run
└── ...
```

## 自动筛选逻辑

安装脚本会自动选择**最新的安装包**（按文件修改时间排序）：

| 包类型 | 前缀匹配 | 筛选函数 |
|--------|----------|----------|
| SQLite | `deploy_sqlite*.run` | `get_sqlite_package` |
| SIE | `deploy_sie*.run` | `get_sie_package` |
| Nginx | `deploy_nginx*.run` | `get_nginx_package` |

## 使用方式

1. **自动选择**：将安装包放入此目录，脚本会自动使用最新版本
2. **手动指定**：在 `install.conf` 中设置具体路径：
   ```ini
   SIE_PACKAGE="/path/to/specific_version.run"
   ```

## 查看可用包

```bash
# 在主目录运行
source lib/common.sh
list_packages
```
