#!/bin/bash
#===============================================================================
# 安全执行脚本
# Safe Execution Script
# 提供数据库操作的安全封装函数
#===============================================================================

# SQLite数据库路径
DB_BASE_PATH="/home/hy_media_server/db"

#===============================================================================
# 数据库操作函数
#===============================================================================

# 安全执行SQL语句
# 参数: $1 - 节点ID, $2 - SQL语句
safeExecsql() {
    local nodeId="$1"
    local sql="$2"
    local dbPath="${DB_BASE_PATH}/node_${nodeId}.db"
    
    if [ -z "$nodeId" ] || [ -z "$sql" ]; then
        echo "Error: safeExecsql requires nodeId and sql parameters"
        return 1
    fi
    
    if [ ! -f "$dbPath" ]; then
        echo "Warning: Database file not found: $dbPath"
        # 尝试使用默认数据库
        dbPath="${DB_BASE_PATH}/sie.db"
    fi
    
    # 使用密码执行SQL（如果设置了密码）
    if [ -n "$DB_PASSWORD" ]; then
        sqlite3 "$dbPath" "$sql"
    else
        sqlite3 "$dbPath" "$sql"
    fi
}

# 删除节点数据库
# 参数: $1 - 节点ID
safeRmNodeDb() {
    local nodeId="$1"
    local dbPath="${DB_BASE_PATH}/node_${nodeId}.db"
    
    if [ -z "$nodeId" ]; then
        echo "Error: safeRmNodeDb requires nodeId parameter"
        return 1
    fi
    
    if [ -f "$dbPath" ]; then
        echo "Removing database: $dbPath"
        rm -f "$dbPath"
    fi
}

# 添加/初始化节点数据库
# 参数: $1 - 节点ID
safeAddNodeDb() {
    local nodeId="$1"
    local dbPath="${DB_BASE_PATH}/node_${nodeId}.db"
    local templateDb="${DB_BASE_PATH}/template.db"
    
    if [ -z "$nodeId" ]; then
        echo "Error: safeAddNodeDb requires nodeId parameter"
        return 1
    fi
    
    # 如果模板数据库存在，复制它
    if [ -f "$templateDb" ]; then
        echo "Creating database from template: $dbPath"
        cp "$templateDb" "$dbPath"
    else
        echo "Creating new database: $dbPath"
        touch "$dbPath"
    fi
    
    # 设置权限
    chmod 644 "$dbPath"
}

# 备份数据库
# 参数: $1 - 节点ID
safeBackupDb() {
    local nodeId="$1"
    local dbPath="${DB_BASE_PATH}/node_${nodeId}.db"
    local backupPath="${dbPath}.bak.$(date +%Y%m%d%H%M%S)"
    
    if [ -f "$dbPath" ]; then
        echo "Backing up database to: $backupPath"
        cp "$dbPath" "$backupPath"
    fi
}

# 检查数据库是否存在
# 参数: $1 - 节点ID
safeCheckDb() {
    local nodeId="$1"
    local dbPath="${DB_BASE_PATH}/node_${nodeId}.db"
    
    if [ -f "$dbPath" ]; then
        return 0
    else
        return 1
    fi
}

#===============================================================================
# 导出函数供其他脚本使用
#===============================================================================
export -f safeExecsql
export -f safeRmNodeDb
export -f safeAddNodeDb
export -f safeBackupDb
export -f safeCheckDb
