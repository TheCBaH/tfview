SCHEMA := modules/tflite-micro/tensorflow/compiler/mlir/lite/schema/schema.fbs
FLATC := modules/flatbuffers/flatc
MODEL_DIR := models
MODEL := $(MODEL_DIR)/mobilenet_v1_1.0_224.tflite

.PHONY: all build build-web-jsoo build-melange flatc deps generate generate-check fmt fmt-check download download-models run run-jsoo run-melange test-jsoo test-web-jsoo test-web-jsoo-browser test-melange test-models serve-web-jsoo print clean

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

FMT_DIRS := bin lib/print web-jsoo web-melange

fmt:
	opam exec -- dune build $(addprefix @,$(addsuffix /fmt,$(FMT_DIRS))) --auto-promote

fmt-check:
	opam exec -- dune build $(addprefix @,$(addsuffix /fmt,$(FMT_DIRS)))

build:
	opam exec -- dune build --ignore-promoted-rules

build-web-jsoo:
	opam exec -- dune build --ignore-promoted-rules web-jsoo/tfview_web.bc.js

build-melange:
	opam exec -- dune build @melange

download:
	mkdir -p $(MODEL_DIR)
	curl -L -o $(MODEL_DIR)/mobilenet_v1_1.0_224.tgz \
		"https://storage.googleapis.com/download.tensorflow.org/models/mobilenet_v1_2018_08_02/mobilenet_v1_1.0_224.tgz" \
		--fail
	cd $(MODEL_DIR) && tar xzf mobilenet_v1_1.0_224.tgz ./mobilenet_v1_1.0_224.tflite
	rm -f $(MODEL_DIR)/mobilenet_v1_1.0_224.tgz

include models.inc

ALL_MODELS := $(wildcard $(MODEL_DIR)/*.tflite)

TEST_MODEL_DIR := _build/models

test-models: build
	@if [ -z "$(ALL_MODELS)" ]; then echo "No models found in $(MODEL_DIR)/"; exit 1; fi
	@mkdir -p $(TEST_MODEL_DIR)
	@for m in $(ALL_MODELS); do \
		name=$$(basename "$$m" .tflite); \
		opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $$m > $(TEST_MODEL_DIR)/$$name.txt || exit 1; \
		tools/verify-model-output.sh $(TEST_MODEL_DIR)/$$name.txt || exit 1; \
	done
	@echo "All models parsed successfully"

run: $(MODEL)
	opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $(MODEL)

run-jsoo: $(MODEL)
	node _build/default/bin/tfview.bc.js $(MODEL)

run-melange: $(MODEL)
	node _build/default/web-melange/output/web-melange/tfview_mel.js $(MODEL)

test-jsoo: $(MODEL)
	opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $(MODEL) > _build/expected.txt
	node _build/default/bin/tfview.bc.js $(MODEL) > _build/actual_jsoo.txt
	diff _build/expected.txt _build/actual_jsoo.txt
	@echo "jsoo output matches native"

NODE_PATH := $(shell node -e "console.log(require('child_process').execSync('npm root -g').toString().trim())")

test-melange: build-melange
	@if [ -z "$(ALL_MODELS)" ]; then echo "No models found in $(MODEL_DIR)/"; exit 1; fi
	@mkdir -p $(TEST_MODEL_DIR)
	@for m in $(ALL_MODELS); do \
		name=$$(basename "$$m" .tflite); \
		opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $$m > $(TEST_MODEL_DIR)/$$name.native.txt || exit 1; \
		node _build/default/web-melange/output/web-melange/tfview_mel.js $$m > $(TEST_MODEL_DIR)/$$name.melange.txt || exit 1; \
		diff $(TEST_MODEL_DIR)/$$name.native.txt $(TEST_MODEL_DIR)/$$name.melange.txt || { echo "FAIL: $$name melange output differs from native"; exit 1; }; \
		echo "OK: $$name"; \
	done
	@echo "All models: melange output matches native"

test-web-jsoo: $(MODEL)
	opam exec -- dune build --ignore-promoted-rules web-jsoo/tfview_web.bc.js
	opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $(MODEL) > _build/expected.txt
	node web-jsoo/test_web.js $(MODEL) api > _build/actual_web_jsoo.txt
	diff _build/expected.txt _build/actual_web_jsoo.txt
	@echo "web-jsoo API output matches native"
	NODE_PATH=$(NODE_PATH) node web-jsoo/test_web.js $(MODEL) dom _build/expected.txt
	@echo "web-jsoo DOM test passed"

test-web-jsoo-browser: $(MODEL)
	opam exec -- dune build --ignore-promoted-rules web-jsoo/tfview_web.bc.js
	opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $(MODEL) > _build/expected.txt
	NODE_PATH=$(NODE_PATH) PLAYWRIGHT_BROWSERS_PATH=$${PLAYWRIGHT_BROWSERS_PATH:-/usr/local/ms-playwright} node web-jsoo/test_browser.js $(MODEL) _build/expected.txt
	@echo "web-jsoo browser test passed"

serve-web-jsoo:
	opam exec -- dune build --ignore-promoted-rules @web-jsoo/serve

print: run

clean:
	opam exec -- dune clean
	rm -f $(GENERATED).ml $(GENERATED).mli
