#!/bin/bash

set -eu

LOCKFILE=$HOME/.config/sergeant/autoupdate.lock

function check_updates {
  LATEST=$(curl -qs https://tools.altipla.consulting/sergeant/release)
  CURRENT=$(cat ~/.config/sergeant/release)
  if [ "$LATEST" != "$CURRENT" ]
  then
    echo
    echo "╭――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╮"
    echo "│                                                                      │"
    echo "│   Installation needs an update. Run the following command:           │"
    echo "│   curl -s https://tools.altipla.consulting/sergeant/install | bash   │"
    echo "│                                                                      │"
    echo "╰――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╯"
    echo
  else
    touch "$LOCKFILE"
  fi
}

if [[ ! -e $LOCKFILE ]]
then
  check_updates
else
  if [[ "$(find $LOCKFILE -mmin +60)" ]]
  then
    check_updates
  fi
fi
