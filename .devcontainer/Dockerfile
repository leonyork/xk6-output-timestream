# syntax=docker/dockerfile:1

# renovate: datasource=docker depName=grafana/k6 versioning=docker
ARG K6_VERSION=1.0.0

#################################################
# Basic environment for building the app
#################################################
FROM golang:1.24.3-bookworm AS builder

# renovate: datasource=go depName=go.k6.io/xk6
ARG XK6_VERSION=v0.20.1
ENV XK6_VERSION=${XK6_VERSION}
RUN go install go.k6.io/xk6/cmd/xk6@"${XK6_VERSION}"

# Docker CLI for integration tests
FROM docker:28.1.1-cli AS docker-cli

# Node for tooling
FROM node:22.16.0-bookworm-slim AS node

# Hadolint for formatting Dockerfiles
FROM hadolint/hadolint:v2.12.0-debian AS hadolint

# Golangci-lint for linting Go
FROM golangci/golangci-lint:v2.1.6 AS golangci-lint

#################################################
# Used for development and CI. Any development
# specific customisations should go in
# .devcontainer. Only tools needed to check
# and test the code in CI should be added here
#################################################
FROM builder AS ci

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/libexec/docker/cli-plugins/docker-buildx
RUN docker buildx install
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/libexec/docker/cli-plugins/docker-compose
COPY --from=node /usr/local/bin /usr/local/bin
COPY --from=node /usr/local/lib /usr/local/lib

# renovate: datasource=repology depName=debian_12/unzip versioning=loose
ARG UNZIP_VERSION=6.0
ENV UNZIP_VERSION=${UNZIP_VERSION}

RUN apt-get update \ 
  && apt-get install -y \
  unzip=${UNZIP_VERSION}* \
  --no-install-recommends \
  && apt-get clean \
  && curl -fsSL \
  "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" \
  -o "awscli.zip" \
  && unzip -q awscli.zip \
  && ./aws/install \
  && rm -f awscli.zip \
  && rm -rf ./aws

# Hadolint for linting Dockerfile
COPY --from=hadolint /bin/hadolint /usr/local/bin/hadolint

# Golangci-lint for linting Go
COPY --from=golangci-lint /usr/bin/golangci-lint /usr/bin/golangci-lint

# shfmt for formatting shell scripts

# renovate: datasource=go depName=mvdan.cc/sh/v3
ARG SHFMT_VERSION=v3.11.0
ENV SHFMT_VERSION=${SHFMT_VERSION}

RUN go install mvdan.cc/sh/v3/cmd/shfmt@${SHFMT_VERSION}

# renovate: datasource=repology depName=debian_12/less versioning=loose
ARG LESS_VERSION=590
ENV LESS_VERSION=${LESS_VERSION}

# hadolint ignore=DL3009
RUN apt-get update \
  && apt-get install -y \
  less=${LESS_VERSION}* \
  --no-install-recommends \
  && apt-get clean

# Prettier for formatting
# renovate: datasource=npm depName=prettier
ARG PRETTIER_VERSION=3.5.3
ENV PRETTIER_VERSION=${PRETTIER_VERSION}
RUN npm install --global prettier@${PRETTIER_VERSION}

# uplift for creating versions from conventional commits
# renovate: datasource=github-releases depName=gembaadvantage/uplift
ARG UPLIFT_VERSION=v2.25.0
ENV UPLIFT_VERSION=${UPLIFT_VERSION}
RUN curl -fsSL https://raw.githubusercontent.com/gembaadvantage/uplift/main/scripts/install \
  | bash -s -- -v ${UPLIFT_VERSION} --no-sudo

ENTRYPOINT ["/bin/bash", "-e", "-o", "pipefail", "-c"]
