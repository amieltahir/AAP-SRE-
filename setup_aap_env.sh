#!/bin/bash
# Script to create isolated Python environment for AAP installation

set -e

echo "=== Installing system dependencies for building Python ==="
sudo apt update
sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev \
libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev git

echo "=== Installing pyenv ==="
curl https://pyenv.run | bash

# Add pyenv to shell
echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv virtualenv-init -)"

echo "=== Installing Python 3.13.8 via pyenv ==="
pyenv install 3.13.8

echo "=== Creating virtual environment 'aap_venv' ==="
pyenv virtualenv 3.13.8 aap_venv

echo "=== Activating virtual environment ==="
pyenv activate aap_venv

echo "=== Upgrading pip and installing Ansible-core 2.14 ==="
pip install --upgrade pip
pip install ansible-core==2.14

echo "=== Verification ==="
python --version
ansible --version

echo "=== Setup complete! Activate your env with: pyenv activate aap_venv ==="
