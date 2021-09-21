FROM golang:alpine

RUN apk --no-cache add jq bash curl git git-lfs

ADD entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
