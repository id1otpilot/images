#!/bin/bash
SCREEN_RESOLUTION=${SCREEN_RESOLUTION:-1920x1080x24}

HORIZONTAL=$(echo ${SCREEN_RESOLUTION} | awk -Fx '{print $1}')
VERTICAL=$(echo ${SCREEN_RESOLUTION} | awk -Fx '{print $2}')
DEPTH=$(echo ${SCREEN_RESOLUTION} | awk -Fx '{print $3}')

case ${DEPTH} in
  8 | 16 | 24)
    ;;
  *)
    DEPTH=24
    ;;
esac

Xvfb :0 -ac -screen 0 ${HORIZONTAL}x${VERTICAL}x${DEPTH} -noreset -listen tcp -nolisten unix 1> /dev/null 2> /dev/null &
DISPLAY=:0 go test -race