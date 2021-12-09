#!/bin/bash

# XXX mostly taken from internal wiki

set -eu

for x in clean auto-remove autoclean; do
  echo ${x};
  apt -y -qq "${x}";
  echo;
done

for x in autoremove; do
  echo ${x};
  apt -y -qq --purge "${x}";
  echo;
done

dpkg --list \
  | grep "^rc" \
  | cut -d " " -f 3 \
  | while read x; do
    echo ${x};
    dpkg --purge ${x};
done
