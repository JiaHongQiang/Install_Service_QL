#!/bin/sh

NodeID=$1
VERIFY_CERT=$2
PASSWORD=$3
P12_FILE=$4

source ./safeExec.sh

if [[ ${NodeID} == '' ]] || [[ ${VERIFY_CERT} == '' ]] || [[ ${PASSWORD} == '' ]] || [[ ${P12_FILE} == '' ]] ; then
    echo "Parameters are invalid, format: <NodeID>,<VERIFY_CERT>,<PASSWORD>,<P12_FILE>"
    echo "please input like this addTlsConnectConfig.sh 2 1 mypassword /path/to/cert.p12"
    exit
fi

echo "TLS Configuration Script - Node ID:${NodeID}, Verify Cert:${VERIFY_CERT}, Password:${PASSWORD}, P12 File:${P12_FILE}"

# 提示用户输入数据库密码
# 提示用户输入数据库密码
if [ -z "$DB_PASSWORD" ]; then
    echo -n "Please enter database password: "
    read -s DB_PASSWORD
    echo
    if [ -z "$DB_PASSWORD" ]; then
        echo "Error: Password cannot be empty"
        exit 1
    fi
fi

# 导出密码变量，供 safeExec.sh 中的函数使用
export DB_PASSWORD

service sie stop

# IP地址验证函数
validate_ip() {
    local ip=$1
    if [[ -z "${ip}" ]]; then
        echo "Error: IP address cannot be empty. Please enter a valid IP address."
        return 1
    elif [[ ${ip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # 验证IP地址格式和范围
        IFS='.' read -ra ADDR <<< "${ip}"
        local valid=true
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                valid=false
                break
            fi
        done
        if [[ $valid == true ]]; then
            return 0
        else
            echo "Error: Invalid IP address format. Please enter a valid IP address (0-255 for each octet)."
            return 1
        fi
    else
        echo "Error: Invalid IP address format. Please enter a valid IP address."
        return 1
    fi
}

# 端口验证函数
validate_port() {
    local port=$1
    if [[ -z "${port}" ]]; then
        echo "Error: Port cannot be empty. Please enter a valid port number."
        return 1
    elif [[ ${port} =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
        return 0
    else
        echo "Error: Invalid port number. Please enter a valid port (1-65535)."
        return 1
    fi
}

# 显示菜单
show_menu() {
    echo "========================================="
    echo "           TLS Configuration Menu"
    echo "========================================="
    echo "1. Configure 666 TLS CONNECT TABLE T_TLS_CONNECTION"
    echo "2. Configure RTSP TLS LISTEN TABLE T_CMG_TLS_LISTEN"
    echo "3. Configure RTSP TLS CONNECT TABLE T_CMG_TLS_CONNECT"
    echo "4. Configure All Tables"
    echo "5. Exit"
    echo "========================================="
}

# 配置 T_TLS_CONNECTION
configure_tls_connection() {
    echo "Configuring  666 TLS CONNECT TABLE T_TLS_CONNECTION..."
    
    # 检查表是否存在，不存在则创建
    echo "Checking if table T_TLS_CONNECTION exists..."
    TABLE_EXISTS=$(safeExecsql $NodeID "SELECT name FROM sqlite_master WHERE type='table' AND name='T_TLS_CONNECTION';" | grep -c "T_TLS_CONNECTION")

    if [ "$TABLE_EXISTS" -eq 0 ]; then
        echo "Table T_TLS_CONNECTION does not exist. Creating table..."
        safeExecsql $NodeID "CREATE TABLE T_TLS_CONNECTION
        (
            ID                      INTEGER PRIMARY KEY AUTOINCREMENT, -- 自增ID, 唯一标识
            NODE_TYPE               INTEGER NOT NULL,
            NODE_ID                 INTEGER NOT NULL,
            CONNECT_NODE_TYPE       INTEGER NOT NULL,
            CONNECT_NODE_ID         INTEGER NOT NULL,
            IP_ADDR                 VARCHAR(32) NOT NULL, -- 远端连接地址
            PORT                    INTEGER NOT NULL,
            VERIFY_CERT             INTEGER DEFAULT 0, -- 是否校验证书，0：不校验 1：校验
            PASSWORD                VARCHAR(32) NOT NULL, -- 密码
            P12_FILE                VARCHAR(1024) NOT NULL,
            UNIQUE(NODE_TYPE, NODE_ID, CONNECT_NODE_TYPE, CONNECT_NODE_ID)
        );"
        
        if [ $? -eq 0 ]; then
            echo "Successfully created table T_TLS_CONNECTION"
        else
            echo "Error: Failed to create table T_TLS_CONNECTION"
            return 1
        fi
    else
        echo "Table T_TLS_CONNECTION already exists"
    fi

    # 提示用户输入IP地址和端口
    while true; do
        read -p "Enter Main Node IP address: " IP_ADDR
        if validate_ip "${IP_ADDR}"; then
            break
        fi
    done

    while true; do
        read -p "Enter port (default: 6661): " PORT
        PORT=${PORT:-6661}
        if validate_port "${PORT}"; then
            break
        fi
    done

    # 删除现有配置
    safeExecsql $NodeID "delete from T_TLS_CONNECTION where NODE_ID = '${NodeID}' AND CONNECT_NODE_TYPE = 666 AND CONNECT_NODE_ID = 1;"

    # 插入第一条数据 (NODE_TYPE = 888)
    safeExecsql $NodeID "insert into T_TLS_CONNECTION(NODE_TYPE, NODE_ID, CONNECT_NODE_TYPE, CONNECT_NODE_ID, IP_ADDR, PORT, VERIFY_CERT, PASSWORD, P12_FILE) VALUES(888, ${NodeID}, 666, 1, '${IP_ADDR}', ${PORT}, ${VERIFY_CERT}, '${PASSWORD}', '${P12_FILE}');"

    # 插入第二条数据 (NODE_TYPE = 999)
    safeExecsql $NodeID "insert into T_TLS_CONNECTION(NODE_TYPE, NODE_ID, CONNECT_NODE_TYPE, CONNECT_NODE_ID, IP_ADDR, PORT, VERIFY_CERT, PASSWORD, P12_FILE) VALUES(999, ${NodeID}, 666, 1, '${IP_ADDR}', ${PORT}, ${VERIFY_CERT}, '${PASSWORD}', '${P12_FILE}');"

    echo "T_TLS_CONNECTION configuration completed!"
}

# 配置 T_CMG_TLS_LISTEN
configure_cmg_tls_listen() {
    echo "Configuring RTSP TLS LISTEN TABLE T_CMG_TLS_LISTEN..."
    
    # 检查表是否存在，不存在则创建
    echo "Checking if table T_CMG_TLS_LISTEN exists..."
    TABLE_EXISTS=$(safeExecsql $NodeID "SELECT name FROM sqlite_master WHERE type='table' AND name='T_CMG_TLS_LISTEN';" | grep -c "T_CMG_TLS_LISTEN")

    if [ "$TABLE_EXISTS" -eq 0 ]; then
        echo "Table T_CMG_TLS_LISTEN does not exist. Creating table..."
        safeExecsql $NodeID "CREATE TABLE T_CMG_TLS_LISTEN (
            ID                      INTEGER PRIMARY KEY AUTOINCREMENT,  -- 自增ID, 唯一标识
            NODE_ID                 INTEGER NOT NULL,                   -- 节点编号（主键）
            CONTAINER_ID            INTEGER NOT NULL,                   -- 容器编号（主键）
            CMG_TLS_LISTEN_IPADDR   TEXT NOT NULL,                     -- 媒体网关监听地址
            CMG_TLS_LISTEN_PORT     INTEGER NOT NULL,                  -- 媒体网关监听端口
            CMG_TLS_LISTEN_TYPE     INTEGER DEFAULT 1,                 -- TLS监听类型, 1:rtsp
            USER_SERVER_CERT        INTEGER DEFAULT 0,                 -- 是否用服务端默认证书（和HYP服务端一致）
            VERIFY_CERT             INTEGER DEFAULT 0,                 -- 是否校验证书，0：不校验 1：校验
            PASSWORD                TEXT DEFAULT NULL,                 -- 密码
            P12_FILE                TEXT DEFAULT NULL                  -- P12文件路径
        );"
        
        if [ $? -eq 0 ]; then
            echo "Successfully created table T_CMG_TLS_LISTEN"
        else
            echo "Error: Failed to create table T_CMG_TLS_LISTEN"
            return 1
        fi
    else
        echo "Table T_CMG_TLS_LISTEN already exists"
    fi

    # 提示用户输入参数
    CONTAINER_ID=1
    
    while true; do
        read -p "Enter CMG TLS Listen IP Address: " CMG_TLS_LISTEN_IPADDR
        if validate_ip "${CMG_TLS_LISTEN_IPADDR}"; then
            break
        fi
    done

    while true; do
        read -p "Enter CMG TLS Listen Port (default: 8554): " CMG_TLS_LISTEN_PORT
        CMG_TLS_LISTEN_PORT=${CMG_TLS_LISTEN_PORT:-8554}
        if validate_port "${CMG_TLS_LISTEN_PORT}"; then
            break
        fi
    done

    CMG_TLS_LISTEN_TYPE=1
    USER_SERVER_CERT=0

    # 删除现有配置（如果需要）
    safeExecsql $NodeID "DELETE FROM T_CMG_TLS_LISTEN WHERE NODE_ID = ${NodeID} AND CONTAINER_ID = ${CONTAINER_ID};"

    # 插入数据
    safeExecsql $NodeID "INSERT INTO T_CMG_TLS_LISTEN(NODE_ID, CONTAINER_ID, CMG_TLS_LISTEN_IPADDR, CMG_TLS_LISTEN_PORT, CMG_TLS_LISTEN_TYPE, USER_SERVER_CERT, VERIFY_CERT, PASSWORD, P12_FILE) VALUES(${NodeID}, ${CONTAINER_ID}, '${CMG_TLS_LISTEN_IPADDR}', ${CMG_TLS_LISTEN_PORT}, ${CMG_TLS_LISTEN_TYPE}, ${USER_SERVER_CERT}, ${VERIFY_CERT}, '${PASSWORD}', '${P12_FILE}');"

    echo "T_CMG_TLS_LISTEN configuration completed!"
}

# 配置 T_CMG_TLS_CONNECT
configure_cmg_tls_connect() {
    echo "Configuring RTSP TLS CONNECT TABLE T_CMG_TLS_CONNECT..."
    
    # 检查表是否存在，不存在则创建
    echo "Checking if table T_CMG_TLS_CONNECT exists..."
    TABLE_EXISTS=$(safeExecsql $NodeID "SELECT name FROM sqlite_master WHERE type='table' AND name='T_CMG_TLS_CONNECT';" | grep -c "T_CMG_TLS_CONNECT")

    if [ "$TABLE_EXISTS" -eq 0 ]; then
        echo "Table T_CMG_TLS_CONNECT does not exist. Creating table..."
        safeExecsql $NodeID "CREATE TABLE T_CMG_TLS_CONNECT (
            ID                      INTEGER PRIMARY KEY AUTOINCREMENT,  -- 自增ID, 唯一标识
            CMG_CONNECT_TCP_IPADDR  TEXT NOT NULL,                     -- 连接的Rtsp Tcp地址
            CMG_CONNECT_TCP_PORT    INTEGER NOT NULL,                  -- 连接的Rtsp Tcp端口
            CMG_CONNECT_TLS_IPADDR  TEXT NOT NULL,                     -- 连接的Rtsp Tls地址
            CMG_CONNECT_TLS_PORT    INTEGER NOT NULL,                  -- 连接的Rtsp Tls端口
            USER_SERVER_CERT        INTEGER DEFAULT 0,                 -- 是否用服务端默认证书（和HYP服务端一致）
            VERIFY_CERT             INTEGER DEFAULT 0,                 -- 是否校验证书，0：不校验 1：校验
            PASSWORD                TEXT DEFAULT NULL,                 -- 密码
            P12_FILE                TEXT DEFAULT NULL                  -- P12文件路径
        );"
        
        if [ $? -eq 0 ]; then
            echo "Successfully created table T_CMG_TLS_CONNECT"
        else
            echo "Error: Failed to create table T_CMG_TLS_CONNECT"
            return 1
        fi
    else
        echo "Table T_CMG_TLS_CONNECT already exists"
    fi

    # 提示用户输入参数
    while true; do
        read -p "Enter CMG Connect TCP IP Address: " CMG_CONNECT_TCP_IPADDR
        if validate_ip "${CMG_CONNECT_TCP_IPADDR}"; then
            break
        fi
    done

    while true; do
        read -p "Enter CMG Connect TCP Port (default: 1554): " CMG_CONNECT_TCP_PORT
        CMG_CONNECT_TCP_PORT=${CMG_CONNECT_TCP_PORT:-1554}
        if validate_port "${CMG_CONNECT_TCP_PORT}"; then
            break
        fi
    done

    while true; do
        read -p "Enter CMG Connect TLS IP Address: " CMG_CONNECT_TLS_IPADDR
        if validate_ip "${CMG_CONNECT_TLS_IPADDR}"; then
            break
        fi
    done

    while true; do
        read -p "Enter CMG Connect TLS Port (default: 8554): " CMG_CONNECT_TLS_PORT
        CMG_CONNECT_TLS_PORT=${CMG_CONNECT_TLS_PORT:-8554}
        if validate_port "${CMG_CONNECT_TLS_PORT}"; then
            break
        fi
    done

    USER_SERVER_CERT=0

    # 删除现有配置（如果需要）
    safeExecsql $NodeID "DELETE FROM T_CMG_TLS_CONNECT WHERE CMG_CONNECT_TCP_IPADDR = '${CMG_CONNECT_TCP_IPADDR}' AND CMG_CONNECT_TCP_PORT = ${CMG_CONNECT_TCP_PORT};"

    # 插入数据
    safeExecsql $NodeID "INSERT INTO T_CMG_TLS_CONNECT(CMG_CONNECT_TCP_IPADDR, CMG_CONNECT_TCP_PORT, CMG_CONNECT_TLS_IPADDR, CMG_CONNECT_TLS_PORT, USER_SERVER_CERT, VERIFY_CERT, PASSWORD, P12_FILE) VALUES('${CMG_CONNECT_TCP_IPADDR}', ${CMG_CONNECT_TCP_PORT}, '${CMG_CONNECT_TLS_IPADDR}', ${CMG_CONNECT_TLS_PORT}, ${USER_SERVER_CERT}, ${VERIFY_CERT}, '${PASSWORD}', '${P12_FILE}');"

    echo "T_CMG_TLS_CONNECT configuration completed!"
}

# 设置P12文件权限
set_p12_permissions() {
    # 检查 /home/hy_media_server 的用户和用户组所属
    if [ -d "/home/hy_media_server" ]; then
        OWNER_INFO=$(stat -c "%U:%G" /home/hy_media_server)
        OWNER_USER=$(echo $OWNER_INFO | cut -d':' -f1)
        OWNER_GROUP=$(echo $OWNER_INFO | cut -d':' -f2)
        
        echo "Found /home/hy_media_server owned by: ${OWNER_USER}:${OWNER_GROUP}"
        
        # 检查 P12_FILE 是否存在并设置相同的用户和用户组
        if [ -f "${P12_FILE}" ]; then
            echo "Setting ownership of ${P12_FILE} to ${OWNER_USER}:${OWNER_GROUP}"
            chown ${OWNER_USER}:${OWNER_GROUP} "${P12_FILE}"
            if [ $? -eq 0 ]; then
                echo "Successfully changed ownership of ${P12_FILE}"
            else
                echo "Warning: Failed to change ownership of ${P12_FILE}"
            fi
        else
            echo "Warning: P12 file ${P12_FILE} does not exist"
        fi
    else
        echo "Warning: /home/hy_media_server directory does not exist"
    fi
}

# 配置所有表
configure_all_tables() {
    echo "Configuring all TLS tables..."
    echo
    
    # 配置 T_TLS_CONNECTION
    configure_tls_connection
    if [ $? -ne 0 ]; then
        echo "Error: Failed to configure T_TLS_CONNECTION"
        return 1
    fi
    
    echo
    echo "----------------------------------------"
    echo
    
    # 配置 T_CMG_TLS_LISTEN
    configure_cmg_tls_listen
    if [ $? -ne 0 ]; then
        echo "Error: Failed to configure T_CMG_TLS_LISTEN"
        return 1
    fi
    
    echo
    echo "----------------------------------------"
    echo
    
    # 配置 T_CMG_TLS_CONNECT
    configure_cmg_tls_connect
    if [ $? -ne 0 ]; then
        echo "Error: Failed to configure T_CMG_TLS_CONNECT"
        return 1
    fi
    
    echo
    echo "All TLS tables configured successfully!"
}

# 主循环
if [ "$5" = "auto" ]; then
    echo "Auto mode detected. Configuring TLS Connection..."
    # 使用配置的TLS连接IP，若为空则使用MAIN_IP
    if [ -n "$TLS_CONNECT_IP" ]; then
        IP_ADDR=$TLS_CONNECT_IP
    elif [ -n "$MAIN_IP" ]; then
        IP_ADDR=$MAIN_IP
    else
        echo "Error: TLS_CONNECT_IP or MAIN_IP is required for auto mode"
        exit 1
    fi
    # 使用配置的端口，默认6661
    PORT=${TLS_CONNECT_PORT:-6661}
    
    # 检查表是否存在，不存在则创建
    echo "Checking if table T_TLS_CONNECTION exists..."
    TABLE_EXISTS=$(safeExecsql $NodeID "SELECT name FROM sqlite_master WHERE type='table' AND name='T_TLS_CONNECTION';" | grep -c "T_TLS_CONNECTION")

    if [ "$TABLE_EXISTS" -eq 0 ]; then
        echo "Table T_TLS_CONNECTION does not exist. Creating table..."
        safeExecsql $NodeID "CREATE TABLE T_TLS_CONNECTION
        (
            ID                      INTEGER PRIMARY KEY AUTOINCREMENT, -- 自增ID, 唯一标识
            NODE_TYPE               INTEGER NOT NULL,
            NODE_ID                 INTEGER NOT NULL,
            CONNECT_NODE_TYPE       INTEGER NOT NULL,
            CONNECT_NODE_ID         INTEGER NOT NULL,
            IP_ADDR                 VARCHAR(32) NOT NULL, -- 远端连接地址
            PORT                    INTEGER NOT NULL,
            VERIFY_CERT             INTEGER DEFAULT 0, -- 是否校验证书，0：不校验 1：校验
            PASSWORD                VARCHAR(32) NOT NULL, -- 密码
            P12_FILE                VARCHAR(1024) NOT NULL,
            UNIQUE(NODE_TYPE, NODE_ID, CONNECT_NODE_TYPE, CONNECT_NODE_ID)
        );"
    fi

    # 删除现有配置
    safeExecsql $NodeID "delete from T_TLS_CONNECTION where NODE_ID = '${NodeID}' AND CONNECT_NODE_TYPE = 666 AND CONNECT_NODE_ID = 1;"

    # 插入第一条数据 (NODE_TYPE = 888)
    safeExecsql $NodeID "insert into T_TLS_CONNECTION(NODE_TYPE, NODE_ID, CONNECT_NODE_TYPE, CONNECT_NODE_ID, IP_ADDR, PORT, VERIFY_CERT, PASSWORD, P12_FILE) VALUES(888, ${NodeID}, 666, 1, '${IP_ADDR}', ${PORT}, ${VERIFY_CERT}, '${PASSWORD}', '${P12_FILE}');"

    # 插入第二条数据 (NODE_TYPE = 999)
    safeExecsql $NodeID "insert into T_TLS_CONNECTION(NODE_TYPE, NODE_ID, CONNECT_NODE_TYPE, CONNECT_NODE_ID, IP_ADDR, PORT, VERIFY_CERT, PASSWORD, P12_FILE) VALUES(999, ${NodeID}, 666, 1, '${IP_ADDR}', ${PORT}, ${VERIFY_CERT}, '${PASSWORD}', '${P12_FILE}');"

    set_p12_permissions
    
    # 配置 T_CMG_TLS_LISTEN (RTSP TLS监听)
    if [ -n "$TLS_RTSP_LISTEN_IP" ] || [ -n "$LOCAL_IP" ]; then
        echo "Configuring T_CMG_TLS_LISTEN..."
        RTSP_LISTEN_IP=${TLS_RTSP_LISTEN_IP:-$LOCAL_IP}
        RTSP_LISTEN_PORT=${TLS_RTSP_LISTEN_PORT:-8554}
        
        # 检查表是否存在
        TABLE_EXISTS=$(safeExecsql $NodeID "SELECT name FROM sqlite_master WHERE type='table' AND name='T_CMG_TLS_LISTEN';" | grep -c "T_CMG_TLS_LISTEN")
        if [ "$TABLE_EXISTS" -eq 0 ]; then
            safeExecsql $NodeID "CREATE TABLE T_CMG_TLS_LISTEN (
                ID INTEGER PRIMARY KEY AUTOINCREMENT,
                NODE_ID INTEGER NOT NULL,
                CONTAINER_ID INTEGER NOT NULL,
                CMG_TLS_LISTEN_IPADDR TEXT NOT NULL,
                CMG_TLS_LISTEN_PORT INTEGER NOT NULL,
                CMG_TLS_LISTEN_TYPE INTEGER DEFAULT 1,
                USER_SERVER_CERT INTEGER DEFAULT 0,
                VERIFY_CERT INTEGER DEFAULT 0,
                PASSWORD TEXT DEFAULT NULL,
                P12_FILE TEXT DEFAULT NULL
            );"
        fi
        
        safeExecsql $NodeID "DELETE FROM T_CMG_TLS_LISTEN WHERE NODE_ID = ${NodeID} AND CONTAINER_ID = 1;"
        safeExecsql $NodeID "INSERT INTO T_CMG_TLS_LISTEN(NODE_ID, CONTAINER_ID, CMG_TLS_LISTEN_IPADDR, CMG_TLS_LISTEN_PORT, CMG_TLS_LISTEN_TYPE, USER_SERVER_CERT, VERIFY_CERT, PASSWORD, P12_FILE) VALUES(${NodeID}, 1, '${RTSP_LISTEN_IP}', ${RTSP_LISTEN_PORT}, 1, 0, ${VERIFY_CERT}, '${PASSWORD}', '${P12_FILE}');"
        echo "T_CMG_TLS_LISTEN configured."
    fi
    
    # 配置 T_CMG_TLS_CONNECT (RTSP TLS连接)
    if [ -n "$TLS_RTSP_CONNECT_IP" ] || [ -n "$MAIN_IP" ]; then
        echo "Configuring T_CMG_TLS_CONNECT..."
        RTSP_CONNECT_IP=${TLS_RTSP_CONNECT_IP:-$MAIN_IP}
        RTSP_TCP_PORT=${TLS_RTSP_TCP_PORT:-1554}
        RTSP_TLS_PORT=${TLS_RTSP_TLS_PORT:-8554}
        
        # 检查表是否存在
        TABLE_EXISTS=$(safeExecsql $NodeID "SELECT name FROM sqlite_master WHERE type='table' AND name='T_CMG_TLS_CONNECT';" | grep -c "T_CMG_TLS_CONNECT")
        if [ "$TABLE_EXISTS" -eq 0 ]; then
            safeExecsql $NodeID "CREATE TABLE T_CMG_TLS_CONNECT (
                ID INTEGER PRIMARY KEY AUTOINCREMENT,
                CMG_CONNECT_TCP_IPADDR TEXT NOT NULL,
                CMG_CONNECT_TCP_PORT INTEGER NOT NULL,
                CMG_CONNECT_TLS_IPADDR TEXT NOT NULL,
                CMG_CONNECT_TLS_PORT INTEGER NOT NULL,
                USER_SERVER_CERT INTEGER DEFAULT 0,
                VERIFY_CERT INTEGER DEFAULT 0,
                PASSWORD TEXT DEFAULT NULL,
                P12_FILE TEXT DEFAULT NULL
            );"
        fi
        
        safeExecsql $NodeID "DELETE FROM T_CMG_TLS_CONNECT WHERE CMG_CONNECT_TCP_IPADDR = '${RTSP_CONNECT_IP}' AND CMG_CONNECT_TCP_PORT = ${RTSP_TCP_PORT};"
        safeExecsql $NodeID "INSERT INTO T_CMG_TLS_CONNECT(CMG_CONNECT_TCP_IPADDR, CMG_CONNECT_TCP_PORT, CMG_CONNECT_TLS_IPADDR, CMG_CONNECT_TLS_PORT, USER_SERVER_CERT, VERIFY_CERT, PASSWORD, P12_FILE) VALUES('${RTSP_CONNECT_IP}', ${RTSP_TCP_PORT}, '${RTSP_CONNECT_IP}', ${RTSP_TLS_PORT}, 0, ${VERIFY_CERT}, '${PASSWORD}', '${P12_FILE}');"
        echo "T_CMG_TLS_CONNECT configured."
    fi
    
    echo "Auto configuration completed!"
    
    echo "restart sie"
    service sie restart
    exit 0
fi

while true; do
    show_menu
    echo -n "Please select an option (1-5): "
    read choice
    
    case $choice in
        1)
            configure_tls_connection
            set_p12_permissions
            ;;
        2)
            configure_cmg_tls_listen
            set_p12_permissions
            ;;
        3)
            configure_cmg_tls_connect
            set_p12_permissions
            ;;
        4)
            configure_all_tables
            set_p12_permissions
            ;;
        5)
            echo "Exiting..."
            break
            ;;
        *)
            echo "Invalid option. Please select 1-5."
            ;;
    esac
    
    echo
    echo "Press Enter to continue..."
    read
done

echo "restart sie"
service sie restart

echo "done!"
