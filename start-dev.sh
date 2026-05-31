#!/bin/sh

etorrent_core=$(dirname "$0")
cd "$etorrent_core"
mkdir -p log/sasl
exec rebar3 shell --sname etorrent --config ~/.config/etorrent.config --apps etorrent_core

