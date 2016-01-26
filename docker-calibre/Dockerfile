FROM phusion/baseimage:0.9.18
RUN apt-get update && apt-get install -yq wget python xvfb imagemagick
RUN wget -nv -O- https://raw.githubusercontent.com/kovidgoyal/calibre/master/setup/linux-installer.py | sudo python -c "import sys; main=lambda:sys.stderr.write('Download failed\n'); exec(sys.stdin.read()); main()"
COPY calibre.sh /etc/service/calibre/run
RUN locale-gen de_DE.UTF-8
RUN chmod +x /etc/service/calibre/run
