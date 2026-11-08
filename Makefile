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

##@ lib-bash. Build

build: export DEST_FILE = $(SYNC_FILE)
build:  ## Build sync.sh
	@./hack/build.sh

build/lib: export DEST_FILE = $(LIB_FILE_SH)
build/lib: export BUILD_AS_LIB = true
build/lib:  ## Build libraries lib.sh, lib-bash.sh and lib-shebang.sh 
	@./hack/build.sh

build/all: build build/lib ## Build sync and libraries

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

##@ lib-bash. Deploy sync.sh and/or config to host

define INCLUDE_PORT_ARG
function port_arg_scp() { \
	local res="22"; \
	if [ -n "$$PORT" ]; then \
		res="$$PORT"; \
	fi; \
	echo -n "-P $$res"; \
}; \
function connect_args_ssh() { \
	local res="22"; \
	if [ -n "$$PORT" ]; then \
		res="$$PORT"; \
	fi; \
	echo -n "$$HOST -p $$res"; \
};
endef

define INCLUDE_DONE_MSG
${INCLUDE_ECHO} \
${INCLUDE_PORT_ARG} \
function done_msg_deploy() { \
	local script="$$1"; \
	local conf="$${2:-}"; \
	local connect_args="$$(connect_args_ssh)"; \
	local header_msg="Sync"; \
	local tail_msg="  --log-add-unix-seconds-to-file-path"; \
	if [ -n "$$conf" ]; then \
		header_msg="$$header_msg and config"; \
		local new_line=$$'\n'; \
		tail_msg="  --log-add-unix-seconds-to-file-path \\$${new_line}  --config '$$conf'"; \
	fi; \
	header_msg="$$header_msg copied to remote"; \
    echo_info "$$header_msg"; \
	echo_info "Connect to host:"; \
	echo "ssh -o ServerAliveInterval=5 -o ServerAliveCountMax=5 $${connect_args}"; \
	echo_info "Run it with sudo or root as:"; \
	echo "sudo $$script \\"; \
	echo "  --screen-enable-run-via-screen \\"; \
	echo "  --screen-records-dir /root/screen-sync \\"; \
	echo "  --log-file /root/host-sync.log \\"; \
	echo "$$tail_msg"; \
};
endef

_check/install/stty:
	@$(MAKE) check/installed/bin BIN_NAME=stty

_check/install/ssh:
	@$(MAKE) check/installed/bin BIN_NAME=ssh
	@$(MAKE) check/installed/bin BIN_NAME=scp

__check/host-passed:
	@${INCLUDE_ECHO} \
	if [ -z "$$HOST" ]; then \
		exit_with_err "host 'user@ip' not passed via HOST param"; \
	fi

deploy/sync/to-tmp: __check/host-passed __check/install/ssh ## Deploy sync.sh to remote host to /tmp dir
	@##~ HOST=USER@IP - Remote host to deploy. Required
	@##~ PORT=PORT    - Port for connect. Optional
	@##~                Optional, Default, 22.
	@${INCLUDE_PORT_ARG} \
	port_arg="$$(port_arg_scp)"; \
	scp $${port_arg} "$(SYNC_FILE)" "$$HOST:$(REMOTE_TMP_SYNC)"

deploy/conf/to-tmp: __check/host-passed __check/install/ssh ## Deploy sync.sh to remote host to /tmp dir
	@##~ HOST=USER@IP - Remote host to deploy. Required
	@##~ PORT=PORT    - Port for connect. Optional
	@##~                Optional, Default, 22.
	@##~ CONF=PATH - Conf path. Optional
	@${INCLUDE_ECHO} \
	${INCLUDE_PORT_ARG} \
	port_arg="$$(port_arg_scp)"; \
	if [ -n "$$CONF" ]; then \
		if [ ! -f "$$CONF" ]; then \
			exit_with_err "Config file '$$CONF' is not file or not found"; \
		fi; \
		echo_info "Conf passed. Copy to $(REMOTE_TMP_CONF)"; \
		scp $${port_arg} "$$CONF" "$$HOST:$(REMOTE_TMP_CONF)"; \
	fi

deploy/cleanup/tmp: __check/host-passed __check/install/ssh ## Remove sync.sh and conf from /tmp on remote host
	@##~ HOST=USER@IP - Remote host to deploy. Required
	@##~ PORT=PORT    - Port for connect. Optional
	@##~                Optional, Default, 22.
	@${INCLUDE_PORT_ARG} \
	connect_args="$$(connect_args_ssh)"; \
	if [ -n "$$HOST" ]; then \
		ssh $$connect_args "rm -f $(REMOTE_TMP_CONF)" || ssh $$connect_args "rm -f $(REMOTE_TMP_SYNC)"; \
	fi

__deploy/with-sudo-password: __check/host-passed __check/install/ssh _check/install/stty deploy/sync/to-tmp deploy/conf/to-tmp
	@${INCLUDE_DONE_MSG} \
	set -e; \
	connect_args="$$(connect_args_ssh)"; \
	stty -echo; \
		read -p "Sudo Password: " PASSD; \
		stty echo; \
		echo ""; \
		ssh $$connect_args "echo $$PASSD | sudo -S mkdir -p $(REMOTE_DEST_SYNC_DIR)"; \
		ssh $$connect_args "echo $$PASSD | sudo -S mv $(REMOTE_TMP_SYNC) $(REMOTE_DEST_SYNC)"; \
		dest_conf=""; \
		if [ -n "$$CONF" ]; then \
			dest_conf="$(REMOTE_DEST_CONF)"; \
			ssh $$connect_args "echo $$PASSD | sudo -S mv $(REMOTE_TMP_CONF) $(REMOTE_DEST_CONF)"; \
		fi; \
		done_msg_deploy "$(REMOTE_DEST_SYNC)" "$$dest_conf"

__deploy/no-sudo-password: __check/host-passed __check/install/ssh deploy/sync/to-tmp deploy/conf/to-tmp
	@${INCLUDE_DONE_MSG} \
	set -e; \
	connect_args="$$(connect_args_ssh)"; \
	dest_conf=""; \
	ssh $$connect_args "sudo mkdir -p $(REMOTE_DEST_SYNC_DIR)"; \
		ssh $$connect_args "sudo mv $(REMOTE_TMP_SYNC) $(REMOTE_DEST_SYNC)"; \
		if [ -n "$$CONF" ]; then \
			dest_conf="$(REMOTE_DEST_CONF)"; \
			ssh $$connect_args "sudo mv $(REMOTE_TMP_CONF) $(REMOTE_DEST_CONF)"; \
		fi; \
		done_msg_deploy "$(REMOTE_DEST_SYNC)" "$$dest_conf"

deploy/with-sudo-password: ## Deploy, use sudo password (will read from stdin), to /tmp and move to /root/sync sync.sh and/or config in the end remove deployed files from /tmp
	@##~ HOST=USER@IP - Remote host to deploy. Required
	@##~ PORT=PORT    - Port for connect. Optional
	@##~                Optional, Default, 22.
	@##~ CONF=PATH    - Conf path. Optional
	@$(call RUN_WITH_CLEANUP,__deploy/with-sudo-password, deploy/cleanup/tmp)

deploy/no-sudo-password: ## Deploy, use sudo without password, to /tmp and move to /root/sync sync.sh and/or config in the end remove deployed files from /tmp
	@##~ HOST=USER@IP - Remote host to deploy. Required
	@##~ PORT=PORT    - Port for connect. Optional
	@##~                Optional, Default, 22.
	@##~ CONF=PATH    - Conf path. Optional
	@$(call RUN_WITH_CLEANUP,__deploy/no-sudo-password, deploy/cleanup/tmp)

deploy/debug/no-sudo-password: build deploy/no-sudo-password ## Build and deploy use sudo password (see deploy/no-sudo-password)
	@##~ HOST=USER@IP - Remote host to deploy. Required
	@##~ PORT=PORT    - Port for connect. Optional
	@##~                Optional, Default, 22.
	@##~ CONF=PATH    - Conf path. Optional

deploy/debug/with-sudo-password: build deploy/with-sudo-password ## Build and deploy use sudo with password (see deploy/with-sudo-password)
	@##~ HOST=USER@IP - Remote host to deploy. Required
	@##~ PORT=PORT    - Port for connect. Optional
	@##~                Optional, Default, 22.
	@##~ CONF=PATH    - Conf path. Optional

deploy/cleanup/with-sudo-password: __check/host-passed __check/install/ssh deploy/cleanup/tmp ## Remove sync.sh and config from /root/sync (and /tmp) and remove dir on remote use sudo password (will read from stdin)
	@##~ HOST=USER@IP - Remote host to cleanup. Required
	@##~ PORT=PORT    - Port for connect. Optional
	@##~                Optional, Default, 22.
	@${INCLUDE_PORT_ARG} \
	connect_args="$$(connect_args_ssh)"; \
	stty -echo; \
		read -p "Sudo Password: " PASSD; \
		stty echo; \
		echo ""; \
		ssh $$connect_args "echo $$PASSD | sudo -S sh -c 'rm -f $(REMOTE_DEST_SYNC); rm -f $(REMOTE_DEST_CONF); rmdir $(REMOTE_DEST_SYNC_DIR) || true'";

deploy/cleanup/no-sudo-password: __check/host-passed __check/install/ssh deploy/cleanup/tmp ## Remove sync.sh and config from /root/sync (and /tmp) and remove dir on remote use sudo password (will read from stdin)
	@##~ HOST=USER@IP - Remote host to cleanup. Required
	@##~ PORT=PORT    - Port for connect. Optional
	@##~                Optional, Default, 22.
	@${INCLUDE_PORT_ARG} \
	connect_args="$$(connect_args_ssh)"; \
	ssh  $$connect_args "sudo sh -c 'rm -f $(REMOTE_DEST_SYNC); rm -f $(REMOTE_DEST_CONF); rmdir $(REMOTE_DEST_SYNC_DIR) || true'";


.PHONY: build build/lib build/all __check/host-passed deploy/sync/to-tmp deploy/conf/to-tmp deploy/cleanup/tmp tests/keep-files/run tests/run deploy/cleanup/with-sudo-password __deploy/with-sudo-password __deploy/no-sudo-password deploy/with-sudo-password deploy/no-sudo-password deploy/debug deploy/debug/with-sudo-password repo/upgrade/common __check/install/ssh
