.PHONY: build
export K6_VERSION=v0.40.0
build:
	xk6 build --with xk6-output-timestream=$(CURDIR) --output $$GOPATH/bin/k6

.PHONY: test-unit
test-unit:
	go test


K6_TIMESTREAM_DATABASE_NAME=test
K6_TIMESTREAM_TABLE_NAME=test
K6_USER_COUNT=2
K6_ITERATIONS=4

K6_TEST_CMD=K6_TIMESTREAM_DATABASE_NAME=$(K6_TIMESTREAM_DATABASE_NAME) \
	K6_TIMESTREAM_TABLE_NAME=$(K6_TIMESTREAM_TABLE_NAME) \
	k6 run test/test.js \
	-u $(K6_USER_COUNT) \
	-i $(K6_ITERATIONS) \
	-o timestream \
	--verbose
.PHONY: test-integration
test-integration: build
	$(K6_TEST_CMD)

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
.PHONY: build-builder
build-builder: 
	docker build -t $(BUILDER_NAME) $(CACHE_CMD) .

.PHONY: push-builder
push-builder:
	docker push $(BUILDER_NAME)

# Tags the repo
# See https://upliftci.dev/
.PHONY: release-tag
release-tag:
	uplift release --skip-changelog

VERSION=$(shell git tag -l --contains HEAD | grep '^v')
.PHONY: release-go
release-go:
	GOPROXY=proxy.golang.org go list -m github.com/leonyork/xk6-output-timestream@$(VERSION)

.PHONY: changelog
changelog:
	uplift changelog --no-stage --no-push
