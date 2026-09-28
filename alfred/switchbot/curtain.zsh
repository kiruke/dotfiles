#!/bin/zsh

export PATH="/usr/local/bin:$PATH"

source "$HOME/.config/dotfiles/secrets.zsh"

DEVICE_ID="$SWITCHBOT_CURTAIN_ID"

case "$1" in
  open)
    switchbot devices expand "$DEVICE_ID" setPosition --position 0
    ;;
  close)
    switchbot devices expand "$DEVICE_ID" setPosition --position 100
    ;;
esac
