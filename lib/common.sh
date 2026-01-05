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

# 包名模式定义
declare -A PACKAGE_PATTERNS
PACKAGE_PATTERNS=(
    ["deploy_sqlite"]="deploy_sqlite*.run"
    ["deploy_sie"]="deploy_sie*.run"
    ["deploy_nginx"]="deploy_nginx*.run"
)

# 从文件名提取版本号
# 参数: $1=文件名
# 返回: 版本号字符串
extract_version() {
    local filename="$1"
    local version=""
    
    # 尝试匹配 V200R006B07 这种格式
    version=$(echo "$filename" | grep -oP 'V\d+R\d+[A-Z]\d+' 2>/dev/null | head -1)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi
    
    # 尝试匹配 V100R003B17 格式
    version=$(echo "$filename" | grep -oP 'V\d+R\d+B\d+' 2>/dev/null | head -1)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi
    
    # 尝试匹配日期时间格式 20250618111517
    version=$(echo "$filename" | grep -oP '\d{14}' 2>/dev/null | head -1)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi
    
    # 尝试匹配日期格式 20250513
    version=$(echo "$filename" | grep -oP '\d{8}' 2>/dev/null | head -1)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi
    
    # 无法提取版本号，返回空
    echo ""
    return 1
}

# 比较版本号
# 参数: $1=版本1, $2=版本2
# 返回: 0=相等, 1=版本1大, 2=版本2大
compare_versions() {
    local v1="$1"
    local v2="$2"
    
    if [ "$v1" = "$v2" ]; then
        return 0
    fi
    
    # 使用sort -V进行版本排序
    local higher=$(echo -e "$v1\n$v2" | sort -V | tail -1)
    
    if [ "$higher" = "$v1" ]; then
        return 1
    else
        return 2
    fi
}

# 获取最新的安装包（支持版本号排序）
# 参数: $1=包名前缀或包类型key, $2=目录（可选）
# 返回: 最新包的完整路径
get_latest_package() {
    local prefix="$1"
    local search_dir="${2:-$PACKAGES_DIR}"
    
    # 检查是否为预定义的包类型
    local pattern="${PACKAGE_PATTERNS[$prefix]}"
    if [ -z "$pattern" ]; then
        pattern="${prefix}*.run"
    fi
    
    if [ ! -d "$search_dir" ]; then
        echo ""
        return 1
    fi
    
    # 查找匹配的文件
    local matches=()
    while IFS= read -r -d '' file; do
        matches+=("$file")
    done < <(find "$search_dir" -maxdepth 2 -type f -name "$pattern" -print0 2>/dev/null)
    
    local count=${#matches[@]}
    
    if [ $count -eq 0 ]; then
        echo ""
        return 1
    elif [ $count -eq 1 ]; then
        echo "${matches[0]}"
        return 0
    else
        # 多个匹配，选择最新版本
        local latest=""
        local latest_version=""
        local latest_mtime=0
        
        for file in "${matches[@]}"; do
            local filename=$(basename "$file")
            local version=$(extract_version "$filename")
            local mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo "0")
            
            if [ -n "$version" ] && [ -n "$latest_version" ]; then
                # 比较版本号
                compare_versions "$version" "$latest_version"
                local cmp_result=$?
                if [ $cmp_result -eq 1 ]; then
                    latest="$file"
                    latest_version="$version"
                    latest_mtime="$mtime"
                fi
            elif [ -n "$version" ]; then
                latest="$file"
                latest_version="$version"
                latest_mtime="$mtime"
            elif [ "$mtime" -gt "$latest_mtime" ]; then
                # 无法提取版本，使用修改时间
                latest="$file"
                latest_mtime="$mtime"
            fi
        done
        
        if [ -z "$latest" ]; then
            # 兜底：取第一个
            latest="${matches[0]}"
        fi
        
        echo "$latest"
        return 0
    fi
}

# 获取最新的SQLite安装包
get_sqlite_package() {
    local pkg=$(get_latest_package "deploy_sqlite")
    if [ -z "$pkg" ]; then
        pkg=$(get_latest_package "deploy_sqlite" "/home")
    fi
    echo "$pkg"
}

# 获取最新的SIE安装包
get_sie_package() {
    local pkg=$(get_latest_package "deploy_sie")
    if [ -z "$pkg" ]; then
        pkg=$(get_latest_package "deploy_sie" "/home")
    fi
    echo "$pkg"
}

# 获取最新的Nginx安装包
get_nginx_package() {
    local pkg=$(get_latest_package "deploy_nginx")
    if [ -z "$pkg" ]; then
        pkg=$(get_latest_package "deploy_nginx" "/home")
    fi
    echo "$pkg"
}

# 检查必要的安装包是否存在
# 参数: $1=安装类型 (black/red)
# 返回: 0=全部存在, 1=有缺失
check_required_packages() {
    local install_type="$1"
    local missing=0
    
    echo -e "${BLUE}检查必要的安装包...${NC}"
    
    # SQLite 和 SIE 是必须的
    local sqlite_pkg=$(get_sqlite_package)
    if [ -z "$sqlite_pkg" ] || [ ! -f "$sqlite_pkg" ]; then
        echo -e "  ${RED}✗${NC} SQLite安装包: 未找到"
        ((missing++))
    else
        echo -e "  ${GREEN}✓${NC} SQLite安装包: $(basename "$sqlite_pkg")"
    fi
    
    local sie_pkg=$(get_sie_package)
    if [ -z "$sie_pkg" ] || [ ! -f "$sie_pkg" ]; then
        echo -e "  ${RED}✗${NC} SIE安装包: 未找到"
        ((missing++))
    else
        echo -e "  ${GREEN}✓${NC} SIE安装包: $(basename "$sie_pkg")"
    fi
    
    # 红区需要Nginx
    if [ "$install_type" = "red" ]; then
        local nginx_pkg=$(get_nginx_package)
        if [ -z "$nginx_pkg" ] || [ ! -f "$nginx_pkg" ]; then
            echo -e "  ${RED}✗${NC} Nginx安装包: 未找到"
            ((missing++))
        else
            echo -e "  ${GREEN}✓${NC} Nginx安装包: $(basename "$nginx_pkg")"
        fi
    fi
    
    echo ""
    
    if [ $missing -gt 0 ]; then
        echo -e "${RED}缺少 $missing 个必要的安装包${NC}"
        return 1
    fi
    
    echo -e "${GREEN}所有必要的安装包已就绪${NC}"
    return 0
}

# 列出所有可用的安装包
list_packages() {
    echo -e "${BLUE}可用的安装包:${NC}"
    echo "========================================"
    
    if [ -d "$PACKAGES_DIR" ]; then
        echo -e "${YELLOW}packages/ 目录:${NC}"
        echo ""
        
        for key in "${!PACKAGE_PATTERNS[@]}"; do
            local pattern="${PACKAGE_PATTERNS[$key]}"
            local found=$(find "$PACKAGES_DIR" -maxdepth 2 -type f -name "$pattern" 2>/dev/null | head -1)
            
            if [ -n "$found" ]; then
                local version=$(extract_version "$(basename "$found")")
                local size=$(ls -lh "$found" 2>/dev/null | awk '{print $5}')
                echo -e "  ${GREEN}✓${NC} $key: $(basename "$found")"
                [ -n "$version" ] && echo -e "      版本: $version  大小: $size"
            else
                echo -e "  ${RED}✗${NC} $key: 未找到"
            fi
        done
        echo ""
    fi
    
    echo -e "${YELLOW}/home 目录:${NC}"
    local home_packages=$(find /home -maxdepth 1 -name "*.run" -type f 2>/dev/null)
    if [ -n "$home_packages" ]; then
        echo "$home_packages" | while read pkg; do
            local size=$(ls -lh "$pkg" 2>/dev/null | awk '{print $5}')
            echo "  $(basename "$pkg") [$size]"
        done
    else
        echo "  (无)"
    fi
    
    echo "========================================"
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
