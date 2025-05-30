FROM docker:28.2.1-cli AS docker-cli

FROM ubuntu:plucky-20250415

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/libexec/docker/cli-plugins/docker-buildx
RUN docker buildx install
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/libexec/docker/cli-plugins/docker-compose

# renovate: datasource=repology depName=ubuntu_25_04/ca-certificates versioning=loose
ARG CA_CERTIFICATES_VERSION=20241223
ENV CA_CERTIFICATES_VERSION=${CA_CERTIFICATES_VERSION}

# renovate: datasource=repology depName=ubuntu_25_04/git
ARG GIT_VERSION=2.48.1
ENV GIT_VERSION=${GIT_VERSION}

# nix is a virtual package so has no version
# hadolint ignore=DL3008
RUN apt-get update -y \
  && apt-get -y install --no-install-recommends \
  ca-certificates=${CA_CERTIFICATES_VERSION}* \
  git=1:${GIT_VERSION}* \
  nix \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /etc/nix \
  && mkdir -p /tmp

COPY nix.conf /etc/nix/nix.conf

ENV USER=root
