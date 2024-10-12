#!/usr/bin/env bash
Green="\033[32m"
Font="\033[0m"
Red="\033[31m" 

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Red}Error: This script must be run as root!${Font}"
        exit 1
    fi
}

# 检查 OpenVZ 环境
check_ovz() {
    if [[ -d "/proc/vz" ]]; then
        echo -e "${Red}Your VPS is based on OpenVZ, not supported!${Font}"
        exit 1
    fi
}

# 添加 swap
add_swap() {
    echo -e "${Green}请输入需要添加的 swap 大小，建议为内存的 2 倍！${Font}"
    read -p "请输入 swap 大小 (MB): " swapsize

    # 检查是否已经存在 swapfile
    if ! grep -q "swapfile" /etc/fstab; then
        echo -e "${Green}未发现 swapfile，正在创建...${Font}"
        fallocate -l ${swapsize}M /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap defaults 0 0' >> /etc/fstab
        echo -e "${Green}Swap 创建成功，信息如下：${Font}"
        cat /proc/swaps
        grep Swap /proc/meminfo
    else
        echo -e "${Red}swapfile 已存在，无法重复创建！${Font}"
    fi
}

# 删除 swap
del_swap() {
    if grep -q "swapfile" /etc/fstab; then
        echo -e "${Green}发现 swapfile，正在删除...${Font}"
        swapoff /swapfile
        rm -f /swapfile
        sed -i '/swapfile/d' /etc/fstab
        echo "3" > /proc/sys/vm/drop_caches
        echo -e "${Green}Swap 删除成功！${Font}"
    else
        echo -e "${Red}未发现 swapfile，删除失败！${Font}"
    fi
}

# 主菜单
main_menu() {
    echo -e "———————————————————————————————————————"
    echo -e "${Green}Linux VPS 一键添加/删除 swap 脚本${Font}"
    echo -e "${Green}1. 添加 swap${Font}"
    echo -e "${Green}2. 删除 swap${Font}"
    echo -e "———————————————————————————————————————"
    read -p "请输入数字 [1-2]: " choice
    case "$choice" in
        1)
            add_swap
            ;;
        2)
            del_swap
            ;;
        *)
            echo -e "${Red}无效输入，请输入 1 或 2${Font}"
            ;;
    esac
}

# 脚本入口
set -e
check_root
check_ovz
main_menu
