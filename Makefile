.PHONY: install uninstall test lint clean

install:
	bash install.sh

uninstall:
	bash install.sh --uninstall

test:
	bash tests/run.sh

lint:
	shellcheck bin/cc-insomnii install.sh tests/*.sh scripts/*.sh

clean:
	rm -rf tmp/
	find . -name '*.log' -delete
