#!/usr/bin/env sh

#################################################
# Default tools (my favourites) to make the dev
# experience nice. Can be customised by adding
# tools.override.sh
#################################################

set -eux

# Basics for installing other tools
apt-get update
apt-get install -y \
	ca-certificates \
	curl \
	gnupg \
	lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg |
	gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
	"deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" |
	tee /etc/apt/sources.list.d/docker.list >/dev/null

# Useful tools
apt-get update
apt-get install -y \
	docker-ce-cli \
	git \
	python \
	python-pip \
	zsh

pip install --no-cache-dir \
	pre-commit

# Command line setup
curl -fsSL \
	https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh |
	zsh || true
git clone https://github.com/djui/alias-tips.git \
	~/.oh-my-zsh/custom/plugins/alias-tips
git clone https://github.com/zsh-users/zsh-autosuggestions \
	~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
	~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
cp -f .devcontainer/.zshrc $HOME

# Required by vscode extension golang.go
go install golang.org/x/tools/gopls@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install honnef.co/go/tools/cmd/staticcheck@latest

# Setup anything we need for development
make init-dev
