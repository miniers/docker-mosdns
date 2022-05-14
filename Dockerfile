FROM golang:alpine AS build-cfst

ARG TARGETARCH
ARG BUILDARCH

ENV CGO_ENABLED="0"
ENV GOOS="linux"
ARG UPX_VERSION="3.96"

RUN apk add --update --no-cache git gcc curl && \
    git clone https://github.com/XIU2/CloudflareSpeedTest.git /CloudflareSpeedTest
RUN cd /CloudflareSpeedTest && \
    version=$(git describe --tags --long --always) && \
    echo "${version}" && \
    GOARCH=${TARGETARCH} go build -ldflags "-s -w -X main.version=${version}" -trimpath -o CloudflareSpeedTest
RUN target="${BUILDARCH}" && \
    curl -sSL https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-${target}_linux.tar.xz | tar xvJf - -C / && \
    cp -f /upx-${UPX_VERSION}-${target}_linux/upx /usr/bin/ && \
    /usr/bin/upx -9 -v /CloudflareSpeedTest/CloudflareSpeedTest

FROM golang:alpine AS build-mosdns

ARG TARGETARCH
ARG BUILDARCH

ENV CGO_ENABLED="0"
ENV GOOS="linux"
ARG UPX_VERSION="3.96"

RUN apk add --update --no-cache git gcc curl && \
    git clone https://github.com/IrineSistiana/mosdns.git /mosdns
RUN cd /mosdns && \
    version=$(git describe --tags --long --always) && \
    echo "${version}" && \
    GOARCH=${TARGETARCH} go build -ldflags "-s -w -X main.version=${version}" -trimpath -o mosdns
RUN target="${BUILDARCH}" && \
    curl -sSL https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-${target}_linux.tar.xz | tar xvJf - -C / && \
    cp -f /upx-${UPX_VERSION}-${target}_linux/upx /usr/bin/ && \
    /usr/bin/upx -9 -v /mosdns/mosdns


FROM alpine

ARG TARGETARCH

ARG S6_OVERLAY_VERSION=v2.2.0.3
ARG ALPINE_REPO=https://mirrors.aliyun.com
ENV TIMEZONE="Asia/Shanghai"
ENV GEO_CDN="cdn.jsdelivr.net"

RUN ver=$(cat /etc/alpine-release | awk -F '.' '{printf "%s.%s", $1, $2;}') \
    && repos=/etc/apk/repositories \
    && mv -f ${repos} ${repos}_bk \
    && echo "${ALPINE_REPO}/alpine/v${ver}/main" > ${repos} \
    && echo "${ALPINE_REPO}/alpine/v${ver}/community" >> ${repos} \
    && apk add --no-cache tzdata \
    && ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone 

# install s6
RUN apk add --update --no-cache curl && \
    target=${TARGETARCH} && \
    if [ "$TARGETARCH" = "arm64" ]; then target="arm"; fi && \
    curl -sSL https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-${target}.tar.gz \
    | tar xfz - -C / && \
    rm -rf /var/cache/apk/*

# install mosdns
COPY --from=build-mosdns /mosdns/mosdns /usr/bin/mosdns
COPY --from=build-cfst /CloudflareSpeedTest/CloudflareSpeedTest /usr/bin/CloudflareST
COPY --from=build-cfst /CloudflareSpeedTest/ip.txt /root/cfip.txt

RUN apk add --no-cache inotify-tools 

COPY root/ /


VOLUME ["/config"]

EXPOSE 53

ENTRYPOINT ["/init"]
