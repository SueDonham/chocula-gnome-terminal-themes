#!/bin/bash

##############################	Function definitions:
handle_dependencies(){
	local pkg_mgrs=("apt" "dnf" "pacman" "yum" "zypper")
	local deps=()

	for d in "dconf" "gsettings" "uuidgen" ; do
		if ! command -v "$d" &>/dev/null; then
			deps+=("$d")
			echo "Dependency '$d' not found."
		fi
	done

	[[ -z "$deps" ]] && return || read -r -p "Install missing program(s)? [y|N]: " yn
	[[ "$yn" != [yY]* ]] && echo "Exiting" && exit

	for p in "${pkg_mgrs[@]}"; do
		if command -v "$p" &>/dev/null; then
			[[ "$p" = "pacman" ]] && comm="sudo $p -S --noconfirm " || comm="sudo $p install -y "
			for d in "${deps[@]}"; do
				[[ "$d" = "uuuidgen" ]] && d="libuuid"
				$comm $d
			done
			break
		else echo "Sorry, could not locate system's package manager." && exit
		fi
	done
}

set_globals(){
	DIR="/org/gnome/terminal"
	WORKING_FILE="gnome-terminal-backup_chocula.txt"
	FLAVORS=("Chocula" "Chocula-Pastel")
	PROFILES="$DIR/legacy/profiles:"
	TMP=tmp.txt
	declare -g -A ID=([Chocula]="$(uuidgen)" [Chocula-Pastel]="$(uuidgen)")
}

install_theme(){
	echo "installing theme..."
	local flavor="${FLAVORS[$1]}"	# Name of variant
	echo "local flavor = $flavor"
	local list=$(gsettings get org.gnome.Terminal.ProfilesList list)	# List of profile IDs

	echo "Installing $flavor theme ..."
	dconf write $PROFILES/list "${list%]*}, '${ID[$flavor]}']"	# Update list
	dconf dump $DIR/ > $WORKING_FILE	# Dump config to working file
	cat "$flavor" >> $TMP	# Copy profile to temp file
	sed -i "s/"$flavor"_UUID/${ID[$flavor]}/g" $TMP	# Give profile an ID
	cat $TMP >> $WORKING_FILE	# Append profile to working file
	dconf load $DIR/ < $WORKING_FILE	# Update config
	rm $TMP
	echo "Done"
}

set_as_default(){
	local default=$1

	if [[ "$default" == 2 ]]; then
		# Clarify which of two installed themes to set as default:
		printf "Which variant?\n1) Chocula\n2) Chocula-Pastel\n"
		read -r -p "Enter your selection [1|2]: " default
		((default--))
		[[ "$default" != [0-1] ]] && echo "Invalid selection; exiting" && exit
	fi

	dconf write $PROFILES/default "'${ID[${FLAVORS[$default]}]}'"	# Set default profile
	echo "Done"
}

##############################	Main logic:
handle_dependencies
set_globals

dconf dump $DIR/ > $WORKING_FILE	# Dump settings
[[ -s $WORKING_FILE ]] && cp $WORKING_FILE "gnome-terminal-backup.txt"	# If settings exist, back them up

printf "Available flavors to install:\n1) Chocula\n2) Chocula-Pastel\n3) Both\n"
read -r -p "Enter your selection [1|2|3]: " SELECTION
((SELECTION--))	# Decrement selection to match its FLAVORS array index

case $SELECTION in
	0 | 1)	 install_theme "$SELECTION" ;;
	2)	install_theme '0' && install_theme '1' ;;
	*)	echo "Invalid selection; exiting" && exit
esac

read -r -p "Set as default theme? [y|N] " YN
[[ "$YN" == [yY]* ]] && set_as_default "$SELECTION"

dconf dump $DIR/ > $WORKING_FILE	# Update backup
