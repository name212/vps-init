run-with-cleanup = $(1) && $(2) || (ret=$$?; $(2) && exit $$ret)

build:
	@./hack/build.sh

check/host-passed:
	@[ ! -z "$$host" ] || { echo "host not passed"; exit 1; }

deploy/copy-init-to-tmp:
	@scp init.sh "$$host:/tmp/init.sh"

deploy/copy-conf-to-tmp:
	@if [ -n "$$conf" ]; then \
		echo "Conf passed. Copy to /tmp/init-conf.env"; \
		scp "$$conf" "$$host:/tmp/init-conf.env"; \
	fi

deploy/cleanup-tmp:
	@if [ -n "$$host" ]; then \
		ssh "$$host" "rm -f /tmp/init-conf.env" || ssh "$$host" "rm -f /tmp/init.sh"; \
	fi

deploy/cleanup/with-sudo-password: check/host-passed deploy/cleanup-tmp
	@stty -echo; \
		read -p "Sudo Password: " PASSD; \
		stty echo; \
		echo ""; \
		ssh "$$host" "echo $$PASSD | sudo -S sh -c 'rm -f /root/init/init.sh; rm -f /root/init/conf.env; rmdir /root/init || true'";

_deploy/with-sudo-password: check/host-passed deploy/copy-init-to-tmp deploy/copy-conf-to-tmp
	@stty -echo; \
		read -p "Sudo Password: " PASSD; \
		stty echo; \
		echo ""; \
		ssh "$$host" "echo $$PASSD | sudo -S mkdir -p /root/init"; \
		ssh "$$host" "echo $$PASSD | sudo -S mv /tmp/init.sh /root/init/init.sh"; \
		if [ -n "$$conf" ]; then \
			ssh "$$host" "echo $$PASSD | sudo -S mv /tmp/init-conf.env /root/init/conf.env"; \
		fi

_deploy/no-sudo-password: check/host-passed deploy/copy-init-to-tmp deploy/copy-conf-to-tmp
	@ssh "$$host" "echo $$PASSD | sudo -S mkdir -p /root/init"; \
		ssh "$$host" "echo $$PASSD | sudo -S mv /tmp/init.sh /root/init/init.sh"; \
		if [ -n "$$conf" ]; then \
			ssh "$$host" "echo $$PASSD | sudo -S mv /tmp/init-conf.env /root/init/conf.env"; \
		fi

deploy/with-sudo-password:
	$(call run-with-cleanup, $(MAKE) _deploy/with-sudo-password, $(MAKE) deploy/cleanup-tmp)

deploy/no-sudo-password:
	$(call run-with-cleanup, $(MAKE) _deploy/no-sudo-password, $(MAKE) deploy/cleanup-tmp)

deploy/debug: build deploy/no-sudo-password

deploy/debug-sudo-pass: build deploy/with-sudo-password

