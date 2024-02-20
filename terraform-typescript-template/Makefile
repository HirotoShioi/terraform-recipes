.PHONY: apply destroy output help

help:
	@echo "Please use \`make <target>' where <target> is one of"
	@echo "  apply       to apply changes"
	@echo "  destroy     to destroy changes"
	@echo "  output      to get output"
	@echo "  init        to init terraform and install npm dependencies"

init:
	@echo "Init terraform"
	@cd terraform && terraform init
	@echo "Install npm dependencies"
	@npm install

apply:
	@echo "Build Lambda"
	@rm -rf dist
	@node esbuild.config.js
	@echo "Apply changes"
	@cd terraform && terraform apply

destroy:
	@echo "Destroy changes"
	@cd terraform && terraform destroy

output:
	@echo "Get output"
	@cd terraform && terraform output
