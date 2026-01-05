#!/bin/bash
#===============================================================================
# 配置加载与参数获取工具
# Configuration Loader and Parameter Utility
# 支持黑区/红区分区配置
#===============================================================================

# 获取脚本所在目录
CONFIG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$CONFIG_SCRIPT_DIR")"

# 配置文件路径
CONFIG_FILE="${ROOT_DIR}/install.conf"

# 当前区域: BLACK 或 RED
CURRENT_ZONE=""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#===============================================================================
# 加载配置文件
#===============================================================================
load_config() {
    local zone="$1"  # BLACK 或 RED
    
    if [ -z "$zone" ]; then
        echo -e "${RED}错误: 请指定区域 (BLACK 或 RED)${NC}"
        return 1
    fi
    
    CURRENT_ZONE="$zone"
    
    if [ -f "$CONFIG_FILE" ]; then
        # 加载通用配置和指定区域配置
        while IFS='=' read -r key value; do
            # 跳过注释和空行
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ "$key" =~ ^\[.*\]$ ]] && continue
            [[ -z "$key" ]] && continue
            
            # 去除空格和引号
            key=$(echo "$key" | tr -d ' ')
            value=$(echo "$value" | sed 's/^"//' | sed 's/"$//')
            
            # 只加载通用配置和当前区域配置
            if [ -n "$key" ] && [ -n "$value" ]; then
                # 通用配置
                if [[ ! "$key" =~ ^BLACK_ ]] && [[ ! "$key" =~ ^RED_ ]]; then
                    export "$key=$value"
                fi
                # 当前区域配置 - 移除前缀后导出
                if [[ "$key" =~ ^${zone}_ ]]; then
                    local new_key="${key#${zone}_}"
                    export "$new_key=$value"
                fi
            fi
        done < "$CONFIG_FILE"
        echo -e "${GREEN}已加载${zone}区配置: $CONFIG_FILE${NC}"
        return 0
    else
        echo -e "${YELLOW}配置文件不存在，将使用交互模式${NC}"
        return 1
    fi
}

# 加载黑区配置
load_black_config() {
    load_config "BLACK"
}

# 加载红区配置
load_red_config() {
    load_config "RED"
}

#===============================================================================
# 获取参数值 - 优先使用配置，否则交互输入
#===============================================================================

# 获取必填参数
get_required_param() {
    local var_name="$1"
    local prompt="$2"
    local default_value="$3"
    local current_value="${!var_name}"
    
    if [ -n "$current_value" ]; then
        echo "$current_value"
        return 0
    fi
    
    local input_value=""
    while [ -z "$input_value" ]; do
        if [ -n "$default_value" ]; then
            echo -n -e "${prompt} [默认: ${default_value}]: "
            read input_value
            [ -z "$input_value" ] && input_value="$default_value"
        else
            echo -n -e "${prompt}: "
            read input_value
            if [ -z "$input_value" ]; then
                echo -e "${RED}此参数不能为空，请重新输入${NC}"
            fi
        fi
    done
    
    export "$var_name=$input_value"
    echo "$input_value"
}

# 获取可选参数
get_optional_param() {
    local var_name="$1"
    local prompt="$2"
    local default_value="$3"
    local current_value="${!var_name}"
    
    if [ -n "$current_value" ]; then
        echo "$current_value"
        return 0
    fi
    
    echo -n -e "${prompt} [默认: ${default_value}]: "
    read input_value
    [ -z "$input_value" ] && input_value="$default_value"
    
    export "$var_name=$input_value"
    echo "$input_value"
}

# 获取密码参数
get_password_param() {
    local var_name="$1"
    local prompt="$2"
    local current_value="${!var_name}"
    
    if [ -n "$current_value" ]; then
        echo "$current_value"
        return 0
    fi
    
    local input_value=""
    while [ -z "$input_value" ]; do
        echo -n -e "${prompt}: "
        read -s input_value
        echo
        if [ -z "$input_value" ]; then
            echo -e "${RED}密码不能为空，请重新输入${NC}"
        fi
    done
    
    export "$var_name=$input_value"
    echo "$input_value"
}

# 获取确认参数
get_confirm_param() {
    local var_name="$1"
    local prompt="$2"
    local default_value="$3"
    local current_value="${!var_name}"
    
    if [ -n "$current_value" ]; then
        echo "$current_value"
        return $current_value
    fi
    
    echo -n -e "${prompt} [y/N]: "
    read answer
    
    case $answer in
        [Yy]* ) export "$var_name=1"; echo "1"; return 0 ;;
        * ) export "$var_name=0"; echo "0"; return 1 ;;
    esac
}

# IP地址验证
validate_ip() {
    local ip=$1
    if [[ ${ip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "${ip}"
        for i in "${ADDR[@]}"; do
            [[ $i -gt 255 ]] && return 1
        done
        return 0
    fi
    return 1
}

# 获取IP地址参数
get_ip_param() {
    local var_name="$1"
    local prompt="$2"
    local default_value="$3"
    local current_value="${!var_name}"
    
    if [ -n "$current_value" ] && validate_ip "$current_value"; then
        echo "$current_value"
        return 0
    fi
    
    local input_value=""
    while true; do
        if [ -n "$default_value" ]; then
            echo -n -e "${prompt} [默认: ${default_value}]: "
            read input_value
            [ -z "$input_value" ] && input_value="$default_value"
        else
            echo -n -e "${prompt}: "
            read input_value
        fi
        
        if [ -z "$input_value" ]; then
            echo -e "${RED}IP地址不能为空${NC}"
        elif validate_ip "$input_value"; then
            break
        else
            echo -e "${RED}IP地址格式无效，请重新输入${NC}"
        fi
    done
    
    export "$var_name=$input_value"
    echo "$input_value"
}

#===============================================================================
# 显示当前配置
#===============================================================================
show_current_config() {
    echo ""
    echo "==============================================================================="
    echo -e "                    ${BLUE}${CURRENT_ZONE}区 当前配置${NC}"
    echo "==============================================================================="
    echo "  节点ID:        ${NODE_ID:-<未配置>}"
    echo "  域代码:        ${DOMAIN_CODE:-<未配置>}"
    echo "  本地IP:        ${LOCAL_IP:-<未配置>}"
    echo "  NAT IP:        ${NAT_IP:-<未配置>}"
    echo "  加密类型:      ${ENCRYPT_TYPE:-<未配置>}"
    echo "  网关用户ID:    ${GW_USER_ID:-<未配置>}"
    echo "  加密卡IP:      ${FPGA_AGENT_IP:-<未配置>}"
    if [ "$CURRENT_ZONE" = "BLACK" ]; then
        echo "  主节点IP:      ${MAIN_IP:-<未配置>}"
        echo "  TLS启用:       ${ENABLE_TLS:-0}"
    else
        echo "  NAT IP2:       ${NAT_IP2:-<未配置>}"
        echo "  Nginx代理IP:   ${NGINX_PROXY_IP:-<未配置>}"
    fi
    echo "==============================================================================="
    echo ""
}

#===============================================================================
# 导出函数
#===============================================================================
export -f load_config load_black_config load_red_config
export -f get_required_param get_optional_param get_password_param
export -f get_confirm_param get_ip_param validate_ip show_current_config
