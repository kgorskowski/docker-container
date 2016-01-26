#!/bin/sh
exec /opt/calibre/calibre-server --with-library /library --url-prefix /calibre --auto-reload --max-cover 300x400 --username $WEBAUTHUSER --password $WEBAUTHPASSWORD 2>&1
