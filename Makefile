SCHEMA := modules/tflite-micro/tensorflow/compiler/mlir/lite/schema/schema.fbs
FLATC := modules/flatbuffers/flatc
MODEL_DIR := models
MODEL := $(MODEL_DIR)/mobilenet_v1_1.0_224.tflite

.PHONY: all build build-web-jsoo flatc deps generate generate-check fmt fmt-check download run run-jsoo test-jsoo test-web-jsoo print clean

all: build

flatc:
	$(MAKE) -C modules/flatbuffers flatc

deps:
	opam install ./modules/flatbuffers --deps-only -t -y

GENERATED := lib/tflite_schema/tflite_schema

generate: $(FLATC)
	$(FLATC) --ocaml $(SCHEMA)
	mv schema.ml $(GENERATED).ml
	mv schema.mli $(GENERATED).mli

generate-check: generate
	@if ! git diff --quiet -- $(GENERATED).ml $(GENERATED).mli; then \
		echo "Error: generated schema files are out of date:" >&2; \
		git diff --stat -- $(GENERATED).ml $(GENERATED).mli; \
		exit 1; \
	fi
	@echo "Generated schema files are up to date"

FMT_DIRS := bin lib/print web-jsoo

fmt:
	opam exec -- dune build $(addprefix @,$(addsuffix /fmt,$(FMT_DIRS))) --auto-promote

fmt-check:
	opam exec -- dune build $(addprefix @,$(addsuffix /fmt,$(FMT_DIRS)))

build:
	opam exec -- dune build --ignore-promoted-rules

build-web-jsoo:
	opam exec -- dune build --ignore-promoted-rules web-jsoo/tfview_web.bc.js

download:
	mkdir -p $(MODEL_DIR)
	curl -L -o $(MODEL_DIR)/mobilenet_v1_1.0_224.tgz \
		"https://storage.googleapis.com/download.tensorflow.org/models/mobilenet_v1_2018_08_02/mobilenet_v1_1.0_224.tgz" \
		--fail
	cd $(MODEL_DIR) && tar xzf mobilenet_v1_1.0_224.tgz ./mobilenet_v1_1.0_224.tflite
	rm -f $(MODEL_DIR)/mobilenet_v1_1.0_224.tgz

run: $(MODEL)
	opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $(MODEL)

run-jsoo: $(MODEL)
	node _build/default/bin/tfview.bc.js $(MODEL)

test-jsoo: $(MODEL)
	opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $(MODEL) > _build/expected.txt
	node _build/default/bin/tfview.bc.js $(MODEL) > _build/actual_jsoo.txt
	diff _build/expected.txt _build/actual_jsoo.txt
	@echo "jsoo output matches native"

NODE_PATH := $(shell node -e "console.log(require('child_process').execSync('npm root -g').toString().trim())")

test-web-jsoo: $(MODEL)
	opam exec -- dune build --ignore-promoted-rules web-jsoo/tfview_web.bc.js
	opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $(MODEL) > _build/expected.txt
	node web-jsoo/test_web.js $(MODEL) api > _build/actual_web_jsoo.txt
	diff _build/expected.txt _build/actual_web_jsoo.txt
	@echo "web-jsoo API output matches native"
	NODE_PATH=$(NODE_PATH) node web-jsoo/test_web.js $(MODEL) dom _build/expected.txt
	@echo "web-jsoo DOM test passed"

print: run

clean:
	opam exec -- dune clean
	rm -f $(GENERATED).ml $(GENERATED).mli
