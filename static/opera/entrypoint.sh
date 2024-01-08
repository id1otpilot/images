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

VERBOSE=${VERBOSE:-""}
DRIVER_ARGS=${DRIVER_ARGS:-""}
if [ -n "$VERBOSE" ]; then
    DRIVER_ARGS="$DRIVER_ARGS --verbose"
fi

clean() {
  if [ -n "$FILESERVER_PID" ]; then
    kill -TERM "$FILESERVER_PID"
  fi
  if [ -n "$CLIPBOARD_PID" ]; then
    kill -TERM "$CLIPBOARD_PID"
  fi
  if [ -n "$PULSE_PID" ]; then
    kill -TERM "$PULSE_PID"
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
  if [ -n "$X11VNC_PID" ]; then
    kill -TERM "$X11VNC_PID"
  fi
}

trap clean SIGINT SIGTERM

if env | grep -q ROOT_CA_; then
  mkdir -p $HOME/.pki/nssdb
  certutil -N --empty-password -d sql:$HOME/.pki/nssdb
  for e in $(env | grep ROOT_CA_ | sed -e 's/=.*$//'); do
    certname=$(echo -n $e | sed -e 's/ROOT_CA_//')
    echo ${!e} | base64 -d >/tmp/cert.pem
    certutil -A -n ${certname} -t "TC,C,T" -i /tmp/cert.pem -d sql:$HOME/.pki/nssdb
    if cat tmp/cert.pem | grep -q "PRIVATE KEY"; then
      PRIVATE_KEY_PASS=${PRIVATE_KEY_PASS:-\'\'}
      openssl pkcs12 -export -in /tmp/cert.pem -clcerts -nodes -out /tmp/key.p12 -passout pass:${PRIVATE_KEY_PASS} -passin pass:${PRIVATE_KEY_PASS}
      pk12util -d sql:$HOME/.pki/nssdb -i /tmp/key.p12 -W ${PRIVATE_KEY_PASS}
      rm /tmp/key.p12
    fi
    rm /tmp/cert.pem
  done
fi

/usr/bin/fileserver &
FILESERVER_PID=$!

DISPLAY=${DISPLAY} /usr/bin/clipboard &
CLIPBOARD_PID=$!

mkdir -p ~/pulse/.config/pulse
echo -n 'gIvST5iz2S0J1+JlXC1lD3HWvg61vDTV1xbmiGxZnjB6E3psXsjWUVQS4SRrch6rygQgtpw7qmghDFTaekt8qWiCjGvB0LNzQbvhfs1SFYDMakmIXuoqYoWFqTJ+GOXYByxpgCMylMKwpOoANEDePUCj36nwGaJNTNSjL8WBv+Bf3rJXqWnJ/43a0hUhmBBt28Dhiz6Yqowa83Y4iDRNJbxih6rB1vRNDKqRr/J9XJV+dOlM0dI+K6Vf5Ag+2LGZ3rc5sPVqgHgKK0mcNcsn+yCmO+XLQHD1K+QgL8RITs7nNeF1ikYPVgEYnc0CGzHTMvFR7JLgwL2gTXulCdwPbg=='| base64 -d>~/pulse/.config/pulse/cookie
HOME=$HOME/pulse pulseaudio --start --exit-idle-time=-1
HOME=$HOME/pulse pactl load-module module-native-protocol-tcp
PULSE_PID=$(ps --no-headers -C pulseaudio -o pid | sed -r 's/( )+//g')

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

DISPLAY="$DISPLAY" /usr/bin/operadriver --port=4444 --whitelisted-ips='' ${DRIVER_ARGS} &
DRIVER_PID=$!

wait
