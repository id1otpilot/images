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
  if [ -n "$SELENIUM_PID" ]; then
    kill -TERM "$SELENIUM_PID"
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

DISPLAY="$DISPLAY" /usr/bin/java -Xmx256m -Djava.security.egd=file:/dev/./urandom -jar /usr/share/selenium/selenium-server-standalone.jar -port 4444 -browserTimeout 120 &
SELENIUM_PID=$!

wait
