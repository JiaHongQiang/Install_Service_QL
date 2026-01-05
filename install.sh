#!/bin/bash
#===============================================================================
# 麒麟系统服务安装工具
# Kylin OS Service Installation Tool
# 版本: 1.0.0
# 说明: 用于黑区、红区服务的一键安装部署
#===============================================================================

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共库
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/logger.sh"

#===============================================================================
# 主菜单
#===============================================================================
show_main_menu() {
    clear
    echo "==============================================================================="
    echo "                    麒麟系统服务安装工具 v1.0.0"
    echo "                    Kylin OS Service Installation Tool"
    echo "==============================================================================="
    echo ""
    echo "  请选择安装区域 / Please select installation zone:"
    echo ""
    echo "  1. 安装黑区服务 (Black Zone Installation)"
    echo "  2. 安装红区服务 (Red Zone Installation)"
    echo "  3. 单独配置模块 (Individual Configuration)"
    echo "  4. 工具脚本 (Utility Tools)"
    echo "  0. 退出 (Exit)"
    echo ""
    echo "==============================================================================="
    echo -n "  请输入选项 [0-4]: "
}

#===============================================================================
# 配置子菜单
#===============================================================================
show_config_menu() {
    clear
    echo "==============================================================================="
    echo "                         单独配置模块"
    echo "==============================================================================="
    echo ""
    echo "  1. 配置节点 (黑区) - addnodeBlack.sh"
    echo "  2. 配置节点 (红区) - addnodeRed.sh"
    echo "  3. 配置网关用户 - addGwUserConfig.sh"
    echo "  4. 配置加密卡信息 - addFpgaConfig.sh"
    echo "  5. 配置TLS连接 (黑区) - addTlsConnectConfig.sh"
    echo "  0. 返回主菜单"
    echo ""
    echo "==============================================================================="
    echo -n "  请输入选项 [0-5]: "
}

#===============================================================================
# 工具子菜单
#===============================================================================
show_tools_menu() {
    clear
    echo "==============================================================================="
    echo "                           工具脚本"
    echo "==============================================================================="
    echo ""
    echo "  1. 查询SQLite数据 - selectTool.sh"
    echo "  2. 执行更新脚本 - update.sh"
    echo "  3. 查看服务状态"
    echo "  4. 重启服务"
    echo "  0. 返回主菜单"
    echo ""
    echo "==============================================================================="
    echo -n "  请输入选项 [0-4]: "
}

#===============================================================================
# 处理配置菜单
#===============================================================================
handle_config_menu() {
    while true; do
        show_config_menu
        read choice
        case $choice in
            1)
                log_info "启动黑区节点配置..."
                cd "${SCRIPT_DIR}/config" && bash addnodeBlack.sh
                press_any_key
                ;;
            2)
                log_info "启动红区节点配置..."
                cd "${SCRIPT_DIR}/config" && bash addnodeRed.sh
                press_any_key
                ;;
            3)
                log_info "启动网关用户配置..."
                cd "${SCRIPT_DIR}/config" && bash addGwUserConfig.sh
                press_any_key
                ;;
            4)
                log_info "启动加密卡配置..."
                cd "${SCRIPT_DIR}/config" && bash addFpgaConfig.sh
                press_any_key
                ;;
            5)
                log_info "启动TLS连接配置..."
                cd "${SCRIPT_DIR}/config" && bash addTlsConnectConfig.sh
                press_any_key
                ;;
            0)
                return
                ;;
            *)
                log_warn "无效选项，请重新选择"
                sleep 1
                ;;
        esac
    done
}

#===============================================================================
# 处理工具菜单
#===============================================================================
handle_tools_menu() {
    while true; do
        show_tools_menu
        read choice
        case $choice in
            1)
                log_info "启动SQLite查询工具..."
                cd "${SCRIPT_DIR}/tools" && bash selectTool.sh
                press_any_key
                ;;
            2)
                log_info "执行更新脚本..."
                cd "${SCRIPT_DIR}/tools" && bash update.sh
                press_any_key
                ;;
            3)
                log_info "查看服务状态..."
                service sie status
                press_any_key
                ;;
            4)
                log_info "重启服务..."
                service sie restart
                press_any_key
                ;;
            0)
                return
                ;;
            *)
                log_warn "无效选项，请重新选择"
                sleep 1
                ;;
        esac
    done
}

#===============================================================================
# 主程序入口
#===============================================================================
main() {
    # 检查是否为root用户
    check_root
    
    while true; do
        show_main_menu
        read choice
        case $choice in
            1)
                log_info "开始黑区安装..."
                bash "${SCRIPT_DIR}/scripts/deploy_black.sh"
                press_any_key
                ;;
            2)
                log_info "开始红区安装..."
                bash "${SCRIPT_DIR}/scripts/deploy_red.sh"
                press_any_key
                ;;
            3)
                handle_config_menu
                ;;
            4)
                handle_tools_menu
                ;;
            0)
                log_info "退出安装程序"
                exit 0
                ;;
            *)
                log_warn "无效选项，请重新选择"
                sleep 1
                ;;
        esac
    done
}

# 运行主程序
main "$@"
