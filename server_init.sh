#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本"
  exit
fi

# 更新并安装必要软件包
function update_system() {
  echo "更新系统..."
  apt update && apt upgrade -y
  echo "系统更新完成"
}

# 安装 Docker
function install_docker() {
  echo "安装 Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  echo "Docker 安装完成"
}

# 配置 ls 颜色
function configure_ls_colors() {
  echo "配置 ls 颜色..."
  BASHRC_FILE="$HOME/.bashrc"
  if ! grep -q "LS_OPTIONS" "$BASHRC_FILE"; then
    cat <<EOT >> "$BASHRC_FILE"

# 配置 ls 颜色
export LS_OPTIONS='--color=auto'
eval "\$(dircolors)"
alias ls='ls \$LS_OPTIONS'
alias ll='ls \$LS_OPTIONS -l'
alias l='ls \$LS_OPTIONS -lA'
EOT
    echo ".bashrc 已更新"
  else
    echo ".bashrc 中已存在 ls 配色配置"
  fi
}

# 配置 page up 和 page down 搜索历史记录
function configure_history_search() {
  echo "配置 page up 和 page down 搜索历史记录..."
  INPUTRC_FILE="/etc/inputrc"
  if ! grep -q "history-search-backward" "$INPUTRC_FILE"; then
    cat <<EOT >> "$INPUTRC_FILE"

# 配置 page up 和 page down 搜索历史记录
"\e[5~": history-search-backward
"\e[6~": history-search-forward
EOT
    echo "inputrc 已更新"
  else
    echo "inputrc 中已存在历史记录搜索配置"
  fi
}

# 设置自动保存历史记录
function configure_history_saving() {
  echo "设置自动保存历史记录..."
  BASHRC_FILE="$HOME/.bashrc"
  if ! grep -q "histappend" "$BASHRC_FILE"; then
    cat <<EOT >> "$BASHRC_FILE"

# 自动保存历史记录
shopt -s histappend
PROMPT_COMMAND='history -a; history -c; history -r'
HISTFILESIZE=10000
HISTSIZE=1000
HISTCONTROL=ignoredups:ignorespace
EOT
    echo ".bashrc 已更新历史记录配置"
  else
    echo ".bashrc 中已存在历史记录配置"
  fi
}

 解决 vim 无法右键粘贴问题
function fix_vim_paste_issue() {
  echo "解决 vim 无法右键粘贴问题..."
  VIM_DEFAULTS_FILE="/usr/share/vim/vim90/defaults.vim"
  if grep -q "set mouse=a" "$VIM_DEFAULTS_FILE"; then
    sed -i 's/set mouse=a/set mouse-=a/' "$VIM_DEFAULTS_FILE"
    echo "vim 配置已更新"
  else
    echo "vim 已配置为允许右键粘贴"
  fi
}

# 重新加载 bash 配置
function reload_bashrc() {
  echo "重新加载 bash 配置..."
  source "$HOME/.bashrc"
  echo "bash 配置已重新加载"
}

# 主函数，执行所有操作
function main() {
  update_system
  install_docker
  configure_ls_colors
  configure_history_search
  configure_history_saving
  fix_vim_paste_issue
  reload_bashrc
  echo "所有初始化配置已完成，请重新打开终端以应用更改。"
}

# 调用主函数
main
