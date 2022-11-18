export K6_VERSION=v0.40.0
export K6_LOCATION?=$(GOPATH)/bin/k6
REPO=github.com/leonyork/xk6-output-timestream
ENV=dev
IMAGE_NAME=k6

.PHONY: build
build:
	xk6 build $(K6_VERSION) --with xk6-output-timestream=$(CURDIR) --output $(K6_LOCATION)

.PHONY: test-unit
test-unit:
	go test

export K6_TIMESTREAM_DATABASE_NAME=dev-xk6-output-timestream-test
export K6_TIMESTREAM_TABLE_NAME=test
export K6_VUS=100
export K6_ITERATIONS=400

AWS_CONFIG_FILE?=$(HOME)/.aws
# If we're running inside a dev container, we're
# using the host's docker, and so need to mount
# the host's AWS config
ifneq ($(HOST_AWS_CONFIG_FILE),)
	AWS_CONFIG_FILE=$(HOST_AWS_CONFIG_FILE)
endif
TEST_IMAGE_NAME:=$(IMAGE_NAME)_test
.PHONY: test-integration
test-integration:
	docker build -t $(TEST_IMAGE_NAME) --build-arg K6_IMAGE=$(FULL_IMAGE_NAME) $(CURDIR)/test
	docker run -e K6_TIMESTREAM_DATABASE_NAME -e K6_TIMESTREAM_TABLE_NAME -e K6_VUS -e K6_ITERATIONS -v "$(AWS_CONFIG_FILE)":"/home/k6/.aws" $(TEST_IMAGE_NAME)
	go test ./test -count=1


INFRA_STACK_NAME:=dev-xk6-output-timestream-test
INFRA_STACK_PARAMETERS:="DatabaseName"="$(K6_TIMESTREAM_DATABASE_NAME)" \
	"TableName"="$(K6_TIMESTREAM_TABLE_NAME)"
INFRA_STACK_TAGS="Repo=$(REPO)" "Env=$(ENV)"
.PHONY: deploy-infra
deploy-infra:
	aws cloudformation deploy --template-file test/infra/cloudformation.yaml --stack-name $(INFRA_STACK_NAME) --tags $(INFRA_STACK_TAGS) --parameter-overrides $(INFRA_STACK_PARAMETERS)

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

# Format the code - will change your files
.PHONY: format
format: fmt prettier shfmt
	@echo Formatting complete

# Check the code - will fail if checks fail
.PHONY: check
check: prettier-check hadolint-check shfmt-check
	@echo Code checking complete

# Formatting with go fmt (golang)
.PHONY: fmt
fmt:
	golines -w .

# Formatting with prettier (json)
.PHONY: prettier
prettier:
	prettier --write .

.PHONY: prettier-check
prettier-check:
	@prettier --check .

# Formatting with hadolint (dockerfile)
.PHONY: hadolint-check
hadolint-check:
	@hadolint Dockerfile
	@echo Hadolint Passed

# Formatting with shfmt (shell scripts)
.PHONY: shfmt
shfmt:
	shfmt -l -w .

.PHONY: shfmt-check
shfmt-check:
	@shfmt -l -d .
	@echo shfmt Passed

# All pre-commit hooks
.PHONY: check-all
check-all:
	pre-commit run --all-files

#################################################
# Targets that are mainly run from CI
#################################################

.PHONY: pull-builder
pull-builder:
	-docker pull $(BUILDER_NAME)

CACHE_CMD=
ifneq ($(CACHE_NAME),)
	CACHE_CMD=--cache-from $(CACHE_NAME)
endif
BUILDER_TARGET=ci
.PHONY: build-builder
build-builder: 
	docker build --target $(BUILDER_TARGET) -t $(BUILDER_NAME) $(CACHE_CMD) .

.PHONY: push-builder
push-builder:
	docker push $(BUILDER_NAME)

# In Dockerhub the versions are without the leading 'v'
K6_VERSION_NO_V=$(subst v,,$(K6_VERSION))
FULL_IMAGE_NAME=$(IMAGE_NAME):$(K6_VERSION_NO_V)

VERSION=$(shell git tag -l --contains HEAD | grep '^v')
VERSION_NO_V=$(subst v,,$(VERSION))
ifneq ($(VERSION_NO_V),)
	FULL_IMAGE_NAME=$(IMAGE_NAME):$(K6_VERSION_NO_V)-timestream$(VERSION_NO_V)
endif
.PHONY: build-image
build-image: 
	docker build --target k6 --build-arg K6_VERSION=$(K6_VERSION_NO_V) --build-arg VERSION=$(VERSION) -t $(FULL_IMAGE_NAME) $(CACHE_CMD) .

.PHONY: push-image
push-image:
	docker push $(FULL_IMAGE_NAME)

.PHONY: image-name
image-name:
	@echo $(FULL_IMAGE_NAME)

.PHONY: update-changelog
update-changelog:
	echo '\nTo pull the image for this release, run\n\n`docker pull $(FULL_IMAGE_NAME)`' >> CHANGELOG.md

.PHONY: copy-k6-from-image
copy-k6-from-image:
	docker cp $$(docker create --name tc $(FULL_IMAGE_NAME)):/usr/bin/k6 $(K6_LOCATION)
	docker rm tc

.PHONY: tag-cached-image
tag-cached-image:
	docker tag $(CACHE_NAME) $(FULL_IMAGE_NAME)

# Tags the repo
# See https://upliftci.dev/
.PHONY: release-tag
release-tag:
	uplift release --skip-changelog

.PHONY: release-go
release-go:
	GOPROXY=proxy.golang.org go list -m github.com/leonyork/xk6-output-timestream@$(VERSION)

.PHONY: changelog
changelog:
	uplift changelog --no-stage --no-push

.PHONY: release-github
release-github:
	gh release create $(VERSION) \
    '$(K6_LOCATION)#K6 x86_64 executable with timestream' \
    -F CHANGELOG.md
