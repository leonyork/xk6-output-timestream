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

pull-builder:
	-docker pull $(BUILDER_NAME)
.PHONY: pull-builder

CACHE_CMD=
ifneq ($(CACHE_NAME),)
	CACHE_CMD=--cache-from $(CACHE_NAME)
endif
build-builder: 
	docker build -t $(BUILDER_NAME) $(CACHE_CMD) .
.PHONY: build-builder

push-builder:
	docker push $(BUILDER_NAME)
.PHONY: push-builder