#################################################
# Basic environment for building the app
#################################################
FROM golang:1.19.3-buster AS builder

RUN apt-get update \ 
  && apt-get install -y \
  unzip=6.0-23+deb10u3 \
  --no-install-recommends \
  && apt-get clean \
  && curl -fsSL \
  "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" \
  -o "awscli.zip" \
  && unzip awscli.zip \
  && ./aws/install \
  && rm -f awscli.zip \
  && rm -rf ./aws

RUN go install go.k6.io/xk6/cmd/xk6@v0.7.0


#################################################
# Used for development and CI. Any development
# specific customisations should go in
# .devcontainer. Only tools needed to check
# the code in CI should be added here
#################################################
FROM builder AS dev

RUN curl -fsSL \
  https://github.com/hadolint/hadolint/releases/download/v2.10.0/hadolint-Linux-x86_64 \
  -o /usr/local/bin/hadolint \
  && chmod +x /usr/local/bin/hadolint

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
