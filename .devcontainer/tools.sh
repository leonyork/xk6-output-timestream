#!/usr/bin/env sh

#################################################
# Uses tools.default.sh by default.
# Can be customised by adding tools.override.sh
#################################################

TOOLS_DEFAULT=.devcontainer/tools.default.sh
TOOLS_OVERRIDE=.devcontainer/tools.override.sh

if [[ -f "$TOOLS_OVERRIDE" ]]; then
	echo "Installing dev tools from $TOOLS_OVERRIDE"
	exec $TOOLS_OVERRIDE
	exit $?
fi

echo "Installing dev tools from $TOOLS_DEFAULT. These can be overwritten by creating $TOOLS_OVERRIDE"
exec $TOOLS_DEFAULT
exit $?
