#!/bin/sh

set -eu

username=$1
password=$2

echo "INFO: create user '$username'"
adduser --disabled-password --gecos "" $username

echo "INFO: set user password"
echo $username:$password | chpasswd
