FROM ubuntu:15.04
RUN apt-get update && apt-get install -qy python-pip && pip install awscli  && rm -rf /var/lib/apt/lists/*
COPY copy-rds-snapshots.sh /
RUN chmod +x /*.sh
CMD ["/copy-rds-snapshots.sh"]
