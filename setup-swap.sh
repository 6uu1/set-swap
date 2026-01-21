#!/bin/bash

#############################################
# VPS Swap 自动配置脚本
# 用途: 在Linux VPS上创建和配置swap文件
# 作者: Auto-generated
# 日期: 2026-01-21
#############################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 默认配置
SWAP_SIZE=""             # swap大小 (为空时自动计算为内存的1倍)
SWAPPINESS=10            # 默认swappiness值 (0-100, 越小越少使用swap)
CACHE_PRESSURE=50        # 默认cache pressure值
SWAP_FILE="/swapfile"    # swap文件路径
INTERACTIVE_MODE=false   # 交互模式

# 显示使用说明
show_usage() {
    cat << EOF
使用方法: $0 [选项]

选项:
    -s, --size SIZE         Swap文件大小 (例如: 2G, 4G, 512M)
                           默认: 自动 (内存的1倍)
    -w, --swappiness VALUE  Swappiness值 (0-100)
                           默认: 10 (推荐服务器使用)
    -c, --cache VALUE       Cache pressure值 (0-100)
                           默认: 50
    -f, --file PATH         Swap文件路径
                           默认: /swapfile
    -i, --interactive       交互式菜单模式
    -r, --remove            删除现有swap
    -h, --help             显示此帮助信息

示例: (内存的1倍)
    $0 -i                   # 交互式菜单模式
    $0                      # 使用默认配置创建2G swap
    $0 -s 4G                # 创建4G swap
    $0 -s 2G -w 20          # 创建2G swap并设置swappiness为20
    $0 -r                   # 删除现有swap

EOF
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        log_info "尝试: sudo $0 $@"
        exit 1
    fi
}

# 检查现有swap
check_existing_swap() {
    log_info "检查现有swap配置..."
    
    # 显示当前swap状态
    if [ -f /proc/swaps ]; then
        local swap_count=$(grep -c "^/" /proc/swaps 2>/dev/null || true)
        if [ "$swap_count" -gt 0 ]; then
            log_warn "发现现有swap:"
            swapon --show
            return 0
        fi
    fi
    
    log_info "当前系统没有配置swap"
    return 1
}

# 删除现有swap
remove_swap() {
    log_info "开始删除swap..."
    
    # 获取所有swap文件
    local swap_files=$(swapon --show=NAME --noheadings 2>/dev/null || true)
    
    if [ -z "$swap_files" ]; then
        log_info "没有找到活动的swap"
        return 0
    fi
    
    # 关闭所有swap
    log_info "关闭所有swap设备..."
    swapoff -a
    
    # 删除swap文件
    for swap_file in $swap_files; do
        if [ -f "$swap_file" ]; then
            log_info "删除swap文件: $swap_file"
            rm -f "$swap_file"
        fi
    done
    
    # 从fstab中删除swap条目
    if [ -f /etc/fstab ]; then
        log_info "从/etc/fstab中删除swap条目..."
        sed -i.bak '/swap/d' /etc/fstab
    fi
    
    # 从sysctl.conf中删除swap相关配置
    if [ -f /etc/sysctl.conf ]; then
        log_info "从/etc/sysctl.conf中删除swap配置..."
        sed -i.bak '/vm.swappiness/d; /vm.vfs_cache_pressure/d' /etc/sysctl.conf
    fi
    
    log_info "Swap已成功删除"
}

# 转换大小为MB
size_to_mb() {
    local size=$1
    local number=$(echo $size | sed 's/[^0-9]//g')
    local unit=$(echo $size | sed 's/[0-9]//g' | tr '[:lower:]' '[:upper:]')
    
    case $unit in
        G|GB)
            echo $((number * 1024))
            ;;
        M|MB)
            echo $number
            ;;
        K|KB)
            echo $((number / 1024))
            ;;
        *)
            log_error "无效的大小单位: $unit (使用 G, M, 或 K)"
            exit 1
            ;;
    esac
}

# 检查磁盘空间
check_disk_space() {
    local required_mb=$1
    local available_mb=$(df / | awk 'NR==2 {print int($4/1024)}')
    
    log_info "需要空间: ${required_mb}MB, 可用空间: ${available_mb}MB"
    
    if [ $available_mb -lt $required_mb ]; then
        log_error "磁盘空间不足! 需要至少 ${required_mb}MB，但只有 ${available_mb}MB 可用"
        exit 1
    fi
}

# 创建swap文件
create_swap_file() {
    local size=$1
    local swap_file=$2
    
    log_info "创建swap文件: $swap_file (大小: $size)..."
    
    # 如果文件已存在，先删除
    if [ -f "$swap_file" ]; then
        log_warn "Swap文件已存在，将被覆盖"
        rm -f "$swap_file"
    fi
    
    # 尝试使用fallocate (更快)
    if command -v fallocate &> /dev/null; then
        log_info "使用fallocate创建swap文件..."
        fallocate -l "$size" "$swap_file"
    else
        # 回退到dd命令
        log_warn "fallocate不可用，使用dd命令 (这可能需要更长时间)..."
        local size_mb=$(size_to_mb "$size")
        dd if=/dev/zero of="$swap_file" bs=1M count=$size_mb status=progress
    fi
    
    # 设置正确的权限
    log_info "设置swap文件权限..."
    chmod 600 "$swap_file"
    
    log_info "Swap文件创建成功"
}

# 启用swap
enable_swap() {
    local swap_file=$1
    
    log_info "配置swap文件..."
    mkswap "$swap_file"
    
    log_info "启用swap..."
    swapon "$swap_file"
    
    log_info "Swap已成功启用"
}

# 配置永久swap
configure_persistent_swap() {
    local swap_file=$1
    
    log_info "配置开机自动挂载swap..."
    
    # 检查fstab中是否已有该条目
    if ! grep -q "$swap_file" /etc/fstab; then
        echo "$swap_file none swap sw 0 0" >> /etc/fstab
        log_info "已添加到/etc/fstab"
    else
        log_warn "/etc/fstab中已存在该swap条目"
    fi
}

# 优化swap参数
optimize_swap_parameters() {
    local swappiness=$1
    local cache_pressure=$2
    
    log_info "优化swap参数..."
    
    # 立即应用
    sysctl vm.swappiness=$swappiness
    sysctl vm.vfs_cache_pressure=$cache_pressure
    
    # 永久保存
    log_info "保存到/etc/sysctl.conf..."
    
    # 先删除旧的配置
    sed -i.bak '/vm.swappiness/d; /vm.vfs_cache_pressure/d' /etc/sysctl.conf 2>/dev/null || true
    
    # 添加新配置
    cat >> /etc/sysctl.conf << EOF

# Swap优化配置 (由setup-swap.sh添加)
vm.swappiness=$swappiness
vm.vfs_cache_pressure=$cache_pressure
EOF
    
    log_info "Swap参数已优化:"
    log_info "  - swappiness: $swappiness (值越小越倾向使用物理内存)"
    log_info "  - cache_pressure: $cache_pressure (值越小越保留目录和inode缓存)"
}

# 显示swap状态
show_swap_status() {
    log_info "当前swap状态:"
    echo "================================"
    swapon --show
    echo ""
    free -h
    echo "================================"
    
    log_info "系统参数:"
    echo "  - vm.swappiness = $(sysctl -n vm.swappiness)"
    echo "  - vm.vfs_cache_pressure = $(sysctl -n vm.vfs_cache_pressure)"
}

# 获取系统内存大小(MB)
get_total_memory_mb() {
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    echo $((mem_kb / 1024))
}

# 计算推荐的swap大小
calculate_recommended_swap() {
    local mem_mb=$(get_total_memory_mb)
    
    # 默认为内存的1倍
    echo "${mem_mb}M"
}

# 交互式菜单
interactive_menu() {
    clear
    echo "========================================"
    echo "     VPS Swap 配置脚本 - 交互模式"
    echo "========================================"
    echo ""
    
    # 显示系统信息
    local mem_mb=$(get_total_memory_mb)
    local mem_gb=$(awk "BEGIN {printf \"%.2f\", $mem_mb/1024}")
    local recommended_swap=$(calculate_recommended_swap)
    
    log_info "系统信息:"
    local os_name=$(awk -F'"' '/^PRETTY_NAME=/{print $2}' /etc/os-release 2>/dev/null || echo "未知")
    echo "  - 操作系统: ${os_name}"
    echo "  - 内核版本: $(uname -r)"
    echo "  - 物理内存: ${mem_gb}GB (${mem_mb}MB)"
    echo "  - 推荐Swap: $recommended_swap (内存的1倍)"
    echo ""
    
    # 检查现有swap
    if check_existing_swap 2>/dev/null; then
        echo ""
    fi
    echo ""
    
    # 主菜单
    echo "请选择操作:"
    echo "  1) 使用推荐配置 (Swap=${recommended_swap}, Swappiness=10)"
    echo "  2) 自定义Swap大小"
    echo "  3) 完全自定义配置"
    echo "  4) 删除现有Swap"
    echo "  5) 查看当前Swap状态"
    echo "  0) 退出"
    echo ""
    
    read -p "请输入选项 [1]: " choice
    choice=${choice:-1}  # 默认选项1
    
    case $choice in
        1)
            SWAP_SIZE=$recommended_swap
            SWAPPINESS=10
            CACHE_PRESSURE=50
            log_info "已选择推荐配置"
            echo ""
            confirm_and_execute
            ;;
        2)
            custom_swap_size
            ;;
        3)
            full_custom_config
            ;;
        4)
            confirm_remove_swap
            ;;
        5)
            show_current_swap_status
            ;;
        0)
            log_info "退出脚本"
            exit 0
            ;;
        *)
            log_error "无效选项"
            sleep 2
            interactive_menu
            ;;
    esac
}

# 自定义swap大小
custom_swap_size() {
    echo ""
    echo "========================================"
    echo "     自定义 Swap 大小"
    echo "========================================"
    echo ""
    
    local mem_mb=$(get_total_memory_mb)
    local recommended_swap=$(calculate_recommended_swap)
    
    echo "推荐大小: $recommended_swap (内存的1倍)"
    echo ""
    echo "常见选项:"
    echo "  1) 512M  (适合小内存VPS)"
    echo "  2) 1G    (适合1GB内存)"
    echo "  3) 2G    (适合2GB内存)"
    echo "  4) 4G    (适合4GB内存)"
    echo "  5) ${recommended_swap} (推荐，内存的1倍)"
    echo "  6) 自定义输入"
    echo ""
    
    read -p "请选择 [5]: " size_choice
    size_choice=${size_choice:-5}
    
    case $size_choice in
        1) SWAP_SIZE="512M" ;;
        2) SWAP_SIZE="1G" ;;
        3) SWAP_SIZE="2G" ;;
        4) SWAP_SIZE="4G" ;;
        5) SWAP_SIZE=$recommended_swap ;;
        6)
            read -p "请输入Swap大小 (如: 3G, 1536M): " custom_size
            if [ -z "$custom_size" ]; then
                log_error "大小不能为空"
                sleep 2
                custom_swap_size
                return
            fi
            SWAP_SIZE=$custom_size
            ;;
        *)
            log_error "无效选项"
            sleep 2
            custom_swap_size
            return
            ;;
    esac
    
    echo ""
    confirm_and_execute
}

# 完全自定义配置
full_custom_config() {
    echo ""
    echo "========================================"
    echo "     完全自定义配置"
    echo "========================================"
    echo ""
    
    # Swap大小
    local recommended_swap=$(calculate_recommended_swap)
    read -p "Swap大小 [$recommended_swap]: " custom_size
    SWAP_SIZE=${custom_size:-$recommended_swap}
    
    # Swappiness
    echo ""
    echo "Swappiness值 (0-100):"
    echo "  - 推荐: 10 (服务器)"
    echo "  - 说明: 值越小越少使用swap"
    read -p "Swappiness [10]: " custom_swappiness
    SWAPPINESS=${custom_swappiness:-10}
    
    # Cache Pressure
    echo ""
    echo "Cache Pressure值 (0-100):"
    echo "  - 推荐: 50 (默认)"
    read -p "Cache Pressure [50]: " custom_cache
    CACHE_PRESSURE=${custom_cache:-50}
    
    # Swap文件路径
    echo ""
    read -p "Swap文件路径 [/swapfile]: " custom_file
    SWAP_FILE=${custom_file:-/swapfile}
    
    echo ""
    confirm_and_execute
}

# 确认并执行
confirm_and_execute() {
    echo "========================================"
    echo "     配置确认"
    echo "========================================"
    echo ""
    echo "即将使用以下配置创建Swap:"
    echo "  - Swap大小: $SWAP_SIZE"
    echo "  - Swap位置: $SWAP_FILE"
    echo "  - Swappiness: $SWAPPINESS"
    echo "  - Cache Pressure: $CACHE_PRESSURE"
    echo ""
    
    # 检查磁盘空间
    local required_mb=$(size_to_mb "$SWAP_SIZE")
    local available_mb=$(df / | awk 'NR==2 {print int($4/1024)}')
    echo "  - 需要空间: ${required_mb}MB"
    echo "  - 可用空间: ${available_mb}MB"
    echo ""
    
    if [ $available_mb -lt $required_mb ]; then
        log_error "磁盘空间不足!"
        echo ""
        read -p "按Enter键返回菜单..." dummy
        interactive_menu
        return
    fi
    
    read -p "确认创建? [Y/n]: " confirm
    confirm=${confirm:-Y}
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo ""
        execute_swap_creation
    else
        log_info "已取消操作"
        sleep 1
        interactive_menu
    fi
}

# 执行swap创建
execute_swap_creation() {
    # 验证参数
    if [ "$SWAPPINESS" -lt 0 ] || [ "$SWAPPINESS" -gt 100 ]; then
        log_error "swappiness值必须在0-100之间"
        sleep 2
        interactive_menu
        return
    fi
    
    # 如果存在旧swap，先关闭
    if check_existing_swap 2>/dev/null; then
        echo ""
        log_warn "将关闭现有swap..."
        swapoff -a 2>/dev/null || true
    fi
    
    # 创建和配置swap
    create_swap_file "$SWAP_SIZE" "$SWAP_FILE"
    enable_swap "$SWAP_FILE"
    configure_persistent_swap "$SWAP_FILE"
    optimize_swap_parameters "$SWAPPINESS" "$CACHE_PRESSURE"
    
    echo ""
    log_info "✓ Swap配置完成!"
    echo ""
    
    # 显示最终状态
    show_swap_status
    
    echo ""
    log_info "提示: 重启后swap将自动挂载"
    echo ""
    read -p "按Enter键退出..." dummy
}

# 确认删除swap
confirm_remove_swap() {
    echo ""
    echo "========================================"
    echo "     删除 Swap"
    echo "========================================"
    echo ""
    
    if ! check_existing_swap 2>/dev/null; then
        echo ""
        log_info "当前没有配置swap"
        echo ""
        read -p "按Enter键返回菜单..." dummy
        interactive_menu
        return
    fi
    
    echo ""
    log_warn "警告: 这将删除所有swap配置!"
    read -p "确认删除? [y/N]: " confirm
    confirm=${confirm:-N}
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo ""
        remove_swap
        echo ""
        log_info "✓ Swap已成功删除"
        echo ""
        read -p "按Enter键返回菜单..." dummy
        interactive_menu
    else
        log_info "已取消操作"
        sleep 1
        interactive_menu
    fi
}

# 显示当前swap状态
show_current_swap_status() {
    echo ""
    echo "========================================"
    echo "     当前 Swap 状态"
    echo "========================================"
    echo ""
    
    if check_existing_swap 2>/dev/null; then
        echo ""
        show_swap_status
    else
        log_info "当前系统没有配置swap"
    fi
    
    echo ""
    read -p "按Enter键返回菜单..." dummy
    interactive_menu
}

# 主函数
main() {
    local remove_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--size)
                SWAP_SIZE="$2"
                shift 2
                ;;
            -w|--swappiness)
                SWAPPINESS="$2"
                shift 2
                ;;
            -c|--cache)
                CACHE_PRESSURE="$2"
                shift 2
                ;;
            -f|--file)
                SWAP_FILE="$2"
                shift 2
                ;;
            -i|--interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            -r|--remove)
                remove_only=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 检查root权限
    check_root "$@"
    
    # 如果是交互模式
    if [ "$INTERACTIVE_MODE" = true ]; then
        interactive_menu
        exit 0
    fi
    
    echo "================================"
    echo "  VPS Swap 配置脚本"
    echo "================================"
    echo ""
    
    # 显示系统信息
    log_info "系统信息:"
    local os_name=$(awk -F'"' '/^PRETTY_NAME=/{print $2}' /etc/os-release 2>/dev/null || echo "未知")
    log_info "  - OS: ${os_name}"
    log_info "  - 内核: $(uname -r)"
    log_info "  - 内存: $(free -h | awk 'NR==2{print $2}')"
    echo ""
    
    # 检查现有swap
    check_existing_swap || true
    echo ""
    
    # 如果只是删除swap
    if [ "$remove_only" = true ]; then
        remove_swap
        exit 0
    fi
    
    # 如果没有指定swap大小，使用推荐值（内存的1倍）
    if [ -z "$SWAP_SIZE" ]; then
        SWAP_SIZE=$(calculate_recommended_swap)
        log_info "未指定Swap大小，使用推荐值: $SWAP_SIZE (内存的1倍)"
        echo ""
    fi
    
    # 验证参数
    if [ "$SWAPPINESS" -lt 0 ] || [ "$SWAPPINESS" -gt 100 ]; then
        log_error "swappiness值必须在0-100之间"
        exit 1
    fi
    
    # 显示配置信息
    log_info "Swap配置:"
    log_info "  - 大小: $SWAP_SIZE"
    log_info "  - 位置: $SWAP_FILE"
    log_info "  - Swappiness: $SWAPPINESS"
    log_info "  - Cache Pressure: $CACHE_PRESSURE"
    echo ""
    
    # 检查磁盘空间
    local required_mb=$(size_to_mb "$SWAP_SIZE")
    check_disk_space $((required_mb + 100))  # 额外100MB缓冲
    
    # 如果存在旧swap，先关闭
    if check_existing_swap; then
        log_warn "将关闭现有swap..."
        swapoff -a 2>/dev/null || true
    fi
    
    # 创建和配置swap
    create_swap_file "$SWAP_SIZE" "$SWAP_FILE"
    enable_swap "$SWAP_FILE"
    configure_persistent_swap "$SWAP_FILE"
    optimize_swap_parameters "$SWAPPINESS" "$CACHE_PRESSURE"
    
    echo ""
    log_info "✓ Swap配置完成!"
    echo ""
    
    # 显示最终状态
    show_swap_status
    
    echo ""
    log_info "提示: 重启后swap将自动挂载"
}

# 运行主函数
main "$@"
