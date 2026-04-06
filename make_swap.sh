#!/usr/bin/env bash

set -euo pipefail

readonly GREEN="\033[32m"
readonly FONT="\033[0m"
readonly RED="\033[31m"

readonly SWAPFILE="/swapfile"
readonly FSTAB_FILE="/etc/fstab"
readonly FSTAB_BACKUP="/etc/fstab.bak"
readonly FSTAB_ENTRY="/swapfile none swap defaults 0 0"


log_info() {
    echo -e "${GREEN}$1${FONT}"
}


log_error() {
    echo -e "${RED}$1${FONT}" >&2
}


# 检查 root 权限
check_root() {
    if [[ ${EUID} -ne 0 ]]; then
        log_error "Error: This script must be run as root!"
        exit 1
    fi
}


# 检查 OpenVZ 环境
check_ovz() {
    local virt_type=""

    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt_type="$(systemd-detect-virt 2>/dev/null || true)"
    fi

    if [[ "${virt_type}" == "openvz" ]] || [[ -d "/proc/vz" ]] || [[ -f "/proc/user_beancounters" ]]; then
        log_error "检测到 OpenVZ 环境，不支持自动创建 swap。"
        exit 1
    fi
}


swapfile_exists() {
    [[ -f "${SWAPFILE}" ]]
}


swapfile_active() {
    awk -v path="${SWAPFILE}" 'NR > 1 && $1 == path { found = 1 } END { exit(found ? 0 : 1) }' /proc/swaps
}


swapfile_in_fstab() {
    grep -Eq '^/swapfile[[:space:]]+none[[:space:]]+swap[[:space:]]+defaults[[:space:]]+0[[:space:]]+0([[:space:]]*#.*)?$' "${FSTAB_FILE}"
}


backup_fstab_once() {
    if [[ ! -f "${FSTAB_BACKUP}" ]]; then
        cp -a "${FSTAB_FILE}" "${FSTAB_BACKUP}"
    fi
}


remove_swapfile_fstab_entry() {
    local tmp_file

    if ! swapfile_in_fstab; then
        return
    fi

    backup_fstab_once
    tmp_file="$(mktemp "${FSTAB_FILE}.XXXXXX")"

    awk '
        $1 == "/swapfile" && $2 == "none" && $3 == "swap" && $4 == "defaults" && $5 == "0" && $6 == "0" { next }
        { print }
    ' "${FSTAB_FILE}" > "${tmp_file}"

    chmod --reference="${FSTAB_FILE}" "${tmp_file}"
    chown --reference="${FSTAB_FILE}" "${tmp_file}"
    mv "${tmp_file}" "${FSTAB_FILE}"
}


ensure_swapfile_fstab_entry() {
    if ! swapfile_in_fstab; then
        backup_fstab_once
        printf '%s\n' "${FSTAB_ENTRY}" >> "${FSTAB_FILE}"
    fi
}


validate_swapsize() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}


check_disk_space() {
    local swapsize_mb="$1"
    local available_mb

    available_mb="$(df --output=avail -m / | tail -n 1 | tr -d ' ')"
    if (( available_mb <= swapsize_mb + 64 )); then
        log_error "磁盘剩余空间不足，至少需要 ${swapsize_mb} MB 以上可用空间。"
        return 1
    fi
}


create_swapfile() {
    local swapsize_mb="$1"

    if fallocate -l "${swapsize_mb}M" "${SWAPFILE}" 2>/dev/null; then
        return
    fi

    log_info "fallocate 失败，回退到 dd 创建 swapfile..."
    dd if=/dev/zero of="${SWAPFILE}" bs=1M count="${swapsize_mb}" status=progress
}


show_swap_status() {
    echo
    cat /proc/swaps
    grep -E '^(SwapTotal|SwapFree):' /proc/meminfo
    echo
}


# 添加 swap
add_swap() {
    local swapsize

    if swapfile_exists || swapfile_active || swapfile_in_fstab; then
        log_error "检测到已有 /swapfile 相关配置，请先删除后再重新创建。"
        show_swap_status
        return 1
    fi

    log_info "请输入需要添加的 swap 大小，建议为内存的 1-2 倍。"
    read -r -p "请输入 swap 大小 (MB): " swapsize

    if ! validate_swapsize "${swapsize}"; then
        log_error "swap 大小必须是大于 0 的整数。"
        return 1
    fi

    check_disk_space "${swapsize}"

    log_info "未发现 /swapfile，正在创建..."
    create_swapfile "${swapsize}"
    chmod 600 "${SWAPFILE}"
    mkswap "${SWAPFILE}" >/dev/null
    swapon "${SWAPFILE}"
    ensure_swapfile_fstab_entry

    log_info "Swap 创建成功，信息如下："
    show_swap_status
}


# 删除 swap
del_swap() {
    if ! swapfile_exists && ! swapfile_active && ! swapfile_in_fstab; then
        log_error "未发现 /swapfile 配置，无需删除。"
        return 1
    fi

    log_info "正在删除 /swapfile..."

    if swapfile_active; then
        swapoff "${SWAPFILE}"
    fi

    if swapfile_exists; then
        rm -f "${SWAPFILE}"
    fi

    remove_swapfile_fstab_entry

    log_info "Swap 删除成功，当前信息如下："
    show_swap_status
}


# 主菜单
main_menu() {
    local choice

    echo -e "———————————————————————————————————————"
    echo -e "${GREEN}Linux VPS 一键添加/删除 swap 脚本${FONT}"
    echo -e "${GREEN}1. 添加 swap${FONT}"
    echo -e "${GREEN}2. 删除 swap${FONT}"
    echo -e "———————————————————————————————————————"
    read -r -p "请输入数字 [1-2]: " choice

    case "${choice}" in
        1)
            add_swap
            ;;
        2)
            del_swap
            ;;
        *)
            log_error "无效输入，请输入 1 或 2"
            return 1
            ;;
    esac
}


# 脚本入口
check_root
check_ovz
main_menu
