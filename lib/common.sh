#!/bin/bash
#===============================================================================
# 公共函数库
# Common Functions Library
#===============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本根目录
get_root_dir() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(dirname "$script_dir")"
}

ROOT_DIR="$(get_root_dir)"

#===============================================================================
# 权限与环境检查
#===============================================================================

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        echo "请使用 sudo 或 root 用户执行"
        exit 1
    fi
}

# 设置脚本执行权限
set_permissions() {
    local dir="${1:-.}"
    echo -e "${BLUE}设置执行权限...${NC}"
    chmod 755 "${dir}"/*.run 2>/dev/null
    chmod 755 "${dir}"/*.sh 2>/dev/null
    chmod 644 "${dir}"/*.sql 2>/dev/null
    chmod 644 "${dir}"/*.ini 2>/dev/null
    echo -e "${GREEN}权限设置完成${NC}"
}

#===============================================================================
# 服务管理
#===============================================================================

# 重启SIE服务
restart_sie() {
    echo -e "${BLUE}正在重启SIE服务...${NC}"
    service sie restart
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SIE服务重启成功${NC}"
    else
        echo -e "${RED}SIE服务重启失败${NC}"
        return 1
    fi
}

# 停止SIE服务
stop_sie() {
    echo -e "${BLUE}正在停止SIE服务...${NC}"
    service sie stop
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SIE服务已停止${NC}"
    else
        echo -e "${YELLOW}SIE服务停止可能失败${NC}"
    fi
}

# 查看SIE服务状态
status_sie() {
    echo -e "${BLUE}SIE服务状态:${NC}"
    service sie status
}

# 重启Nginx服务
restart_nginx() {
    echo -e "${BLUE}正在重启Nginx服务...${NC}"
    service nginxd stop
    sleep 1
    service nginxd start
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Nginx服务重启成功${NC}"
    else
        echo -e "${RED}Nginx服务重启失败${NC}"
        return 1
    fi
}

#===============================================================================
# 安装包管理
#===============================================================================

# 包目录
PACKAGES_DIR="${ROOT_DIR}/packages"

# 获取最新的安装包
# 用法: get_latest_package <包名前缀> [目录]
# 示例: get_latest_package "deploy_sqlite" 
# 返回: 最新包的完整路径
get_latest_package() {
    local prefix="$1"
    local search_dir="${2:-$PACKAGES_DIR}"
    
    if [ ! -d "$search_dir" ]; then
        echo ""
        return 1
    fi
    
    # 查找匹配的包，按修改时间排序，取最新的
    local latest_package=$(find "$search_dir" -maxdepth 2 -name "${prefix}*.run" -type f 2>/dev/null | \
        xargs -r ls -t 2>/dev/null | head -n 1)
    
    if [ -n "$latest_package" ] && [ -f "$latest_package" ]; then
        echo "$latest_package"
        return 0
    else
        echo ""
        return 1
    fi
}

# 获取最新的SQLite安装包
get_sqlite_package() {
    local pkg=$(get_latest_package "deploy_sqlite")
    if [ -z "$pkg" ]; then
        # 回退到/home目录
        pkg=$(find /home -maxdepth 1 -name "deploy_sqlite*.run" -type f 2>/dev/null | head -n 1)
    fi
    echo "$pkg"
}

# 获取最新的SIE安装包
get_sie_package() {
    local pkg=$(get_latest_package "deploy_sie")
    if [ -z "$pkg" ]; then
        pkg=$(find /home -maxdepth 1 -name "deploy_sie*.run" -type f 2>/dev/null | head -n 1)
    fi
    echo "$pkg"
}

# 获取最新的Nginx安装包
get_nginx_package() {
    local pkg=$(get_latest_package "deploy_nginx")
    if [ -z "$pkg" ]; then
        pkg=$(find /home -maxdepth 1 -name "deploy_nginx*.run" -type f 2>/dev/null | head -n 1)
    fi
    echo "$pkg"
}

# 列出所有可用的安装包
list_packages() {
    echo -e "${BLUE}可用的安装包:${NC}"
    echo "----------------------------------------"
    
    if [ -d "$PACKAGES_DIR" ]; then
        echo -e "${YELLOW}packages/ 目录:${NC}"
        find "$PACKAGES_DIR" -name "*.run" -type f 2>/dev/null | while read pkg; do
            local size=$(ls -lh "$pkg" | awk '{print $5}')
            local mtime=$(stat -c "%y" "$pkg" 2>/dev/null | cut -d'.' -f1)
            echo "  $(basename "$pkg") [$size] $mtime"
        done
    fi
    
    echo -e "${YELLOW}/home 目录:${NC}"
    find /home -maxdepth 1 -name "*.run" -type f 2>/dev/null | while read pkg; do
        local size=$(ls -lh "$pkg" | awk '{print $5}')
        echo "  $(basename "$pkg") [$size]"
    done
    
    echo "----------------------------------------"
}

#===============================================================================
# 安装包执行
#===============================================================================

# 安装SQLite
install_sqlite() {
    local package_path="${1:-./deploy_sqlite_loongarch64.run}"
    if [ ! -f "$package_path" ]; then
        echo -e "${RED}错误: SQLite安装包不存在: $package_path${NC}"
        return 1
    fi
    echo -e "${BLUE}正在安装SQLite...${NC}"
    chmod 755 "$package_path"
    "$package_path"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SQLite安装完成${NC}"
    else
        echo -e "${RED}SQLite安装失败${NC}"
        return 1
    fi
}

# 安装流媒体服务
install_sie() {
    local package_path="${1:-./deploy_sie_loongarch64_sqlite_UMP_V200R006B07.run}"
    if [ ! -f "$package_path" ]; then
        echo -e "${RED}错误: SIE安装包不存在: $package_path${NC}"
        return 1
    fi
    echo -e "${BLUE}正在安装SIE流媒体服务...${NC}"
    chmod 755 "$package_path"
    "$package_path"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SIE流媒体服务安装完成${NC}"
    else
        echo -e "${RED}SIE流媒体服务安装失败${NC}"
        return 1
    fi
}

# 安装Nginx
install_nginx() {
    local package_path="${1:-./deploy_nginx_loongarch64.run}"
    if [ ! -f "$package_path" ]; then
        echo -e "${RED}错误: Nginx安装包不存在: $package_path${NC}"
        return 1
    fi
    echo -e "${BLUE}正在安装Nginx...${NC}"
    chmod 755 "$package_path"
    "$package_path"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Nginx安装完成${NC}"
    else
        echo -e "${RED}Nginx安装失败${NC}"
        return 1
    fi
}

#===============================================================================
# 用户交互
#===============================================================================

# 按任意键继续
press_any_key() {
    echo ""
    echo -n "按任意键继续..."
    read -n 1 -s
    echo ""
}

# 确认操作
confirm() {
    local message="${1:-确认继续?}"
    echo -n -e "${YELLOW}${message} [y/N]: ${NC}"
    read answer
    case $answer in
        [Yy]* ) return 0;;
        * ) return 1;;
    esac
}

# 输入非空值
input_required() {
    local prompt="$1"
    local value=""
    while [ -z "$value" ]; do
        echo -n "$prompt: "
        read value
        if [ -z "$value" ]; then
            echo -e "${RED}输入不能为空，请重新输入${NC}"
        fi
    done
    echo "$value"
}

# IP地址验证
validate_ip() {
    local ip=$1
    if [[ -z "${ip}" ]]; then
        return 1
    elif [[ ${ip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "${ip}"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# 端口验证
validate_port() {
    local port=$1
    if [[ ${port} =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
        return 0
    else
        return 1
    fi
}

#===============================================================================
# 文件操作
#===============================================================================

# 备份文件
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup"
        echo -e "${GREEN}已备份: $backup${NC}"
    fi
}

# 检查文件是否存在
check_file_exists() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo -e "${RED}错误: 文件不存在: $file${NC}"
        return 1
    fi
    return 0
}
