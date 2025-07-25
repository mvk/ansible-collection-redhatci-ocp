ROLES ?= $(PWD)
ANSIBLE_LINT_CONF=.ansible-lint
ANSIBLE_LINT_DIRS ?= roles
REPORTS_DIR ?= $(PWD)/reports
BATS_PARAMS ?= --recursive --report-formatter junit --output $(REPORTS_DIR)
SHELLCHECK_PARAMS ?= -o all -x -f diff

# Internal variable: Convert comma-separated ROLES to a clean, space-separated list of items.
# Handles cases like "role1,role2", "role1", "", "role1,,role2".
# 1. Replace commas with spaces.
# 2. Replace multiple spaces with a single space (GNU Make's subst behavior).
# 3. Strip leading/trailing whitespace.
_ROLE_ITEMS := $(strip $(subst ,, ,$(ROLES)))
CLEAN_LIST := *.output *.errors *.output-* *.errors-* diff.raw diff.warnings ./reports regression-report*.md

.ONESHELL:

build:
	@ansible-galaxy collection build --force

.PHONY: make-docs
make-docs:
	@echo "--- Docsible Documentation Generation ---"
	@echo "INFO: Using ROLES='$(ROLES)'"
	@echo "INFO: Derived role items: '$(_ROLE_ITEMS)'"

	@# --- Validation Phase (runs only when make-docs is invoked) ---
	$(if $(_ROLE_ITEMS), \
		@echo "INFO: Validating role directories..." && \
		for role_dir_shell_loop in $(_ROLE_ITEMS); do \
			echo "DEBUG: Validating $$role_dir_shell_loop"; \
			if [ ! -d "$$role_dir_shell_loop" ]; then \
				echo >&2 "ERROR: Role directory '$$role_dir_shell_loop' does not exist. Validation failed for ROLES='$(ROLES)'"; \
				exit 1; \
			fi; \
			if [ ! -d "$$role_dir_shell_loop/tasks" ]; then \
				echo >&2 "ERROR: Role directory '$$role_dir_shell_loop' must contain a 'tasks/' subdirectory. Validation failed for ROLES='$(ROLES)'"; \
				exit 1; \
			fi; \
			if [ ! -d "$$role_dir_shell_loop/meta" ]; then \
				echo >&2 "ERROR: Role directory '$$role_dir_shell_loop' must contain a 'meta/' subdirectory. Validation failed for ROLES='$(ROLES)'"; \
				exit 1; \
			fi; \
		done && \
		echo "INFO: All specified role directories are valid." \
	)

	@# --- Docsible Command Preparation and Execution ---
	@# Initialize shell variable for arguments
	@_EFFECTIVE_ROLE_ARGS=""; \
	# Check if Make's _ROLE_ITEMS is non-empty (will be substituted by Make)
	if [ -n "$(_ROLE_ITEMS)" ]; then \
		# Loop through Make's _ROLE_ITEMS (space-separated) in shell
		for role_dir_for_docsible in $(_ROLE_ITEMS); do \
			# Append to shell variable _EFFECTIVE_ROLE_ARGS
			_EFFECTIVE_ROLE_ARGS="$$_EFFECTIVE_ROLE_ARGS -r $$role_dir_for_docsible"; \
		done; \
		echo "INFO: Processing documentation for roles specified: $(_ROLE_ITEMS)"; \
	else \
		echo "INFO: ROLES variable is empty or results in no role items after processing."; \
		echo "INFO: Running docsible without any role-specific '-r' arguments."; \
	fi; \
	# Execute docsible with the constructed shell arguments
	echo "EXEC: docsible -nod -nob $$_EFFECTIVE_ROLE_ARGS"; \
	docsible -nod -nob $$_EFFECTIVE_ROLE_ARGS
	@echo "--- Docsible Documentation Generation Complete ---"

bash-tests:
	pushd $(PWD) >/dev/null 2>&1 || true
	mkdir -p $(REPORTS_DIR)
	cd hack/
	bats $(BATS_PARAMS) ./test
	popd >/dev/null 2>&1 || true

bash-lint:
	pushd $(PWD) >/dev/null 2>&1 || true
	cd hack
	shellcheck $(SHELLCHECK_PARAMS) *.sh
	shellcheck $(SHELLCHECK_PARAMS) common_lib.bash
	popd >/dev/null 2>&1 || true


clean:
	@rm -fr $(CLEAN_LIST)
	@find . -name \*.orig -delete

check-bash:
	$(MAKE) bash-tests
	$(MAKE) bash-lint

ansible-lint:
	./hack/run_ansible_lint.sh

ansible-test:
	@./hack/run_ansible_test.sh

ansible-doc:
	@./hack/check_doc.sh

check-version:
	@./hack/check_version.sh

run-pr:
	$(MAKE) check-bash
	$(MAKE) ansible-lint
	$(MAKE) ansible-test
	$(MAKE) ansible-doc
	$(MAKE) check-version

run-pr-job-%:
	@act pull_request -j $(*) --verbose 2>&1 | tee act.$(*).log
