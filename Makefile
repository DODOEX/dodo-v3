install:
	forge install
build:
	forge build
lint:
	solhint ./contracts/**.sol
test:
	forge test -vvvv
gas-report:
	forge test -v --gas-report
gas:
	forge test | grep " gas"
doc:
	rm -rf docs
	yarn docgen
	python3 docs.py