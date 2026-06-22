.PHONY: install uninstall test lint bench clean

install:
	bash install.sh $${PREFIX:+--prefix=$$PREFIX}

uninstall:
	bash install.sh $${PREFIX:+--prefix=$$PREFIX} --uninstall

test:
	/bin/bash tests/run.sh

lint:
	shellcheck bin/cc-insomnii install.sh tests/*.sh scripts/*.sh

bench:
	bash tests/bench.sh

clean:
	rm -rf tmp/
	find . -name '*.log' -delete
