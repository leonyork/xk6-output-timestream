export K6_VUS?=100
export K6_ITERATIONS?=400

export AWS_CONFIG_FILE?=$(HOME)/.aws
# If we're running inside a dev container, we're
# using the host's docker, and so need to mount
# the host's AWS config
ifneq ($(HOST_AWS_CONFIG_FILE),)
	export AWS_CONFIG_FILE=$(HOST_AWS_CONFIG_FILE)
endif
export AWS_ACCESS_KEY_ID?=$(shell aws configure get default.aws_access_key_id)
export AWS_SECRET_ACCESS_KEY?=$(shell aws configure get default.aws_secret_access_key)
export AWS_SESSION_TOKEN?=$(shell aws configure get default.aws_session_token)
export AWS_REGION?=$(shell aws configure get default.region )

TEST_IMAGE_NAME:=$(IMAGE_NAME)_test
FIXTURE_BUILD_ARGS:=--build-arg K6_IMAGE=$(FULL_IMAGE_NAME)
DOCKER_AWS_ARGS:=-e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION -e AWS_REGION -e AWS_ROLE_ARN -e AWS_ROLE_SESSION_NAME -e AWS_SESSION_TOKEN
DOCKER_K6_ARGS:=-e K6_TIMESTREAM_REGION -e K6_TIMESTREAM_DATABASE_NAME -e K6_TIMESTREAM_TABLE_NAME -e K6_VUS -e K6_ITERATIONS
export TEST_ID=$(shell date +%s)
.PHONY: test
test:
	docker compose build $(FIXTURE_BUILD_ARGS)
	docker compose up --exit-code-from test
	docker build -t $(TEST_IMAGE_NAME) --quiet .
	@echo $$TEST_ID
	docker run $(DOCKER_AWS_ARGS) $(DOCKER_K6_ARGS) -e TEST_ID -v "$(AWS_CONFIG_FILE)":"/root/.aws" $(TEST_IMAGE_NAME)
