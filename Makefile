.PHONY: build test

build:
	opam exec -- dune build

format:
	opam exec -- dune fmt

test:
	opam exec -- dune test

runtest:
	opam exec -- dune runtest
