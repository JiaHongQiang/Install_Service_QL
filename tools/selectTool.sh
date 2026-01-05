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

function queryTable()
{
    local node_id="$1"
    local table_name="$2"
    
    if [ -z "$node_id" ]; then
        echo "Error: Node ID is required"
        return 1
    fi
    
    if [ -z "$table_name" ]; then
        echo "Error: Table name is required"
        return 1
    fi
    
    echo "Querying table: $table_name from node: $node_id"
    echo "========================================"
    
    # 找到第一个匹配的数据库文件
    DB_FILE=$(find "${ConfDir}" -type f -name "*-$node_id.db" | head -1)
    
    if [ -z "$DB_FILE" ]; then
        echo "Error: No database found for node: $node_id"
        return 1
    fi
    
    echo "Database: $DB_FILE"
    echo "----------------------------------------"
    
    # 检查表是否存在
    table_exists=$(echo "PRAGMA key = '$DB_PASSWORD'; SELECT name FROM sqlite_master WHERE type='table' AND name='$table_name';" | $SQLITE_BIN "$DB_FILE" 2>/dev/null)
    
    if [ -z "$table_exists" ]; then
        echo "Table '$table_name' does not exist in this database"
    else
        # 查询表数据
        echo "PRAGMA key = '$DB_PASSWORD'; SELECT * FROM $table_name;" | $SQLITE_BIN "$DB_FILE" 2>&1 | grep -v "Warning:"
    fi
    echo "----------------------------------------"
}

# 检查参数
if [ $# -ne 2 ]; then
    echo "Usage: $0 <node_id> <table_name>"
    echo "Example: $0 2 user_table"
    exit 1
fi

# 读取密码
read_password

# 查询表数据
queryTable "$1" "$2"
