.PHONY: install uninstall test lint bench clean

install:
	bash install.sh

uninstall:
	bash install.sh --uninstall

test:
	bash tests/run.sh

lint:
	shellcheck bin/cc-insomnii install.sh tests/*.sh scripts/*.sh

bench:
	bash tests/bench.sh

clean:
	rm -rf tmp/
	find . -name '*.log' -delete
