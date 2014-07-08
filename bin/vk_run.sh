#!/bin/bash

application="vk"

topdir="/home/victorykit"
appdir="${topdir}/${application}"
current_path="${appdir}/current"
shared_path="${appdir}/shared"

. "${appdir}/current/bin/vk_env.sh"

if [ -z "$RBENV_SHELL" ] ; then
  PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH:/usr/local/sbin:/usr/local/bin:$HOME/bin"; export PATH
  eval "$(rbenv init -)"
fi

cd "${appdir}/current"

exec bundle exec $@
