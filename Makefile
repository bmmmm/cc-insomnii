.PHONY: install uninstall test lint clean

install:
	bash install.sh

uninstall:
	bash install.sh --uninstall

test:
	bash tests/run.sh

lint:
	shellcheck bin/insomnii

clean:
	rm -rf tmp/
	find . -name '*.log' -delete
