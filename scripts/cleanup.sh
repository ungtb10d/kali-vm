#!/bin/bash

# XXX mostly taken from internal wiki

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

exit 0

sudo rm -rf '/var/lib/apt/lists/*'

sudo rm -f '/root/.*_history' '/home/kali/.*_history'
sudo rm -f '/root/.*_hsts' '/home/kali/.*_hsts'
sudo rm -f '/root/.lesshst' '/home/kali/.lesshst'
sudo rm -f '/root/.recently-used.xbel' '/home/kali/.recently-used.xbel'
sudo rm -f '/root/.viminfo' '/home/kali/.viminfo'
sudo rm -f '/root/.ssh/known_hosts' '/home/kali/.ssh/known_hosts'
sudo rm -rf '/tmp/*'
sudo rm -rf '/var/tmp/*'

[ -e ~/.msf4/history ] && echo > ~/.msf4/history
[ -e ~/.msf5/history ] && echo > ~/.msf5/history
[ -e ~/.msf6/history ] && echo > ~/.msf6/history

sudo rm -f '/var/lib/sudo/lectured/kali'
sudo rm -f '/var/run/sudo/ts/kali'

