#!/bin/bash

set -eu


function check_updates {
  LATEST=`curl -q https://tools.altipla.consulting/sergeant/release`
  CURRENT=`cat /.config/sergeant/version`
  if [ $LATEST != $CURRENT ]
  then
    echo
    echo "╭――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╮"
    echo "│                                                                      │"
    echo "│   Installation needs an update. Run the following command:           │"
    echo "│   curl -q https://tools.altipla.consulting/sergeant/install | bash   │"
    echo "│                                                                      │"
    echo "╰――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╯"
    echo
  fi
}


LOCKFILE=$HOME/.config/sergeant/autoupdate.lock
if [[ ! -e $LOCKFILE ]]
then
  check_updates
  touch $LOCKFILE
else
  if [[ "`find $LOCKFILE -mmin +60`" ]]
  then
    check_updates
    touch $LOCKFILE
  fi
fi
