# syntax=docker/dockerfile:1

## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.19 as buildstage

RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    git go && \
  echo "**** git  clone sequence ****" && \
  mkdir -p /root-layer && \
  cd /root-layer && \
  git clone https://github.com/ccin2p3/sequence && \
  echo "**** start building sequence ****" && \
  cd sequence/ && \
  echo "**** applying patch ****" && \
  go mod edit -replace="github.com/mattn/go-sqlite3=github.com/leso-kn/go-sqlite3@v0.0.0-20230710125852-03158dc838ed" && \
  go mod tidy && \
  echo "**** build ****" && \
  go build && \
  cd cmd/sequence_db/ && \
  go build && \
  echo "**** creating initial sequence db ****" && \
  cd /root-layer/sequence/ && \
  /root-layer/sequence/cmd/sequence_db/sequence_db createdatabase -l /dev/stderr -n info --conn sequence.sdb --type sqlite3 && \
  echo "**** creating initial sequence config ****" && \
  sed -i 's/connectioninfo = "sequence.sdb"/connectioninfo = "\/etc\/sequence\/sequence.sdb"/g' sequence.toml && \
  touch sequence.xml

# copy local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="takalele"

# Add files from buildstage
COPY --from=buildstage /root-layer/sequence/cmd/sequence_db/sequence_db /usr/local/bin/sequence
COPY --from=buildstage /root-layer/sequence/sequence.sdb /etc/syslog-ng/conf.d/sequence.sdb
COPY --from=buildstage /root-layer/sequence/sequence.toml /etc/sequence/sequence.toml
COPY --from=buildstage /root-layer/sequence/sequence.xml /var/lib/syslog-ng/sequence.xml