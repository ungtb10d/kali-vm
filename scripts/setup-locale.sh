#!/bin/sh

set -eu

locale=$1

if ! grep -q "^# $locale " /etc/locale.gen; then
	echo "ERROR: invalid locale '$locale'"
	exit 1
fi

pattern=$(echo $locale | sed 's/\./\\./g')
sed -i "/^# $pattern /s/^# //" /etc/locale.gen
locale-gen
update-locale LANG=$locale
