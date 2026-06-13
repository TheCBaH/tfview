.PHONY: build test format runtest clean

build:
	opam exec -- dune build --display short

format:
	opam exec -- dune fmt

test:
	opam exec -- dune test

runtest:
	opam exec -- dune runtest

clean:
	opam exec -- dune clean
	rm -rf modules/aten_core/gen modules/aten_core/inc
