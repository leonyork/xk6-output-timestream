IMAGE_NAME=grafana-oss
# renovate: datasource=docker depName=grafana/grafana-oss versioning=docker
GRAFANA_VERSION:=9.5.1
FULL_IMAGE_NAME=$(IMAGE_NAME):$(GRAFANA_VERSION)

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
	@docker run -p 3000:3000 -e AWS_ACCESS_KEY_ID=$(shell aws configure get default.aws_access_key_id) -e AWS_SECRET_ACCESS_KEY=$(shell aws configure get default.aws_secret_access_key) -e "GF_AUTH_ANONYMOUS_ENABLED=true" -e "GF_AUTH_ANONYMOUS_ORG_ROLE=Admin" -e "GF_AUTH_DISABLE_LOGIN_FORM=true" $(FULL_IMAGE_NAME)

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