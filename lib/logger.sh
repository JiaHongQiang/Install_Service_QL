#!/bin/bash
#===============================================================================
# 日志工具库
# Logger Utility Library
#===============================================================================

# 颜色定义
LOG_RED='\033[0;31m'
LOG_GREEN='\033[0;32m'
LOG_YELLOW='\033[1;33m'
LOG_BLUE='\033[0;34m'
LOG_CYAN='\033[0;36m'
LOG_NC='\033[0m'

# 日志级别
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# 当前日志级别 (默认INFO)
CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# 获取脚本根目录
LOGGER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGGER_ROOT_DIR="$(dirname "$LOGGER_SCRIPT_DIR")"

# 日志文件路径 (放在项目根目录)
LOG_FILE="${LOG_FILE:-${LOGGER_ROOT_DIR}/install.log}"

# 获取时间戳
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# 写入日志文件
write_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(get_timestamp)
    
    # 确保日志目录存在
    local log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null
    fi
    
    # 写入日志文件
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
}

# DEBUG日志
log_debug() {
    local message="$1"
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]; then
        echo -e "${LOG_CYAN}[DEBUG]${LOG_NC} $message"
    fi
    write_log "DEBUG" "$message"
}

# INFO日志
log_info() {
    local message="$1"
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]; then
        echo -e "${LOG_GREEN}[INFO]${LOG_NC} $message"
    fi
    write_log "INFO" "$message"
}

# WARN日志
log_warn() {
    local message="$1"
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]; then
        echo -e "${LOG_YELLOW}[WARN]${LOG_NC} $message"
    fi
    write_log "WARN" "$message"
}

# ERROR日志
log_error() {
    local message="$1"
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]; then
        echo -e "${LOG_RED}[ERROR]${LOG_NC} $message"
    fi
    write_log "ERROR" "$message"
}

# 成功提示
log_success() {
    local message="$1"
    echo -e "${LOG_GREEN}[SUCCESS]${LOG_NC} $message"
    write_log "SUCCESS" "$message"
}

# 步骤提示
log_step() {
    local step="$1"
    local message="$2"
    echo -e "${LOG_BLUE}[步骤 $step]${LOG_NC} $message"
    write_log "STEP $step" "$message"
}

# 分隔线
log_separator() {
    echo "==============================================================================="
}

# 标题
log_title() {
    local title="$1"
    log_separator
    echo -e "${LOG_BLUE}  $title${LOG_NC}"
    log_separator
}
