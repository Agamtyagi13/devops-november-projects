ENV ?= dev
BUCKET ?= $(shell cd bootstrap && terraform output -raw state_bucket)
fmt:; terraform fmt -recursive
scan:; checkov -d . --config-file .checkov.yaml || tfsec .
init:; cd envs/$(ENV) && terraform init -backend-config="bucket=$(BUCKET)"
plan: init; cd envs/$(ENV) && terraform plan
apply: init; cd envs/$(ENV) && terraform apply
destroy: init; cd envs/$(ENV) && terraform destroy
