#!/bin/sh
#===============================================================================
# Nginx配置脚本
# 用于配置Nginx的proxy_pass IP地址
#===============================================================================

NGINX_CONF="/opt/nginx/conf/nginx.conf"
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../templates" && pwd)"

# 显示使用帮助
show_usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -i, --ip <IP>     设置proxy_pass的目标IP地址"
    echo "  -t, --template    使用模板覆盖nginx.conf"
    echo "  -b, --backup      备份当前nginx.conf"
    echo "  -r, --restart     重启Nginx服务"
    echo "  -h, --help        显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -i 192.168.16.254 -r    # 修改IP并重启Nginx"
    echo "  $0 -t -i 192.168.16.254    # 使用模板并修改IP"
}

# 备份配置文件
backup_config() {
    if [ -f "$NGINX_CONF" ]; then
        local backup_file="${NGINX_CONF}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$NGINX_CONF" "$backup_file"
        echo "已备份配置文件: $backup_file"
    fi
}

# 使用模板
use_template() {
    local template_file="${TEMPLATE_DIR}/nginx.conf"
    if [ -f "$template_file" ]; then
        backup_config
        cp "$template_file" "$NGINX_CONF"
        echo "已使用模板覆盖nginx.conf"
    else
        echo "错误: 模板文件不存在: $template_file"
        exit 1
    fi
}

# 修改proxy_pass IP
change_proxy_ip() {
    local new_ip="$1"
    
    if [ -z "$new_ip" ]; then
        echo "错误: 请提供IP地址"
        exit 1
    fi
    
    # 验证IP格式
    if ! echo "$new_ip" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
        echo "错误: IP地址格式无效: $new_ip"
        exit 1
    fi
    
    if [ -f "$NGINX_CONF" ]; then
        # 使用sed替换proxy_pass后的IP地址
        sed -i "s|proxy_pass http://[0-9.]*;|proxy_pass http://${new_ip};|g" "$NGINX_CONF"
        echo "已将proxy_pass IP修改为: $new_ip"
    else
        echo "错误: 配置文件不存在: $NGINX_CONF"
        exit 1
    fi
}

# 重启Nginx
restart_nginx() {
    echo "正在重启Nginx..."
    service nginxd stop
    sleep 1
    service nginxd start
    echo "Nginx已重启"
}

# 主程序
main() {
    local do_backup=0
    local do_template=0
    local do_restart=0
    local target_ip=""
    
    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -i|--ip)
                target_ip="$2"
                shift 2
                ;;
            -t|--template)
                do_template=1
                shift
                ;;
            -b|--backup)
                do_backup=1
                shift
                ;;
            -r|--restart)
                do_restart=1
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 如果没有参数，进入交互模式
    if [ -z "$target_ip" ] && [ $do_template -eq 0 ]; then
        echo "Nginx配置工具"
        echo "=============="
        echo ""
        echo "1. 修改proxy_pass IP地址"
        echo "2. 使用模板覆盖配置"
        echo "3. 备份配置文件"
        echo "4. 重启Nginx"
        echo "0. 退出"
        echo ""
        echo -n "请选择: "
        read choice
        
        case $choice in
            1)
                backup_config
                echo -n "请输入新的IP地址: "
                read target_ip
                change_proxy_ip "$target_ip"
                echo -n "是否重启Nginx? [y/N]: "
                read answer
                [ "$answer" = "y" ] || [ "$answer" = "Y" ] && restart_nginx
                ;;
            2)
                use_template
                echo -n "请输入proxy_pass IP地址 [默认192.168.16.254]: "
                read target_ip
                [ -z "$target_ip" ] && target_ip="192.168.16.254"
                change_proxy_ip "$target_ip"
                echo -n "是否重启Nginx? [y/N]: "
                read answer
                [ "$answer" = "y" ] || [ "$answer" = "Y" ] && restart_nginx
                ;;
            3)
                backup_config
                ;;
            4)
                restart_nginx
                ;;
            0)
                exit 0
                ;;
            *)
                echo "无效选项"
                ;;
        esac
        exit 0
    fi
    
    # 命令行模式
    [ $do_backup -eq 1 ] && backup_config
    [ $do_template -eq 1 ] && use_template
    [ -n "$target_ip" ] && change_proxy_ip "$target_ip"
    [ $do_restart -eq 1 ] && restart_nginx
}

main "$@"
