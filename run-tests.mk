##@ lib-bash. Run tests

lib/tests/run: ## Run tests for lib or child projects
	@##~ LIB_FILE=PATH           - Path to file (lib) for prepend to result
	@##~                           tests script.
	@##~                           Required.
	@##~ INCLUDE_DIR=PATH        - Path to collect tests files
	@##~                           Test files should have suffix .test.sh 
	@##~                           Required.
	@##~ KEEP_TEST_SCRIPTS=true  - If passed, will not remove result test files
	@##~                           and print test_file -> temp_result_test_file
	@##~                           after run.
	@##~                           Default: not passed
	@##~ RUN_ONLY=FILENAME       - if passed run only one test for one passed file
	@##~                           File name should base name with extension, like:
	@##~                           02_base_type_02_str_08_password.test.sh
	@##~                           Default: not passed
	@function echo_red() { \
    	echo -e "\033[1;31m$$1\033[0m" >&2; \
	}; \
	function echo_green () { \
    	echo -e "\033[1;32m$$1\033[0m" >&2; \
	}; \
	function echo_yellow () { \
    	echo -e "\033[1;33m$$1\033[0m" >&2; \
	}; \
	if [ -z "$$LIB_FILE" ]; then \
		echo_red "LIB_FILE for prepend to result temp test not passed"; \
		exit 1; \
	fi; \
	lb="$$LIB_FILE"; \
	if [ ! -s "$$lb" ]; then \
		echo_red "Lib file '$lb' file not found or empty"; \
		exit 1; \
	fi; \
	if [ -z "$$INCLUDE_DIR" ]; then \
		echo_red "INCLUDE_DIR for collect tests files not passed"; \
		exit 1; \
	fi; \
	if [ ! -d "$$INCLUDE_DIR" ]; then \
		echo_red "INCLUDE_DIR '$$INCLUDE_DIR' is not dir"; \
		exit 1; \
	fi; \
	inc_dir="$$INCLUDE_DIR"; \
	echo_green "--- Run tests ---"; \
	if [ -n "$$RUN_ONLY" ]; then \
		echo_yellow "Will run only '$$RUN_ONLY' test!"; \
		if [ ! -s "$${inc_dir}/$${RUN_ONLY}" ]; then \
			echo_red "Not found test file for '$$RUN_ONLY'"; \
			exit 1; \
		fi; \
	fi; \
	failed_tests=(); \
	declare -A files_to_remove=(); \
	for fl in $$(find "$$inc_dir" -name "*.test.sh" -type f | sort -V); do \
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
		if ! tmp_run_fl="$$(mktemp -t "lib-bash-test.XXXXXXXX")"; then \
			echo_red "Cannot create tempt file for run '$$fl'"; \
			exit 1; \
		fi; \
		files_to_remove["$$fl"]="$$tmp_run_fl"; \
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
	if [ -z "$$KEEP_TEST_SCRIPTS" ]; then \
		echo_green "Remove temp test script files:"; \
		for d_tmp_name in "$${!files_to_remove[@]}"; do \
			d_tmp="$${files_to_remove[$$d_tmp_name]}"; \
			rm -fv "$$d_tmp"; \
		done; \
	else \
		echo_yellow "Temp test script files was skipped(KEEP_TEST_SCRIPTS passed):"; \
		for d_tmp_name in "$${!files_to_remove[@]}"; do \
			d_tmp="$${files_to_remove[$$d_tmp_name]}"; \
			echo_yellow "  $$d_tmp_name -> $$d_tmp"; \
		done; \
	fi; \
	if [[ "$${#failed_tests[@]}" == "0" ]]; then \
		echo_green "All tests passed!"; \
		exit 0; \
	fi; \
	echo_red "Tests FAILED:"; \
	for ftst in "$${failed_tests[@]}"; do \
		echo_red "  $$ftst"; \
	done; \
	exit 1

.PHONY: lib/tests/run
