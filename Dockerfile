FROM debian:bookworm-slim as builder
ARG VERSION

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    automake \
    build-essential \
    ca-certificates \
    git \
    libtool \
    make \
    pkg-config \
    # Icecast
    libcurl4-openssl-dev \
    libogg-dev \
    libspeex-dev \
    libssl-dev \
    libtheora-dev \
    libvorbis-dev \
    libxml2-dev \
    libxslt1-dev \
    libigloo-dev \
    librhash-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --recursive https://gitlab.xiph.org/xiph/icecast-server.git

WORKDIR /build/icecast-server

RUN ./autogen.sh

RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var

RUN make
RUN make install DESTDIR=/build/output

FROM debian:bookworm-slim

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    media-types \
    libcurl4 \
    libogg0 \
    libspeex1 \
    libssl3 \
    libtheora0 \
    libvorbis0a \
    libxml2  \
    libxslt1.1 \
    libigloo0 \
    tzdata \
    && rm -rf \
    /var/cache/* \
    /var/lib/apt/lists/* \
    /var/log/apt/* \
    /var/log/dpkg.log

ENV USER=icecast

ENV TZ=UTC

RUN adduser --disabled-password --gecos '' --no-create-home $USER

COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY ./xml-edit.sh /usr/local/bin/xml-edit
RUN chmod +x \
    /usr/local/bin/docker-entrypoint \
    /usr/local/bin/xml-edit

COPY --from=builder /build/output /
RUN xml-edit errorlog - /etc/icecast.xml

RUN mkdir -p /var/log/icecast && \
    chown $USER /etc/icecast.xml /var/log/icecast

COPY ./style.css /usr/share/icecast/web/assets/css/style.css 
COPY ./web /usr/share/icecast/web

EXPOSE 8000
ENTRYPOINT ["docker-entrypoint"]
USER $USER
CMD ["icecast", "-c", "/etc/icecast.xml"]
