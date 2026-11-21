.PHONY: all test lint synth check report orfs clean

all: report test lint check

report:
	python3 verification/golden_model.py

test:
	bash scripts/run_tests.sh

lint:
	bash scripts/run_lint.sh

synth:
	bash scripts/run_lint.sh

check:
	python3 scripts/check_consistency.py

orfs:
	bash scripts/run_orfs.sh

clean:
	rm -rf /tmp/scicore16_sim /tmp/yosys_core_stat.txt /tmp/yosys_asic_stat.txt
