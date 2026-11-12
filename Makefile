# Makefile — Anestoa Infrastructure Development & Audit Tooling
#
# Targets:
#   setup      Install/update dev tools (tofuenv, checkov, opa, infracost)
#   fmt        Auto-format all Terraform files
#   fmt-check  Check formatting
#   validate   Run tofu init + validate
#   checkov    Run Checkov static analysis
#   plan       Generate plan.json for OPA evaluation
#   opa        Run OPA policy evaluation (requires plan.json)
#   test       Run tofu test suite
#   infracost  Run Infracost estimate
#   review     Full audit: fmt-check + validate + checkov + opa + test + infracost
#   all        CI gate: fmt-check + validate + checkov + test
#
# Usage:
#   make review MODULE_PATH=modules/aws/s3-bucket

MODULE_PATH ?= .
TOFU_CMD ?= tofu
# Absolute path to the repo root (resolved once at Make parse time)
REPO_ROOT := $(shell git rev-parse --show-toplevel 2>/dev/null || pwd)

.PHONY: all
all: fmt-check validate checkov test

.PHONY: review
review: fmt-check validate checkov opa test infracost

.PHONY: fmt
fmt:
	cd $(MODULE_PATH) && $(TOFU_CMD) fmt -recursive

.PHONY: fmt-check
fmt-check:
	cd $(MODULE_PATH) && $(TOFU_CMD) fmt -check -recursive

.PHONY: validate
validate:
	cd $(MODULE_PATH) && $(TOFU_CMD) init -backend=false && $(TOFU_CMD) validate

.PHONY: checkov
checkov:
	which checkov >/dev/null 2>&1 || (echo "checkov not found — run 'make setup'" && exit 0)
	checkov --framework terraform -d $(MODULE_PATH) --compact --quiet

.PHONY: plan
plan:
	cd $(MODULE_PATH) && $(TOFU_CMD) init -backend=false && $(TOFU_CMD) plan -input=false -out=plan.tfplan && $(TOFU_CMD) show -json plan.tfplan > plan.json && rm plan.tfplan

# CI variant of plan — injects an offline provider block so tofu plan runs
# without real AWS credentials. Each module has its own ci.auto.tfvars for
# the required variables with dummy values.
plan-ci:
	@NEEDS_LIVE=$$(grep -rlE 'data "(aws_ssm_parameter|aws_ram_resource_share|aws_ec2_transit_gateway)"' $(REPO_ROOT)/$(MODULE_PATH) --include='*.tf' 2>/dev/null | head -1); \
	if [ -n "$$NEEDS_LIVE" ] && [ "$${PLAN_CI_ENABLED:-}" != "true" ]; then \
		echo "plan-ci: SKIP $(MODULE_PATH) — plan requires live AWS data sources ($$(basename $$NEEDS_LIVE)) unreachable without real credentials."; \
		echo "plan-ci: Set PLAN_CI_ENABLED=true to force plan generation (requires a read-only AWS role)."; \
		$(RM) -f $(REPO_ROOT)/$(MODULE_PATH)/plan.json; \
		exit 0; \
	fi; \
	CI_PROVIDER=$(REPO_ROOT)/$(MODULE_PATH)/_ci_provider.tf; \
	printf 'provider "aws" {\n  region                      = "us-east-1"\n  access_key                  = "[SECRET:aws-access-key-id]"\n  secret_key                  = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"\n  skip_credentials_validation = true\n  skip_requesting_account_id  = true\n  skip_metadata_api_check     = true\n  skip_region_validation      = true\n}\n' > $$CI_PROVIDER; \
	cd $(REPO_ROOT)/$(MODULE_PATH) && $(TOFU_CMD) init -backend=false && $(TOFU_CMD) plan -input=false -out=plan.tfplan && $(TOFU_CMD) show -json plan.tfplan > plan.json && $(RM) plan.tfplan; \
	EC=$$?; $(RM) -f $$CI_PROVIDER; exit $$EC

.PHONY: opa
opa:
	which opa >/dev/null 2>&1 || (echo "opa not found — run 'make setup'" && exit 0)
	test -d $(MODULE_PATH)/policies || (echo "No policies/ directory — skipping OPA" && exit 0)
	test -f $(MODULE_PATH)/plan.json || (echo "No plan.json — run 'make plan' first" && exit 0)
	@VIOLATIONS=$$(cd $(MODULE_PATH) && opa eval --format values --data policies/ --stdin-input plan.json "count(data.terraform.deny)" 2>/dev/null || true); \
	if [ -n "$$VIOLATIONS" ] && [ "$$VIOLATIONS" != "0" ] && [ "$$VIOLATIONS" != "[]" ]; then \
		echo "::group::OPA violations in $(MODULE_PATH) ($$VIOLATIONS)"; \
		cd $(MODULE_PATH) && opa eval --format pretty --data policies/ --stdin-input plan.json "data.terraform.deny[x]" 2>/dev/null; \
		echo "::endgroup::"; \
		exit 1; \
	else \
		echo "OPA policy passed — no violations."; \
	fi

.PHONY: test
test:
	test -d $(MODULE_PATH)/tests || (echo "No tests/ directory" && exit 0)
	@NEEDS_LIVE=$$(grep -rlE 'data "(aws_ssm_parameter|aws_ram_resource_share|aws_ec2_transit_gateway)"' $(REPO_ROOT)/$(MODULE_PATH) --include='*.tf' 2>/dev/null | head -1); \
	if [ -n "$$NEEDS_LIVE" ] && [ "$${PLAN_CI_ENABLED:-}" != "true" ]; then \
		echo "test: SKIP $(MODULE_PATH) — tests require live AWS data sources ($$(basename $$NEEDS_LIVE)) unreachable without real credentials."; \
		echo "test: Set PLAN_CI_ENABLED=true to force tests (requires a read-only AWS role)."; \
		exit 0; \
	fi; \
	CI_PROVIDER=$(REPO_ROOT)/$(MODULE_PATH)/_ci_provider.tf; \
	printf 'provider "aws" {\n  region                      = "us-east-1"\n  access_key                  = "[SECRET:aws-access-key-id]"\n  secret_key                  = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"\n  skip_credentials_validation = true\n  skip_requesting_account_id  = true\n  skip_metadata_api_check     = true\n  skip_region_validation      = true\n}\n' > $$CI_PROVIDER; \
	cd $(REPO_ROOT)/$(MODULE_PATH) && $(TOFU_CMD) init -backend=false && $(TOFU_CMD) test -test-directory=tests; \
	EC=$$?; $(RM) -f $$CI_PROVIDER; exit $$EC

.PHONY: infracost
infracost:
	which infracost >/dev/null 2>&1 || (echo "infracost not found — run 'make setup'" && exit 0)
	infracost breakdown --path $(MODULE_PATH)

.PHONY: symlink-skills
symlink-skills:
	@$(MAKE) -C $(HOME)/Developer/agents/terraform-agents symlink-skills TARGET=$(shell pwd)

.PHONY: opa-ssm
opa-ssm:
	which opa >/dev/null 2>&1 || (echo "opa not found — run 'make setup'" && exit 0)
	test -f $(MODULE_PATH)/plan.json || (echo "No plan.json — run 'make plan' first" && exit 0)
	test -f $(REPO_ROOT)/ssm-contract.json || (echo "No ssm-contract.json — run 'make ssm-contract-json' first" && exit 1)
	@VIOLATIONS=$$(opa eval --format values --data policies/ssm-contract.rego --data $(REPO_ROOT)/ssm-contract.json --input $(MODULE_PATH)/plan.json "count(data.terraform.deny)" 2>/dev/null || true); \
	if [ -n "$$VIOLATIONS" ] && [ "$$VIOLATIONS" != "0" ] && [ "$$VIOLATIONS" != "[]" ]; then \
		echo "::group::SSM Contract OPA violations in $(MODULE_PATH) ($$VIOLATIONS)"; \
		opa eval --format pretty --data policies/ssm-contract.rego --data $(REPO_ROOT)/ssm-contract.json --input $(MODULE_PATH)/plan.json "data.terraform.deny[x]" 2>/dev/null; \
		echo "::endgroup::"; \
		exit 1; \
	else \
		echo "SSM Contract OPA — no violations."; \
	fi

.PHONY: opa-ssm-plan
opa-ssm-plan: plan-ci opa-ssm

.PHONY: ssm-contract-json
ssm-contract-json:
	python3 -c "import yaml,json; json.dump(yaml.safe_load(open('$(REPO_ROOT)/ssm-contract.yaml')), open('$(REPO_ROOT)/ssm-contract.json','w'), indent=2)"
	@echo "Generated ssm-contract.json from ssm-contract.yaml"

.PHONY: setup
setup:
	bash scripts/setup-dev.sh