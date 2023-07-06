#!/bin/bash

declare curDir="$(dirname $0)"
curDir="$(readlink -f $curDir)"

ln -s "$curDir"/src/gg.sh /usr/local/bin/gg
