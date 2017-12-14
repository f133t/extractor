
FROM f133t/fleet-base:latest

COPY ./ /opt/extractor

WORKDIR /opt/extractor

RUN \
  sudo chown -R ubuntu:ubuntu /opt/extractor

USER ubuntu

RUN bundle install

ENTRYPOINT [".docker/docker-entrypoint.sh"]
