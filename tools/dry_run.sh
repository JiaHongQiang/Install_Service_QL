#!/bin/bash
#===============================================================================
#Dry Run / 模拟运行脚本
# 用于验证配置加载和模拟安装流程
#===============================================================================

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# 加载库
source "${ROOT_DIR}/lib/config_loader.sh"
source "${ROOT_DIR}/lib/logger.sh"

# Mock 常用函数以避免实际执行
check_root() { echo "[MOCK] check_root: Check passed"; }
set_permissions() { echo "[MOCK] set_permissions: Setting permissions for $1"; }
install_sqlite() { echo "[MOCK] install_sqlite: Installing from $1"; }
install_sie() { echo "[MOCK] install_sie: Installing from $1"; }
install_nginx() { echo "[MOCK] install_nginx: Installing from $1"; }
restart_sie() { echo "[MOCK] restart_sie: Restarting SIE service"; }
status_sie() { echo "[MOCK] status_sie: Checking SIE status"; }
safeRmNodeDb() { echo "[MOCK] safeRmNodeDb: Removing DB for node $1"; }
safeAddNodeDb() { echo "[MOCK] safeAddNodeDb: Adding DB for node $1"; }
safeExecsql() { echo "[MOCK] safeExecsql: Executing SQL on node $1: $2"; }
service() { echo "[MOCK] service: Executing service command: $@"; }

echo "==============================================================================="
echo "开始模拟安装流程"
echo "==============================================================================="
echo ""

#===============================================================================
# 模拟黑区安装
#===============================================================================
simulate_black() {
    log_title "模拟：黑区安装"
    
    # 1. 加载配置
    echo "步骤 1: 加载黑区配置"
    load_black_config
    if [ $? -ne 0 ]; then
        log_error "配置文件加载失败"
        return 1
    fi
    show_current_config
    
    # 2. 模拟变量获取
    echo "步骤 2: 验证关键变量"
    echo "NODE_ID: ${NODE_ID}"
    echo "DOMAIN_CODE: ${DOMAIN_CODE}"
    echo "MAIN_IP: ${MAIN_IP}"
    echo "ENABLE_TLS: ${ENABLE_TLS}"
    
    # 3. 模拟逻辑分支
    echo "步骤 3: 模拟安装逻辑"
    if [ "$ENABLE_TLS" = "1" ]; then
        echo "[逻辑验证] TLS已启用，将执行configure_black_tls"
    else
        echo "[逻辑验证] TLS未启用"
    fi
    
    echo "黑色区域模拟完成"
    echo "-------------------------------------------------------------------------------"
}

#===============================================================================
# 模拟红区安装
#===============================================================================
simulate_red() {
    log_title "模拟：红区安装"
    
    # 1. 加载配置
    echo "步骤 1: 加载红区配置"
    load_red_config
    if [ $? -ne 0 ]; then
        log_error "配置文件加载失败"
        return 1
    fi
    show_current_config
    
    # 2. 模拟变量获取
    echo "步骤 2: 验证关键变量"
    echo "NODE_ID: ${NODE_ID}"
    echo "NAT_IP2: ${NAT_IP2}"
    echo "NGINX_PROXY_IP: ${NGINX_PROXY_IP}"
    
    # 3. 模拟逻辑分支
    echo "步骤 3: 模拟安装逻辑"
    if [ -n "$NGINX_PROXY_IP" ]; then
        echo "[逻辑验证] Nginx Proxy IP已配置为: $NGINX_PROXY_IP"
    fi
    
    echo "红色区域模拟完成"
    echo "-------------------------------------------------------------------------------"
}

# 运行模拟
simulate_black
echo ""
simulate_red
