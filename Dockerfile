FROM node:20.11.0 AS FRONT
WORKDIR /web
COPY ./web .

ARG MODE
RUN if [ "$MODE" = "dev" ]; then \
      mv .env.development .env.local; \
    elif [ "$MODE" = "prod" ]; then \
      mv .env.production .env.local; \
    fi

RUN yarn install --frozen-lockfile --network-timeout 1000000 && yarn run build


FROM golang:1.20.12 AS BACK
WORKDIR /go/src/casdoor
COPY . .
# for windows bash to work, line-ending problems
RUN apt-get update && apt-get install -y dos2unix
RUN dos2unix build.sh && chmod +x build.sh
RUN ./build.sh
RUN go test -v -run TestGetVersionInfo ./util/system_test.go ./util/system.go > version_info.txt

FROM alpine:latest AS STANDARD
LABEL MAINTAINER="https://casdoor.org/"
ARG USER=casdoor
#ARG TARGETOS
#ARG TARGETARCH
#ENV BUILDX_ARCH="${TARGETOS:-linux}_${TARGETARCH:-amd64}"
#build the image for amd64 os, to run in aws node
#ENV BUILDX_ARCH="linux_amd64"
#build the image for apple chip
#ENV BUILDX_ARCH="linux_arm64"

RUN sed -i 's/https/http/' /etc/apk/repositories
RUN apk add --update sudo
RUN apk add curl
RUN apk add ca-certificates && update-ca-certificates

RUN adduser -D $USER -u 1000 \
    && echo "$USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER \
    && chmod 0440 /etc/sudoers.d/$USER \
    && mkdir logs \
    && chown -R $USER:$USER logs

USER 1000
WORKDIR /
COPY --from=BACK --chown=$USER:$USER /go/src/casdoor/server ./server
COPY --from=BACK --chown=$USER:$USER /go/src/casdoor/swagger ./swagger
COPY --from=BACK --chown=$USER:$USER /go/src/casdoor/conf/app.conf ./conf/app.conf
COPY --from=BACK --chown=$USER:$USER /go/src/casdoor/version_info.txt ./go/src/casdoor/version_info.txt
COPY --from=FRONT --chown=$USER:$USER /web/build ./web/build

ENTRYPOINT ["/server"]
#ENTRYPOINT ["/bin/bash"]
#CMD ["exec", "/server"]

# DEMO purpose, mysql db in docker
#FROM debian:latest AS db
#RUN apt update \
#    && apt install -y \
#        mariadb-server \
#        mariadb-client \
#    && rm -rf /var/lib/apt/lists/*
#
#
#FROM db AS ALLINONE
#LABEL MAINTAINER="https://casdoor.org/"
#ARG TARGETOS
#ARG TARGETARCH
#ENV BUILDX_ARCH="${TARGETOS:-linux}_${TARGETARCH:-amd64}"
#
#RUN apt update
#RUN apt install -y ca-certificates && update-ca-certificates
#
#WORKDIR /
#COPY --from=BACK /go/src/casdoor/server_${BUILDX_ARCH} ./server
#COPY --from=BACK /go/src/casdoor/swagger ./swagger
#COPY --from=BACK /go/src/casdoor/docker-entrypoint.sh /docker-entrypoint.sh
#COPY --from=BACK /go/src/casdoor/conf/app.conf ./conf/app.conf
#COPY --from=BACK /go/src/casdoor/version_info.txt ./go/src/casdoor/version_info.txt
#COPY --from=FRONT /web/build ./web/build
#
#ENTRYPOINT ["/bin/bash"]
#CMD ["/docker-entrypoint.sh"]
