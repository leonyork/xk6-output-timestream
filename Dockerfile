# syntax=docker/dockerfile:1

# renovate: datasource=docker depName=grafana/k6 versioning=docker
ARG K6_VERSION=0.55.2

FROM grafana/k6:$K6_VERSION AS k6
ARG K6_HOST_LOCATION=/go/bin/k6
ARG K6_VERSION=$K6_VERSION
ARG VERSION=$VERSION

ENV K6_LOCATION=/usr/bin/k6
ENV K6_VERSION=v$K6_VERSION
ENV XK6_OUTPUT_TIMESTREAM_VERSION=$VERSION

COPY $K6_HOST_LOCATION $K6_LOCATION
