IMAGE_NAME=grafana-oss
# renovate: datasource=docker depName=grafana/grafana-oss versioning=docker
GRAFANA_VERSION:=10.3.1
FULL_IMAGE_NAME=$(IMAGE_NAME):$(GRAFANA_VERSION)
DOCKER_AWS_ARGS:=-e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION -e AWS_REGION=$(shell aws configure get region) -e AWS_ROLE_ARN -e AWS_ROLE_SESSION_NAME -e AWS_SESSION_TOKEN
DOCKER_GRAFANA_ARGS:=-e "GF_AUTH_ANONYMOUS_ENABLED=true" -e "GF_AUTH_ANONYMOUS_ORG_ROLE=Admin" -e "GF_AUTH_DISABLE_LOGIN_FORM=true"

VERSION=$(shell git tag -l --contains HEAD | grep '^v')
VERSION_NO_V=$(subst v,,$(VERSION))
ifneq ($(VERSION_NO_V),)
	FULL_IMAGE_NAME=$(IMAGE_NAME):$(GRAFANA_VERSION)-timestream$(VERSION_NO_V)
endif
.PHONY: build
build:
	docker build --build-arg GRAFANA_VERSION=$(GRAFANA_VERSION) --quiet -t $(FULL_IMAGE_NAME) .

.PHONY: run
run:
	docker run -p 3000:3000 $(DOCKER_AWS_ARGS) $(DOCKER_GRAFANA_ARGS) $(FULL_IMAGE_NAME)

.PHONY: push-image
push-image:
	docker push $(FULL_IMAGE_NAME)

.PHONY: image-name
image-name:
	@echo $(FULL_IMAGE_NAME)

.PHONY: tag-cached-image
tag-cached-image:
	docker tag $(CACHE_NAME) $(FULL_IMAGE_NAME)

CHANGELOG_LOCATION=../CHANGELOG.md
.PHONY: update-changelog
update-changelog:
	echo '\nTo pull the example grafana image for this release, run\n\n`docker pull $(FULL_IMAGE_NAME)`' >> $(CHANGELOG_LOCATION)