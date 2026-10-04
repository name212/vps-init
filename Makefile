SHELL = /usr/bin/env bash

run-with-cleanup = $(1) && $(2) || (ret=$$?; $(2) && exit $$ret)

LIB_FILE = $(CURDIR)/lib.sh
SYNC_FILE = $(CURDIR)/sync.sh

REMOTE_TMP_SYNC="/tmp/sync.sh"
REMOTE_DEST_SYNC_DIR="/root/sync"
REMOTE_DEST_SYNC="$(REMOTE_DEST_SYNC_DIR)/sync.sh"
REMOTE_TMP_CONF="/tmp/sync-conf.env"
REMOTE_DEST_CONF="$(REMOTE_DEST_SYNC_DIR)/conf.env"

build: export DEST_FILE = $(SYNC_FILE)
build:
	@./hack/build.sh

build/lib: export DEST_FILE = $(LIB_FILE)
build/lib: export BUILD_AS_LIB = true
build/lib:
	@./hack/build.sh

build/all: build build/lib

check/host-passed:
	@[ ! -z "$$host" ] || { echo "host not passed"; exit 1; }

deploy/copy-init-to-tmp:
	@scp "$(SYNC_FILE)" "$$host:$(REMOTE_TMP_SYNC)"

deploy/copy-conf-to-tmp:
	@if [ -n "$$conf" ]; then \
		echo "Conf passed. Copy to $(REMOTE_TMP_CONF)"; \
		scp "$$conf" "$$host:$(REMOTE_TMP_CONF)"; \
	fi

deploy/cleanup-tmp:
	@if [ -n "$$host" ]; then \
		ssh "$$host" "rm -f $(REMOTE_TMP_CONF)" || ssh "$$host" "rm -f $(REMOTE_TMP_SYNC)"; \
	fi

deploy/cleanup/with-sudo-password: check/host-passed deploy/cleanup-tmp
	@stty -echo; \
		read -p "Sudo Password: " PASSD; \
		stty echo; \
		echo ""; \
		ssh "$$host" "echo $$PASSD | sudo -S sh -c 'rm -f $(REMOTE_DEST_SYNC); rm -f $(REMOTE_DEST_CONF); rmdir $(REMOTE_DEST_SYNC_DIR) || true'";

_deploy/with-sudo-password: check/host-passed deploy/copy-init-to-tmp deploy/copy-conf-to-tmp
	@stty -echo; \
		read -p "Sudo Password: " PASSD; \
		stty echo; \
		echo ""; \
		ssh "$$host" "echo $$PASSD | sudo -S mkdir -p $(REMOTE_DEST_SYNC_DIR)"; \
		ssh "$$host" "echo $$PASSD | sudo -S mv $(REMOTE_TMP_SYNC) $(REMOTE_DEST_SYNC)"; \
		if [ -n "$$conf" ]; then \
			ssh "$$host" "echo $$PASSD | sudo -S mv $(REMOTE_TMP_CONF) $(REMOTE_DEST_CONF)"; \
		fi

_deploy/no-sudo-password: check/host-passed deploy/copy-init-to-tmp deploy/copy-conf-to-tmp
	@ssh "$$host" "echo $$PASSD | sudo -S mkdir -p $(REMOTE_DEST_SYNC_DIR)"; \
		ssh "$$host" "echo $$PASSD | sudo -S mv $(REMOTE_TMP_SYNC) $(REMOTE_DEST_SYNC)"; \
		if [ -n "$$conf" ]; then \
			ssh "$$host" "echo $$PASSD | sudo -S mv $(REMOTE_TMP_CONF) $(REMOTE_DEST_CONF)"; \
		fi

deploy/with-sudo-password:
	$(call run-with-cleanup, $(MAKE) _deploy/with-sudo-password, $(MAKE) deploy/cleanup-tmp)

deploy/no-sudo-password:
	$(call run-with-cleanup, $(MAKE) _deploy/no-sudo-password, $(MAKE) deploy/cleanup-tmp)

deploy/debug: build deploy/no-sudo-password

deploy/debug-sudo-pass: build deploy/with-sudo-password

tests/run: build/lib
	@function echo_red() { \
    	echo -e "\033[1;31m$$1\033[0m" >&2; \
	}; \
	function echo_green () { \
    	echo -e "\033[1;32m$$1\033[0m" >&2; \
	}; \
	lb="$(LIB_FILE)"; \
	if [ ! -s "$$lb" ]; then \
		echo_red "'$lb' file not found or empty"; \
		exit 1; \
	fi; \
	echo_green "--- Run tests ---"; \
	if [ -n "$$RUN_ONLY" ]; then \
		echo -e "\033[1;33mWill run only '$$RUN_ONLY' test!\033[0m" >&2; \
	fi; \
	failed_tests=(); \
	for fl in $$(find src/include -name "*test.sh" -type f | sort -n); do \
    	bs=""; \
		if ! bs="$$(basename "$$fl")"; then \
			echo_red "Cannot get base name for '$$fl'"; \
			exit 1; \
		fi; \
		if [[ "$$RUN_ONLY" != "" && "$$RUN_ONLY" != "$$bs" ]]; then \
			continue; \
		fi; \
		echo_green "Run test '$$fl'"; \
		tmp_run_fl=""; \
		if ! tmp_run_fl="$$(mktemp)"; then \
			echo_red "Cannot create tempt file for run '$$fl'"; \
			exit 1; \
		fi; \
		if ! chmod 700 "$$tmp_run_fl"; then \
			echo_red "Cannot chmod 700 '$$tmp_run_fl'"; \
			exit 1; \
		fi; \
    	if ! cat "$$lb" > "$$tmp_run_fl"; then \
			echo_red "Cannot write lib file '$$lb' to temp tile $$tmp_run_fl"; \
			exit 1; \
		fi; \
		echo "" >> "$$tmp_run_fl"; \
		echo "# Tests for '$$fl'" >> "$$tmp_run_fl"; \
		echo "" >> "$$tmp_run_fl"; \
		if ! cat "$$fl" >> "$$tmp_run_fl"; then \
			echo_red "Cannot write test file '$$fl' to temp tile $$tmp_run_fl"; \
			exit 1; \
		fi; \
    	if ! bash "$$tmp_run_fl"; then \
        	echo_red "FAILED '$$fl'"; \
        	failed_tests+=("$$fl"); \
    	fi; \
		rm -f "$tmp_run_fl" || true; \
	done; \
	if [[ "$${#failed_tests[@]}" == "0" ]]; then \
		echo_green "All tests passed!"; \
		exit 0; \
	fi; \
	echo_red "Tests FAILED:"; \
	for ftst in "$${failed_tests[@]}"; do \
		echo_red "  $$ftst"; \
	done; \
	exit 1

.PHONY: build build/lib build/all check/host-passed deploy/copy-init-to-tmp deploy/copy-conf-to-tmp deploy/cleanup-tmp tests/run deploy/cleanup/with-sudo-password _deploy/with-sudo-password _deploy/no-sudo-password deploy/with-sudo-password deploy/no-sudo-password deploy/debug deploy/debug-sudo-pass
