# renovate: datasource=docker depName=loadimpact/k6 versioning=docker
ARG K6_VERSION=0.43.1

#################################################
# Basic environment for building the app
#################################################
FROM golang:1.20.3-bullseye AS builder

# renovate: datasource=go depName=go.k6.io/xk6
ARG XK6_VERSION=v0.9.1
ENV XK6_VERSION=${XK6_VERSION}
RUN go install go.k6.io/xk6/cmd/xk6@"${XK6_VERSION}"

#################################################
# Used for development and CI. Any development
# specific customisations should go in
# .devcontainer. Only tools needed to check
# and test the code in CI should be added here
#################################################
FROM builder AS ci

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Docker CLI for integration tests

# renovate: datasource=repology depName=debian_11/gnupg2 versioning=loose
ARG GNUPG_VERSION=2.2.27
ENV GNUPG_VERSION=${GNUPG_VERSION}

# renovate: datasource=repology depName=debian_11/lsb versioning=loose
ARG LSB_VERSION=11.1.0
ENV LSB_VERSION=${LSB_VERSION}

# renovate: datasource=docker depName=docker versioning=docker
ARG DOCKER_VERSION=23.0.4
ENV DOCKER_VERSION=${DOCKER_VERSION}

# docker-compose for running integration tests
# renovate: datasource=github-releases depName=docker/compose
ARG DOCKER_COMPOSE_PLUGIN_VERSION=2.17.2
ENV DOCKER_COMPOSE_PLUGIN_VERSION=${DOCKER_COMPOSE_PLUGIN_VERSION}

RUN apt-get update \ 
  && apt-get install -y \
  gnupg=${GNUPG_VERSION}* \
  lsb-release=${LSB_VERSION} \
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
  docker-ce-cli=5:${DOCKER_VERSION}* \
  docker-compose-plugin=${DOCKER_COMPOSE_PLUGIN_VERSION}* \
  --no-install-recommends \
  && apt-get clean

# AWS CLI for integration tests

# renovate: datasource=repology depName=debian_11/unzip versioning=loose
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

# renovate: datasource=github-releases depName=hadolint/hadolint
ARG HADOLINT_VERSION=v2.12.0
ENV HADOLINT_VERSION=${HADOLINT_VERSION}

RUN curl -fsSL \
  "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
  -o /usr/local/bin/hadolint \
  && chmod +x /usr/local/bin/hadolint

# shfmt for formatting shell scripts
# & golines for formatting go files

# renovate: datasource=go depName=mvdan.cc/sh/v3
ARG SHFMT_VERSION=v3.6.0
ENV SHFMT_VERSION=${SHFMT_VERSION}

# renovate: datasource=go depName=github.com/segmentio/golines
ARG GOLINES_VERSION=v0.11.0
ENV GOLINES_VERSION=${GOLINES_VERSION}

RUN go install mvdan.cc/sh/v3/cmd/shfmt@${SHFMT_VERSION} \
  && go install github.com/segmentio/golines@${GOLINES_VERSION}

# Node for prettier

# renovate: datasource=repology depName=debian_11/less versioning=loose
ARG LESS_VERSION=551
ENV LESS_VERSION=${LESS_VERSION}

# renovate: datasource=github-tags depName=nodejs/node extractVersion=^v(?<version>.*)$
ARG NODE_VERSION=20.0.0
ENV NODE_VERSION=${NODE_VERSION}

# hadolint ignore=DL3009
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION%.*.*}.x \
  | bash - \
  && apt-get update \
  && apt-get install -y \
  less=${LESS_VERSION}* \
  nodejs=${NODE_VERSION}* \
  --no-install-recommends \
  && apt-get clean

# Prettier for formatting
# renovate: datasource=npm depName=prettier
ARG PRETTIER_VERSION=2.8.8
ENV PRETTIER_VERSION=${PRETTIER_VERSION}
RUN npm install --global prettier@${PRETTIER_VERSION}

# uplift for creating versions from conventional commits
# renovate: datasource=github-releases depName=gembaadvantage/uplift
ARG UPLIFT_VERSION=v2.21.0
ENV UPLIFT_VERSION=${UPLIFT_VERSION}
RUN curl -fsSL https://raw.githubusercontent.com/gembaadvantage/uplift/main/scripts/install \
  | bash -s -- -v ${UPLIFT_VERSION} --no-sudo


#################################################
# Build k6 with the extension
#################################################

FROM builder AS build
ARG K6_VERSION=$K6_VERSION

WORKDIR /app
COPY . .
RUN make K6_VERSION=$K6_VERSION build


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