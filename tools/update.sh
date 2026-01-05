#!/bin/sh

SQLITE_BIN=/opt/sqlite/bin/sqlite3
ConfDir=/home/hy_media_server/conf

# 函数：安全读取密码
function read_password() {
    if [ -z "$DB_PASSWORD" ]; then
        echo -n "Please enter database password: "
        read -s DB_PASSWORD
        echo
        if [ -z "$DB_PASSWORD" ]; then
            echo "Error: Password cannot be empty"
            exit 1
        fi
    fi
}

function safeExecSqlFile()
{
    local node_id="$1"
    local sql_file="$2"
    
    if [ -z "$node_id" ]; then
        echo "Error: Node ID is required"
        return 1
    fi
    
    if [ -z "$sql_file" ]; then
        echo "Error: SQL file name is required"
        return 1
    fi
    
    if [ ! -f "$sql_file" ]; then
        echo "Error: SQL file '$sql_file' does not exist"
        return 1
    fi
    
    echo "Executing SQL file: $sql_file for node: $node_id"
    
    find "${ConfDir}" -type f -name "*-$node_id.db" | while read -r DB_FILE; do
        echo "Processing database: $DB_FILE"
        echo "PRAGMA key = '$DB_PASSWORD';" | cat - "$sql_file" | $SQLITE_BIN "$DB_FILE" 2>&1 | grep -v "Warning:"
        if [ $? -eq 0 ]; then
            echo "Successfully executed $sql_file on $DB_FILE"
        else
            echo "Error executing $sql_file on $DB_FILE"
        fi
    done
}

# 检查参数
if [ $# -ne 2 ]; then
    echo "Usage: $0 <node_id> <sql_file>"
    echo "Example: $0 2 update_20250709.sql"
    exit 1
fi

# 读取密码
read_password

# 执行SQL文件
safeExecSqlFile "$1" "$2"

service sie restart
