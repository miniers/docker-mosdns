FROM alpine AS build-mosdns

COPY release.py /
RUN apk add --update --no-cache git python3 go upx && \
    git clone https://github.com/IrineSistiana/mosdns.git && \
    cp -f /release.py /mosdns/ && \
    cd mosdns && \
    python3 release.py


FROM alpine

ARG S6_OVERLAY_VERSION=v2.1.0.2

ARG ALPINE_REPO=https://mirrors.aliyun.com
ENV TIMEZONE="Asia/Shanghai"

RUN ver=$(cat /etc/alpine-release | awk -F '.' '{printf "%s.%s", $1, $2;}') \
    && repos=/etc/apk/repositories \
    && mv -f ${repos} ${repos}_bk \
    && echo "${ALPINE_REPO}/alpine/v${ver}/main" > ${repos} \
    && echo "${ALPINE_REPO}/alpine/v${ver}/community" >> ${repos} \
    # && echo "@edge ${URL_PREFIX}${ALPINE_REPO}/alpine/edge/main" >> ${repos} \
    # && echo "@testing ${URL_PREFIX}${ALPINE_REPO}/alpine/edge/testing" >> ${repos} \
    && apk add --no-cache tzdata \
    && ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone 

# install s6
RUN apk add --update --no-cache curl vim && \
    curl -sSL https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-amd64.tar.gz \
    | tar xfz - -C / && \
    rm -rf /var/cache/apk/*

# install mosdns
COPY --from=build-mosdns /mosdns/release/mosdns /usr/bin/mosdns

RUN apk add --no-cache inotify-tools 

COPY root/ /


VOLUME ["/config"]

EXPOSE 53

ENTRYPOINT ["/init"]
