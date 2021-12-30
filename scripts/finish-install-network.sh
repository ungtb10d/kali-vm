#!/bin/sh

set -eu

hostname=$(cat /etc/hostname)

if grep -Eq "^127\.0\.1\.1\s+$hostname" /etc/hosts; then
	echo "INFO: hostname already present in /etc/hosts"
	exit 0
fi

if ! grep -Eq "^127\.0\.0\.1\s+localhost" /etc/hosts; then
	echo "ERROR: Couldn't find localhost in /etc/hosts"
	exit 1
fi

sed -Ei "/^127\.0\.0\.1\s+localhost/a 127.0.1.1\t$hostname" /etc/hosts
