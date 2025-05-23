#!/usr/bin/env sh

#################################################
# Default tools (my favourites) to make the dev
# experience nice. Can be customised by adding
# tools.override.sh or tools.override.nix.
# You can base these files on this file and
# tools.default.nix.
#################################################

TOOLS_DEFAULT=.devcontainer/tools.default.nix
TOOLS_OVERRIDE=.devcontainer/tools.override.nix

if [ -f "$TOOLS_OVERRIDE" ]; then
	echo "Installing nix dev tools from $TOOLS_OVERRIDE"
	export NIX_TOOLS_PATH=$PWD/$TOOLS_OVERRIDE
else
	echo "Installing nix dev tools from $TOOLS_DEFAULT. These can be overwritten by creating $TOOLS_OVERRIDE"
	export NIX_TOOLS_PATH=$PWD/$TOOLS_DEFAULT
fi

set -eux

rm -f ~/.bashrc ~/.profile ~/.zshrc ~/.zprofile
nix --extra-experimental-features "nix-command flakes" run home-manager -- --extra-experimental-features "nix-command flakes" switch --impure --flake .devcontainer
echo export 'PATH=~/.nix-profile/bin:$PATH' >/etc/profile.d/10-nix.sh
echo export 'PATH=~/.nix-profile/bin:$PATH' >~/.zprofile
chmod +x /etc/profile.d/10-nix.sh
. "/etc/profile.d/10-nix.sh"

touch /root/.zsh-hist/.zsh_history
ln -nsf /root/.zsh-hist/.zsh_history ~/.zsh_history

direnv allow
direnv exec . pre-commit install
