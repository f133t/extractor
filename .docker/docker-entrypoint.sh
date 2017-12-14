#!/bin/bash

set -eui

export RAILS_ENV=${RAILS_ENV:-development}
export AUTO_START=${AUTO_START_EXTRACTOR:-false}

while ! ( echo -e "$REDIS_PORT" | xargs -i nc -w 1 -zv $REDIS_HOSTNAME {} ) ; do
  echo "Waiting for redis to come up at '$REDIS_HOSTNAME:$REDIS_PORT'..."
  sleep 5
done

if [ $RAILS_ENV == "development" ]; then
  bundle
fi

echo "------------------- $(pwd) UP ------------------"

if [ $AUTO_START == "true" ]; then
  foreman start
else
  tail -f /dev/null
fi
