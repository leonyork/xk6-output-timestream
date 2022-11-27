export AWS_ACCESS_KEY_ID?=$(shell aws configure get default.aws_access_key_id)
export AWS_SECRET_ACCESS_KEY?=$(shell aws configure get default.aws_secret_access_key)

.PHONY: run-grafana
run-grafana:
	docker build --quiet -t grafana .
	docker run -p 3000:3000 -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e "GF_AUTH_ANONYMOUS_ENABLED=true" -e "GF_AUTH_ANONYMOUS_ORG_ROLE=Admin" -e "GF_AUTH_DISABLE_LOGIN_FORM=true" grafana

