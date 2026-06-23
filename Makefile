.PHONY: install uninstall test sweep lint bench clean

install:
	bash install.sh $${PREFIX:+--prefix=$$PREFIX}

uninstall:
	bash install.sh $${PREFIX:+--prefix=$$PREFIX} --uninstall

test:
	/bin/bash tests/run.sh

# Full byte-identity release gate: render all 1440 minutes × 7 bedtimes with every
# feature OFF and assert the hash still matches the committed 0.3.0 baseline. Opt-in
# (the suite SKIPs it by default) because it is slow; run it before tagging a release.
sweep:
	CC_INSOMNII_SWEEP=full /bin/bash tests/test_byte_identity.sh

lint:
	shellcheck bin/cc-insomnii install.sh tests/*.sh scripts/*.sh

bench:
	bash tests/bench.sh

clean:
	rm -rf tmp/
	find . -name '*.log' -delete
