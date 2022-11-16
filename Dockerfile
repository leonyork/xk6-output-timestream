ARG K6_VERSION=0.40.0

#################################################
# Basic environment for building the app
#################################################
FROM golang:1.19.3-buster AS builder

RUN go install go.k6.io/xk6/cmd/xk6@v0.8.1


#################################################
# Used for development and CI. Any development
# specific customisations should go in
# .devcontainer. Only tools needed to check
# and test the code in CI should be added here
#################################################
FROM builder AS ci

# AWS CLI for integration tests
RUN apt-get update \ 
  && apt-get install -y \
  unzip=6.0-23+deb10u3 \
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
  https://github.com/hadolint/hadolint/releases/download/v2.10.0/hadolint-Linux-x86_64 \
  -o /usr/local/bin/hadolint \
  && chmod +x /usr/local/bin/hadolint

# shfmt for formatting shell scripts
# & golines for formatting go files
RUN go install mvdan.cc/sh/v3/cmd/shfmt@v3.5.1 \
  && go install github.com/segmentio/golines@v0.9.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# Node for prettier
# hadolint ignore=DL3009
RUN curl -fsSL https://deb.nodesource.com/setup_18.x \
  | bash - \
  && apt-get update \
  && apt-get install -y \
  less=487-0.1+b1 \
  nodejs=18.12.1-deb-1nodesource1 \
  --no-install-recommends \
  && apt-get clean

# Prettier for formatting
RUN npm install --global prettier@2.7.1

# uplift for creating versions from conventional commits
RUN curl -fsSL https://raw.githubusercontent.com/gembaadvantage/uplift/main/scripts/install \
  | bash -s -- -v v2.18.1 --no-sudo


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