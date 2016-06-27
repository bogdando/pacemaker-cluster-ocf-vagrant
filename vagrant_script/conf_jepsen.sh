#!/bin/sh
# Clone/fetch jepsen fork and branch $1, or use from a mount
mkdir -p /jepsen
cd /jepsen
branch="${1:-dev}"
if ! git clone -b $branch https://github.com/bogdando/jepsen
then
  cd ./jepsen
  git remote update
  git pull --ff-only
fi
mkdir -p /jepsen/logs
sync
exit 0
