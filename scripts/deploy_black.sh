#!/bin/bash
#===============================================================================
# 黑区安装部署脚本
# Black Zone Deployment Script
# 支持配置文件预配置和交互式输入
#===============================================================================

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# 加载公共库
source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/logger.sh"
source "${ROOT_DIR}/lib/config_loader.sh"

# 工作目录 (安装包所在目录)
WORK_DIR="/home"

#===============================================================================
# 黑区安装流程
#===============================================================================
deploy_black_zone() {
    log_title "黑区安装部署 - Black Zone Deployment"
    
    # 预检查安装包
    if ! check_required_packages "black"; then
        log_error "请先将安装包放入 packages/ 目录"
        return 1
    fi
    
    # 加载黑区配置
    load_black_config
    show_current_config
    
    # 步骤1: 设置权限
    log_step 1 "设置文件权限"
    cd "$WORK_DIR"
    set_permissions "$WORK_DIR"
    
    # 步骤2: 安装SQLite
    log_step 2 "安装SQLite数据库"
    local sqlite_pkg="${SQLITE_PACKAGE:-$(get_sqlite_package)}"
    if [ -n "$sqlite_pkg" ] && [ -f "$sqlite_pkg" ]; then
        log_info "使用安装包: $(basename "$sqlite_pkg")"
        install_sqlite "$sqlite_pkg"
    else
        log_warn "SQLite安装包不存在，跳过"
    fi
    
    # 步骤3: 安装流媒体服务
    log_step 3 "安装SIE流媒体服务"
    local sie_pkg="${SIE_PACKAGE:-$(get_sie_package)}"
    if [ -n "$sie_pkg" ] && [ -f "$sie_pkg" ]; then
        log_info "使用安装包: $(basename "$sie_pkg")"
        install_sie "$sie_pkg"
    else
        log_warn "SIE安装包不存在，跳过"
    fi
    
    # 步骤4: 配置数据库
    log_step 4 "配置数据库"
    configure_black_database
    
    # 步骤5: 配置TLS (可选)
    log_step 5 "配置TLS服务"
    local enable_tls=$(get_confirm_param "ENABLE_TLS" "是否配置TLS连接?" "0")
    if [ "$enable_tls" = "1" ]; then
        configure_black_tls
    fi
    
    # 步骤6: 重启服务
    log_step 6 "重启服务"
    restart_sie
    status_sie
    
    log_success "黑区安装部署完成!"
}

#===============================================================================
# 配置黑区数据库
#===============================================================================
configure_black_database() {
    log_info "开始配置黑区数据库..."
    
    # 获取数据库密码
    DB_PASSWORD=$(get_password_param "DB_PASSWORD" "请输入数据库密码")
    export DB_PASSWORD
    
    # 4.1 配置节点
    log_info "4.1 配置黑区节点"
    
    # 从配置文件或交互获取参数
    local node_id=$(get_required_param "NODE_ID" "请输入节点ID")
    local local_ip=$(get_ip_param "LOCAL_IP" "请输入本地IP")
    local nat_ip="${NAT_IP:-$local_ip}"  # NAT_IP默认等于LOCAL_IP
    local main_ip=$(get_ip_param "MAIN_IP" "请输入主节点IP")
    local domain_code=$(get_required_param "DOMAIN_CODE" "请输入域代码")
    
    # 配置watchdog.ini
    cp "${ROOT_DIR}/templates/watchdog.ini" /home/hy_media_server/conf/
    sed -i "s/-n [0-9]\+/ -n ${node_id}/g" /home/hy_media_server/conf/watchdog.ini
    
    # 执行节点配置
    cd "${ROOT_DIR}/config"
    source ./safeExec.sh
    
    service sie stop
    safeRmNodeDb $node_id
    safeAddNodeDb $node_id
    
    log_info "配置节点: LocalIP=${local_ip}, NatIP=${nat_ip}, NodeID=${node_id}, MainIP=${main_ip}"
    
    # 执行SQL配置...
    safeExecsql $node_id "update t_domain_info set DOMAIN_CODE='${domain_code}',PARENT_DOMAIN_CODE='${domain_code}',DOMAIN_IP='${nat_ip}',DOMAIN_NAT_IP='${nat_ip}' where IS_LOCAL_DOMAIN=1;"
    
    # 4.2 配置网关用户
    log_info "4.2 配置网关用户"
    local encrypt_type=$(get_required_param "ENCRYPT_TYPE" "请输入加密类型 (-1=未加密, 3=黑区加密, 4=红区加密)" "3")
    local user_id=$(get_required_param "GW_USER_ID" "请输入网关用户ID")
    
    safeExecsql $node_id "delete from t_sip_encrypt where NODE_ID = '${node_id}';"
    safeExecsql $node_id "replace into t_sip_encrypt(NODE_ID, CONTAINER_ID, KEY_FILE, DEV_PATH, ENCRYPT_TYPE, KEY_PASS,DEV_ID,USER_ID) VALUES(${node_id},1,'','',${encrypt_type},'','','${user_id}');"
    
    # 4.3 配置加密卡信息
    log_info "4.3 配置网关加密卡信息"
    local agent_ip=$(get_ip_param "FPGA_AGENT_IP" "请输入加密卡代理IP")
    local nego_port=$(get_optional_param "FPGA_NEGOTIATION_PORT" "请输入协商端口" "16001")
    local node_port=$(get_optional_param "FPGA_NODE_PORT" "请输入节点端口" "16002")
    local data_port=$(get_optional_param "FPGA_DATA_PORT" "请输入数据端口" "16003")
    local contact_port=$(get_optional_param "FPGA_CONTACT_PORT" "请输入联系端口" "500")
    
    safeExecsql $node_id "delete from t_scm_agent_info where NODE_ID = '${node_id}';"
    safeExecsql $node_id "insert into t_scm_agent_info(AGENT_IP, NEGOTIATTE_PORT, NODE_COMMUNICATION_PORT, DATA_PORT, CONTACT_PORT, NODE_ID,CONTAINER_ID) VALUES('${agent_ip}',${nego_port},${node_port},${data_port},${contact_port},${node_id},1);"
    
    log_success "数据库配置完成"
}

#===============================================================================
# 配置黑区TLS
#===============================================================================
configure_black_tls() {
    log_info "开始配置黑区TLS..."
    
    local node_id="${NODE_ID}"
    local verify_cert=$(get_optional_param "TLS_VERIFY_CERT" "是否校验证书 (0=否, 1=是)" "1")
    
    # TLS密码默认使用GW_USER_ID
    local password="${TLS_PASSWORD:-$GW_USER_ID}"
    
    # P12证书处理：从packages目录复制到目标路径
    local p12_filename="${TLS_P12_FILE:-${password}.p12}"
    local p12_source="${ROOT_DIR}/packages/${p12_filename}"
    local p12_target="/home/hy_media_server/bin/${p12_filename}"
    
    if [ -f "$p12_source" ]; then
        log_info "复制P12证书: $p12_filename -> $p12_target"
        cp "$p12_source" "$p12_target"
        chmod 644 "$p12_target"
        # 设置与hy_media_server目录相同的所有者
        if [ -d "/home/hy_media_server" ]; then
            local owner=$(stat -c "%U:%G" /home/hy_media_server 2>/dev/null)
            [ -n "$owner" ] && chown "$owner" "$p12_target"
        fi
        log_success "P12证书已复制"
    else
        log_warn "P12证书不存在: $p12_source"
        log_warn "请确保证书文件已放入 packages/ 目录"
    fi
    
    cd "${ROOT_DIR}/config"
    bash addTlsConnectConfig.sh "$node_id" "$verify_cert" "$password" "$p12_target" "auto"
}

#===============================================================================
# 主程序
#===============================================================================
main() {
    check_root
    deploy_black_zone
}

main "$@"
