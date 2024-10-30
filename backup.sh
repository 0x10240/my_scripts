#!/bin/bash

# Current time
current=$(date +"%Y%m%d_%H%M%S")

password="d3oA5FVdz1IXnfi"

# rclone command and config
RCLONE_CMD="/usr/bin/rclone"
RCLONE_CONF="/root/.config/rclone/rclone.conf"

# Error checking function
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "\033[31m $1 失败 \033[0m"
        exit 1
    fi
}

# Generalized Encryption function
Encryption() {
    local input_path="$1"
    local output_file="$2"
    local enc_password="${3:-$password}"

    # 加密
    tar -zcf - "$input_path" | openssl enc -aes-256-cbc -salt -pbkdf2 -k "$enc_password" | dd of="$output_file"

    # 解密
    # dd if=$output_file | openssl enc -d -aes-256-cbc -pbkdf2 -k $password | tar -zxf -

    check_error "加密压缩 $input_path 到 $output_file"

    echo -e "\033[32m 数据加密备份完成：$output_file \033[0m"
}

# Generalized Upload function with three parameters
UploadToRemote() {
    local input_file="$1"
    local remote_name="$2"
    local remote_backup_dir="$3"

    local remote_path="$remote_name:$remote_backup_dir"

    $RCLONE_CMD --config "$RCLONE_CONF" copy "$input_file" "$remote_path"
    check_error "备份 $input_file 到 $remote_path"

    echo -e "\033[32m 远程备份上传成功：$remote_path \033[0m"
}

# Bitwarden backup function
bitwarden_backup() {
    cd /data/bitwarden
    
    check_error "切换目录失败"

    local backup_source="data"
    local backup_dest_dir="/app_backup/bitwarden"
    local backup_filename="bitwarden_$current.aes"
    local remote_name="gdrive"
    local remote_backup_dir="00_data_backup/bitwarden"

    local dailyPath="$backup_dest_dir/$backup_filename"

    Encryption "$backup_source" "$dailyPath" "$password"
    UploadToRemote "$dailyPath" "$remote_name" "$remote_backup_dir"

    echo -e "\033[32m Bitwarden 备份操作已完成！ \033[0m"
}

start() {
    bitwarden_backup
    # Uncomment the following line to enable /etc backup
    # etc_backup

    echo -e "\033[32m 所有备份操作已完成！ \033[0m"
}

start
