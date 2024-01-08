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

DISPLAY_NUM=0
export DISPLAY=":$DISPLAY_NUM"

QUIET=${QUIET:-""}
DRIVER_ARGS=""
if [ -z "$QUIET" ]; then
    DRIVER_ARGS="--verbose"
fi

clean() {
  if [ -n "$FILESERVER_PID" ]; then
    kill -TERM "$FILESERVER_PID"
  fi
  if [ -n "$CLIPBOARD_PID" ]; then
    kill -TERM "$CLIPBOARD_PID"
  fi
  if [ -n "$XVFB_PID" ]; then
    kill -TERM "$XVFB_PID"
  fi
  if [ -n "$OPENBOX_PID" ]; then
    kill -TERM "$OPENBOX_PID"
  fi
  if [ -n "$DRIVER_PID" ]; then
    kill -TERM "$DRIVER_PID"
  fi
  if [ -n "$PRISM_PID" ]; then
    kill -TERM "$PRISM_PID"
  fi
  if [ -n "$X11VNC_PID" ]; then
    kill -TERM "$X11VNC_PID"
  fi
}

trap clean SIGINT SIGTERM

/usr/bin/fileserver &
FILESERVER_PID=$!

DISPLAY=${DISPLAY} /usr/bin/clipboard &
CLIPBOARD_PID=$!

if env | grep -q ROOT_CA_; then
  mkdir -p /tmp/ca-certificates
  for e in $(env | grep ROOT_CA_ | sed -e 's/=.*$//'); do
    certname=$(echo -n $e | sed -e 's/ROOT_CA_//')
    echo ${!e} | base64 -d >/tmp/ca-certificates/${certname}.crt
  done
  update-ca-certificates --localcertsdir /tmp/ca-certificates
fi

Xvfb ${DISPLAY} -ac -screen 0 ${HORIZONTAL}x${VERTICAL}x${DEPTH} -noreset -listen tcp -nolisten unix &
XVFB_PID=$!
while ! xdpyinfo -display ${DISPLAY} 1> /dev/null 2> /dev/null; do
  echo 'Waiting X server...'
  sleep 1s
done

/bin/bash -c "until [ -f /tmp/.X0-lock ]; do sleep 1s; done; exec openbox" &
OPENBOX_PID=$!

if [ "$ENABLE_VNC" == "true" ]; then
    x11vnc -xkb -xrandr -noxrecord -forever -passwd selenoid -display WAIT${DISPLAY} -shared -rfbport 5900 1> /dev/null 2> /dev/null &
    X11VNC_PID=$!
fi

DISPLAY="$DISPLAY" /opt/webkit/bin/WebKitWebDriver --port=5555 --host=0.0.0.0 ${DRIVER_ARGS} &
DRIVER_PID=$!

/usr/bin/prism  &
PRISM_PID=$!

wait
