include $(CURDIR)/makefile-common/include.mk.inc
include $(CURDIR)/run-tests.mk

export HELP_LIBRARIES_FIRST = true
export HELP_LIBRARIES_OUT = $(CURDIR)

run-with-cleanup = $(1) && $(2) || (ret=$$?; $(2) && exit $$ret)

LIB_FILE_SH = $(CURDIR)/lib.sh
SYNC_FILE = $(CURDIR)/sync.sh

REMOTE_TMP_SYNC="/tmp/sync.sh"
REMOTE_DEST_SYNC_DIR="/root/sync"
REMOTE_DEST_SYNC="$(REMOTE_DEST_SYNC_DIR)/sync.sh"
REMOTE_TMP_CONF="/tmp/sync-conf.env"
REMOTE_DEST_CONF="$(REMOTE_DEST_SYNC_DIR)/conf.env"

build: export DEST_FILE = $(SYNC_FILE)
build:
	@./hack/build.sh

build/lib: export DEST_FILE = $(LIB_FILE_SH)
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

##@ lib-bash. Run tests for itself

tests/run: export LIB_FILE = $(LIB_FILE_SH)
tests/run: export INCLUDE_DIR = src/include
tests/run: build/lib lib/tests/run ## Run library itself tests
	@##~ RUN_ONLY=FILENAME       - if passed run only one test for one passed file
	@##~                           File name should base name with extension, like:
	@##~                           02_base_type_02_str_08_password.test.sh
	@##~                           Default: not passed

tests/keep-files/run: export KEEP_TEST_SCRIPTS = true
tests/keep-files/run: tests/run ## Run library itself tests with keep result tests files
	@##~ RUN_ONLY=FILENAME       - if passed run only one test for one passed file
	@##~                           File name should base name with extension, like:
	@##~                           02_base_type_02_str_08_password.test.sh
	@##~                           Default: not passed

repo/upgrade/common: export SUBMODULE_DIR = makefile-common
repo/upgrade/common: common/git/submodule/upgrade


.PHONY: build build/lib build/all check/host-passed deploy/copy-init-to-tmp deploy/copy-conf-to-tmp deploy/cleanup-tmp tests/keep-files/run tests/run deploy/cleanup/with-sudo-password _deploy/with-sudo-password _deploy/no-sudo-password deploy/with-sudo-password deploy/no-sudo-password deploy/debug deploy/debug-sudo-pass repo/upgrade/common
