#!/usr/bin/env python3

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT_HOME = Path("/root")
BASHRC_FILE = ROOT_HOME / ".bashrc"
INPUTRC_FILE = Path("/etc/inputrc")
VIMRC_FILE = ROOT_HOME / ".vimrc"

BASHRC_START = "# >>> debian_init shell settings >>>"
BASHRC_END = "# <<< debian_init shell settings <<<"
BASHRC_CONTENT = """export LS_OPTIONS='--color=auto'
eval "$(dircolors)"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -l'
alias l='ls $LS_OPTIONS -lA'

# Append to the history file, don't overwrite it
shopt -s histappend
PROMPT_COMMAND='history -a; history -c; history -r'
HISTFILESIZE=10000
HISTSIZE=1000
HISTCONTROL=ignoredups:ignorespace
"""

INPUTRC_START = "# >>> debian_init history search >>>"
INPUTRC_END = "# <<< debian_init history search <<<"
INPUTRC_CONTENT = "\"\\e[5~\": history-search-backward\n\"\\e[6~\": history-search-forward\n"

VIMRC_START = "\" >>> debian_init vim settings >>>"
VIMRC_END = "\" <<< debian_init vim settings <<<"
VIMRC_CONTENT = "set mouse-=a\n"


def require_root():
    if not hasattr(os, "geteuid") or os.geteuid() != 0:
        raise PermissionError("This script must be run as root.")


def backup_once(file_path):
    backup_path = file_path.with_name(f"{file_path.name}.bak")
    if file_path.exists() and not backup_path.exists():
        shutil.copy2(file_path, backup_path)


def atomic_write(file_path, content):
    file_path.parent.mkdir(parents=True, exist_ok=True)

    fd, temp_path = tempfile.mkstemp(
        prefix=f".{file_path.name}.",
        dir=str(file_path.parent),
    )

    try:
        if file_path.exists():
            os.fchmod(fd, file_path.stat().st_mode)
        else:
            os.fchmod(fd, 0o644)

        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)

        os.replace(temp_path, file_path)
    except Exception:
        if os.path.exists(temp_path):
            os.unlink(temp_path)
        raise


def ensure_managed_block(file_path, start_marker, end_marker, content, create_if_missing=False):
    if file_path.exists():
        original_content = file_path.read_text(encoding="utf-8")
    elif create_if_missing:
        original_content = ""
    else:
        raise FileNotFoundError(f"File {file_path} not found.")

    managed_block = f"{start_marker}\n{content.strip()}\n{end_marker}\n"
    block_pattern = re.compile(
        rf"{re.escape(start_marker)}\n.*?{re.escape(end_marker)}\n?",
        re.DOTALL,
    )

    if block_pattern.search(original_content):
        updated_content = block_pattern.sub(managed_block, original_content, count=1)
    else:
        separator = "\n" if original_content and not original_content.endswith("\n") else ""
        updated_content = f"{original_content}{separator}{managed_block}"

    if updated_content != original_content:
        if file_path.exists():
            backup_once(file_path)
        atomic_write(file_path, updated_content)


def run_command(command, description):
    print(description)
    subprocess.run(command, check=True)


def configure_bashrc():
    ensure_managed_block(
        BASHRC_FILE,
        BASHRC_START,
        BASHRC_END,
        BASHRC_CONTENT,
        create_if_missing=True,
    )


def configure_inputrc():
    ensure_managed_block(
        INPUTRC_FILE,
        INPUTRC_START,
        INPUTRC_END,
        INPUTRC_CONTENT,
        create_if_missing=True,
    )


def configure_vim():
    ensure_managed_block(
        VIMRC_FILE,
        VIMRC_START,
        VIMRC_END,
        VIMRC_CONTENT,
        create_if_missing=True,
    )


def update_apt():
    run_command(["apt-get", "update"], "Updating apt package lists...")


def install_curl():
    if shutil.which("curl"):
        print("curl is already installed.")
        return

    run_command(["apt-get", "install", "-y", "curl"], "Installing curl...")


def install_docker():
    fd, docker_script_path = tempfile.mkstemp(prefix="get-docker-", suffix=".sh")
    os.close(fd)

    try:
        run_command(
            ["curl", "-fsSL", "https://get.docker.com", "-o", docker_script_path],
            "Downloading Docker install script...",
        )
        run_command(["sh", docker_script_path], "Installing Docker...")
    finally:
        if os.path.exists(docker_script_path):
            os.unlink(docker_script_path)


def main():
    try:
        require_root()
        print("Starting server initialization configurations...\n")

        update_apt()
        install_curl()

        configure_bashrc()
        print(f"Configured {BASHRC_FILE}\n")

        configure_inputrc()
        print(f"Configured {INPUTRC_FILE}\n")

        configure_vim()
        print(f"Configured {VIMRC_FILE}\n")

        install_docker()

        print(
            "\nAll configurations applied. Run `source /root/.bashrc` or start a new shell "
            "to load the updated shell settings."
        )
    except (PermissionError, FileNotFoundError, OSError, subprocess.CalledProcessError) as exc:
        print(f"\nInitialization failed: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
