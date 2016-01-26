FROM alpine
MAINTAINER kgorskowski@codemonauts.com
RUN apk add --update ruby ruby-dev curl ruby-rdoc ruby-irb && rm -rf /var/cache/apk/*
RUN gem update --system && gem install slack-notifier systemd_mon && curl -fsSL curl.haxx.se/ca/cacert.pem -o "$(ruby -ropenssl -e 'puts OpenSSL::X509::DEFAULT_CERT_FILE')"
CMD ["systemd_mon","/systemd_mon/systemd_mon.yml"]
