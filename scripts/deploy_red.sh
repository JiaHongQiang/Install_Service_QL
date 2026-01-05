#!/bin/bash
#===============================================================================
# 红区安装部署脚本
# Red Zone Deployment Script
# 支持配置文件预配置和交互式输入
#===============================================================================

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# 加载公共库
source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/logger.sh"
source "${ROOT_DIR}/lib/config_loader.sh"

# 工作目录
WORK_DIR="/home"

#===============================================================================
# 红区安装流程
#===============================================================================
deploy_red_zone() {
    log_title "红区安装部署 - Red Zone Deployment"
    
    # 加载红区配置
    load_red_config
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
    
    # 步骤3: 安装Nginx
    log_step 3 "安装Nginx服务"
    local nginx_pkg="${NGINX_PACKAGE:-$(get_nginx_package)}"
    if [ -n "$nginx_pkg" ] && [ -f "$nginx_pkg" ]; then
        log_info "使用安装包: $(basename "$nginx_pkg")"
        install_nginx "$nginx_pkg"
    else
        log_warn "Nginx安装包不存在，跳过"
    fi
    
    # 步骤4: 配置Nginx
    log_step 4 "配置Nginx"
    configure_nginx
    
    # 步骤5: 安装流媒体服务
    log_step 5 "安装SIE流媒体服务"
    local sie_pkg="${SIE_PACKAGE:-$(get_sie_package)}"
    if [ -n "$sie_pkg" ] && [ -f "$sie_pkg" ]; then
        log_info "使用安装包: $(basename "$sie_pkg")"
        install_sie "$sie_pkg"
    else
        log_warn "SIE安装包不存在，跳过"
    fi
    
    # 步骤6: 配置数据库
    log_step 6 "配置数据库"
    configure_red_database
    
    # 步骤7: 重启服务
    log_step 7 "重启服务"
    restart_sie
    status_sie
    
    log_success "红区安装部署完成!"
}

#===============================================================================
# 配置Nginx
#===============================================================================
configure_nginx() {
    log_info "配置Nginx..."
    
    local nginx_conf="/opt/nginx/conf/nginx.conf"
    local template_file="${ROOT_DIR}/templates/nginx.conf"
    
    # 使用模板
    if [ -f "$template_file" ]; then
        backup_file "$nginx_conf"
        cp "$template_file" "$nginx_conf"
        log_info "已使用模板配置Nginx"
    fi
    
    # 获取proxy_pass IP
    local proxy_ip=$(get_ip_param "NGINX_PROXY_IP" "请输入Nginx proxy_pass目标IP" "192.168.16.254")
    
    # 修改配置中的IP
    if [ -f "$nginx_conf" ]; then
        sed -i "s|proxy_pass http://[0-9.]*;|proxy_pass http://${proxy_ip};|g" "$nginx_conf"
        log_info "已设置proxy_pass IP: $proxy_ip"
    fi
    
    # 重启Nginx
    log_info "重启Nginx服务..."
    service nginxd stop
    sleep 1
    service nginxd start
}

#===============================================================================
# 配置红区数据库
#===============================================================================
configure_red_database() {
    log_info "开始配置红区数据库..."
    
    # 获取数据库密码
    DB_PASSWORD=$(get_password_param "DB_PASSWORD" "请输入数据库密码")
    export DB_PASSWORD
    
    # 6.1 配置节点
    log_info "6.1 配置红区节点"
    
    local node_id=$(get_required_param "NODE_ID" "请输入节点ID")
    local local_ip=$(get_ip_param "LOCAL_IP" "请输入本地IP")
    local nat_ip="${NAT_IP:-$local_ip}"  # NAT_IP默认等于LOCAL_IP
    local nat_ip2=$(get_ip_param "NAT_IP2" "请输入红区网关地址")
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
    
    log_info "配置节点: LocalIP=${local_ip}, NatIP=${nat_ip}, NodeID=${node_id}, NatIP2=${nat_ip2}"
    
    safeExecsql $node_id "update t_domain_info set DOMAIN_CODE='${domain_code}',PARENT_DOMAIN_CODE='${domain_code}',DOMAIN_IP='${nat_ip}',DOMAIN_NAT_IP='${nat_ip}' where IS_LOCAL_DOMAIN=1;"
    
    # 6.2 配置网关用户
    log_info "6.2 配置网关用户"
    local encrypt_type=$(get_required_param "ENCRYPT_TYPE" "请输入加密类型 (-1=未加密, 3=黑区加密, 4=红区加密)" "4")
    local user_id=$(get_required_param "GW_USER_ID" "请输入网关用户ID")
    
    safeExecsql $node_id "delete from t_sip_encrypt where NODE_ID = '${node_id}';"
    safeExecsql $node_id "replace into t_sip_encrypt(NODE_ID, CONTAINER_ID, KEY_FILE, DEV_PATH, ENCRYPT_TYPE, KEY_PASS,DEV_ID,USER_ID) VALUES(${node_id},1,'','',${encrypt_type},'','','${user_id}');"
    safeExecsql $node_id "update t_domain_info set DOMAIN_CODE='${domain_code}',PARENT_DOMAIN_CODE='${domain_code}' where IS_LOCAL_DOMAIN=1;"
    
    # 6.3 配置加密卡信息
    log_info "6.3 配置网关加密卡信息"
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
# 主程序
#===============================================================================
main() {
    check_root
    deploy_red_zone
}

main "$@"
