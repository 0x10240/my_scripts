#!/usr/bin/env python3

import os
import shutil
import re
import subprocess
import glob

# Function to uncomment lines matching a pattern in a file
def uncomment_line(file_path, pattern):
    if os.path.isfile(file_path):
        with open(file_path, 'r') as f:
            lines = f.readlines()

        pattern_regex = re.compile(r'^#\s*' + re.escape(pattern))
        with open(file_path, 'w') as f:
            for line in lines:
                if pattern_regex.match(line):
                    line = pattern + '\n'
                f.write(line)
    else:
        print(f"File {file_path} not found!")

# Function to replace a line matching a pattern with a new line
def replace_line(file_path, search_pattern, replacement):
    if os.path.isfile(file_path):
        with open(file_path, 'r') as f:
            lines = f.readlines()

        pattern_regex = re.compile('^' + re.escape(search_pattern))
        with open(file_path, 'w') as f:
            for line in lines:
                if pattern_regex.match(line):
                    line = replacement + '\n'
                f.write(line)
    else:
        print(f"File {file_path} not found!")

# Function to append content to a file if it's not already present
def append_content(file_path, marker, content):
    if os.path.isfile(file_path):
        with open(file_path, 'r') as f:
            file_content = f.read()
        if marker not in file_content:
            with open(file_path, 'a') as f:
                f.write('\n' + marker + '\n')
                f.write(content + '\n')
    else:
        print(f"File {file_path} not found!")

# Function to configure $HOME/.bashrc
def configure_bashrc():
    bashrc_file = os.path.expanduser("~/.bashrc")

    # Backup the file
    shutil.copy(bashrc_file, bashrc_file + '.bak')

    # Uncomment required lines
    uncomment_line(bashrc_file, "export LS_OPTIONS='--color=auto'")
    uncomment_line(bashrc_file, "eval \"$(dircolors)\"")
    uncomment_line(bashrc_file, "alias ls='ls $LS_OPTIONS'")
    uncomment_line(bashrc_file, "alias ll='ls $LS_OPTIONS -l'")
    uncomment_line(bashrc_file, "alias l='ls $LS_OPTIONS -lA'")

    # Append history configurations
    history_marker = "# Custom history configurations"
    history_content = """
# Append to the history file, don't overwrite it
shopt -s histappend
PROMPT_COMMAND='history -a; history -c; history -r'
HISTFILESIZE=10000
HISTSIZE=1000
HISTCONTROL=ignoredups:ignorespace
"""
    append_content(bashrc_file, history_marker, history_content)

# Function to configure /etc/inputrc
def configure_inputrc():
    inputrc_file = "/etc/inputrc"

    # Backup the file
    try:
        shutil.copy(inputrc_file, inputrc_file + '.bak')

        # Uncomment required lines
        uncomment_line(inputrc_file, '"\\e[5~": history-search-backward')
        uncomment_line(inputrc_file, '"\\e[6~": history-search-forward')
    except PermissionError:
        print(f"Permission denied while modifying {inputrc_file}. Please run the script with sudo.")
    except FileNotFoundError:
        print(f"File {inputrc_file} not found!")

# Function to configure Vim defaults
def configure_vim():
    # Find the defaults.vim file regardless of the Vim version
    vim_defaults_list = glob.glob('/usr/share/vim/vim*/defaults.vim')
    if not vim_defaults_list:
        print("defaults.vim not found!")
        return

    vim_defaults = vim_defaults_list[-1]  # Take the last one (assuming it's the latest version)

    # Backup the file
    shutil.copy(vim_defaults, vim_defaults + '.bak')

    # Replace 'set mouse=a' with 'set mouse-=a'
    replace_line(vim_defaults, '    set mouse=a', '    set mouse-=a')

# Function to reload .bashrc (note: this won't affect the current shell session)
def reload_bashrc():
    print("Reloading .bashrc...")
    subprocess.run(['source', os.path.expanduser('~/.bashrc')], shell=True)

# Function to install Docker
def install_docker():
    subprocess.run(['curl', '-fsSL', 'https://get.docker.com', '-o', 'get-docker.sh'])
    subprocess.run(['sh', 'get-docker.sh'])

# Function to update apt package lists
def update_apt():
    print("Updating apt package lists...")
    subprocess.run(['apt', 'update', '-y'])

# Main script execution
def main():
    print("Starting server initialization configurations...\n")

    configure_bashrc()
    print(f"Configured {os.path.expanduser('~/.bashrc')}\n")

    configure_inputrc()
    print("Configured /etc/inputrc\n")

    configure_vim()
    print("Configured Vim defaults\n")

    # Note: Reloading .bashrc in a subprocess won't affect the current shell
    reload_bashrc()

    update_apt()

    install_docker()

    print("\nAll configurations applied. Please restart your shell or source your .bashrc to apply changes.")

if __name__ == "__main__":
    configure_vim()
