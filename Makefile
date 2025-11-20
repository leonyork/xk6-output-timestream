# renovate: datasource=docker depName=grafana/k6 versioning=docker
K6_VERSION=1.4.1
export K6_LOCATION?=$(GOPATH)/bin/k6
REPO=github.com/leonyork/xk6-output-timestream
ENV?=dev
export IMAGE_NAME=k6

.PHONY: all
all: build test-unit pre-commit build-image deploy-infra test-integration destroy-infra

.PHONY: build
build:
	mkdir -p dist
	xk6 build --with xk6-output-timestream=$(CURDIR) --output $(K6_DIST_LOCATION) v$(K6_VERSION)

.PHONY: test-unit
test-unit:
	go test

export K6_TIMESTREAM_DATABASE_NAME?=dev-xk6-output-timestream-test
export K6_TIMESTREAM_TABLE_NAME?=test
.PHONY: test-integration
test-integration:
	make -C test test

INFRA_STACK_NAME?=dev-xk6-output-timestream-test
INFRA_STACK_PARAMETERS="DatabaseName"="$(K6_TIMESTREAM_DATABASE_NAME)" \
	"TableName"="$(K6_TIMESTREAM_TABLE_NAME)"
INFRA_STACK_TAGS="Repo=$(REPO)" "Env=$(ENV)"

ifneq ($(INFRA_ROLE_ARN),)
	ROLE_ARN_ARG=--role-arn $(INFRA_ROLE_ARN)
endif
.PHONY: deploy-infra
deploy-infra:
	aws cloudformation deploy --template-file test/infra/cloudformation.yaml --stack-name $(INFRA_STACK_NAME) --tags $(INFRA_STACK_TAGS) --parameter-overrides $(INFRA_STACK_PARAMETERS) $(ROLE_ARN_ARG)

.PHONY: destroy-infra
destroy-infra:
	aws cloudformation delete-stack --stack-name $(INFRA_STACK_NAME)
	aws cloudformation wait stack-delete-complete --stack-name $(INFRA_STACK_NAME)


#################################################
# Dev tooling (including code formatting
# + checking)
#################################################

# Init development mode - ensures code is in a
# good state when commiting.
.PHONY: init-dev
init-dev:
	pre-commit install

.PHONY: pre-commit
pre-commit:
	pre-commit run --all-files

VERSION=$(shell git tag -l --contains HEAD | grep '^v')
VERSION_NO_V=$(subst v,,$(VERSION))
ifneq ($(VERSION_NO_V),)
	export FULL_IMAGE_NAME?=$(IMAGE_NAME):$(K6_VERSION)-timestream$(VERSION_NO_V)
else
	# In Dockerhub the versions are without the leading 'v'
	export FULL_IMAGE_NAME?=$(IMAGE_NAME):$(K6_VERSION)
endif
DOCKER_BUILD_CMD=build
ifneq ($(GOOS),)
ifneq ($(GOARCH),)
	PLATFORM_ARG=--platform $(GOOS)/$(GOARCH)
	EXTRA_ARGS=$(PLATFORM_ARG) --load
	DOCKER_BUILD_CMD=buildx build
endif
endif
K6_DIST_LOCATION?=dist/k6
.PHONY: build-image
build-image: build
	$(MAKE) K6_LOCATION=$(K6_DIST_LOCATION) build
	docker $(DOCKER_BUILD_CMD) --target k6 --build-arg K6_VERSION=$(K6_VERSION) --build-arg VERSION=$(VERSION) --build-arg K6_HOST_LOCATION=$(K6_DIST_LOCATION) $(EXTRA_ARGS) -t $(FULL_IMAGE_NAME) $(CACHE_CMD) .

.PHONY: push-image
push-image:
	docker push $(FULL_IMAGE_NAME)

.PHONY: image-name
image-name:
	@echo $(FULL_IMAGE_NAME)

.PHONY: update-changelog
update-changelog:
	echo '\nTo pull the image for this release, run\n\n`docker pull $(FULL_IMAGE_NAME)`' >> CHANGELOG.md

.PHONY: retag-image
retag-image:
	docker buildx imagetools create -t $(FULL_IMAGE_NAME) $(CACHE_NAME)

.PHONY: release-go
release-go:
	GOPROXY=proxy.golang.org go list -m $(REPO)@$(VERSION)

#################################################
# Example grafana setup
# Run `make grafana-{target}` to run any of the
# targets in ./grafana/Makefile
# e.g. `make grafana-build`
#################################################

GRAFANA_ARGS:=K6_TIMESTREAM_DATABASE_NAME=$(K6_TIMESTREAM_DATABASE_NAME) \
	K6_TIMESTREAM_TABLE_NAME=$(K6_TIMESTREAM_TABLE_NAME) \
	$(if $(GRAFANA_IMAGE_NAME),IMAGE_NAME=$(GRAFANA_IMAGE_NAME),) \
	$(if $(GRAFANA_FULL_IMAGE_NAME),FULL_IMAGE_NAME=$(GRAFANA_FULL_IMAGE_NAME),) \
	$(if $(CACHE_NAME),CACHE_NAME=$(CACHE_NAME),) \
	VERSION=$(VERSION)

.PHONY: grafana-%
grafana-%:
	make $(GRAFANA_ARGS) -C grafana $*
