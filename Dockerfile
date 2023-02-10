ARG K6_VERSION=0.42.0

#################################################
# Basic environment for building the app
#################################################
FROM golang:1.20.0-bullseye AS builder

RUN go install go.k6.io/xk6/cmd/xk6@v0.8.1


#################################################
# Used for development and CI. Any development
# specific customisations should go in
# .devcontainer. Only tools needed to check
# and test the code in CI should be added here
#################################################
FROM builder AS ci

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Docker CLI for integration tests
RUN apt-get update \ 
  && apt-get install -y \
  gnupg=2.2.27-2+deb11u2 \
  lsb-release=11.1.0 \
  --no-install-recommends \
  && mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/debian/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list >/dev/null \
  && apt-get update \
  && apt-get install -y \
  docker-ce-cli=5:20.10.23~3-0~debian-bullseye \
  --no-install-recommends \
  && apt-get clean

# AWS CLI for integration tests
RUN apt-get update \ 
  && apt-get install -y \
  unzip=6.0-26+deb11u1 \
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
RUN curl -fsSL \
  https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64 \
  -o /usr/local/bin/hadolint \
  && chmod +x /usr/local/bin/hadolint

# shfmt for formatting shell scripts
# & golines for formatting go files
RUN go install mvdan.cc/sh/v3/cmd/shfmt@v3.6.0 \
  && go install github.com/segmentio/golines@v0.11.0

# Node for prettier
# hadolint ignore=DL3009
RUN curl -fsSL https://deb.nodesource.com/setup_18.x \
  | bash - \
  && apt-get update \
  && apt-get install -y \
  less=551-2 \
  nodejs=18.14.0-deb-1nodesource1 \
  --no-install-recommends \
  && apt-get clean

# Prettier for formatting
RUN npm install --global prettier@2.8.3

# uplift for creating versions from conventional commits
RUN curl -fsSL https://raw.githubusercontent.com/gembaadvantage/uplift/main/scripts/install \
  | bash -s -- -v v2.21.0 --no-sudo


#################################################
# Build k6 with the extension
#################################################

FROM builder AS build
ARG K6_VERSION=$K6_VERSION

WORKDIR /app
COPY . .
RUN make K6_VERSION=v$K6_VERSION build


#################################################
# "Update" the k6 official image
#################################################

FROM loadimpact/k6:$K6_VERSION AS k6
ARG K6_VERSION=$K6_VERSION
ARG VERSION=$VERSION

ENV K6_LOCATION=/usr/bin/k6
ENV K6_VERSION=v$K6_VERSION
ENV XK6_OUTPUT_TIMESTREAM_VERSION=$VERSION

COPY --from=build /go/bin/k6 $K6_LOCATION