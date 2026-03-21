SCHEMA := modules/tflite-micro/tensorflow/compiler/mlir/lite/schema/schema.fbs
FLATC := modules/flatbuffers/flatc
MODEL_DIR := models
MODEL := $(MODEL_DIR)/mobilenet_v1_1.0_224.tflite
DL = tools/download-model.sh $(MODEL_DIR)

.PHONY: all build build-web-jsoo build-melange build-web-melange flatc deps generate generate-check fmt fmt-check download download-models run run-jsoo run-melange test-jsoo test-web-jsoo test-web-jsoo-browser test-melange test-web-melange test-web-melange-browser test-models serve-web-jsoo serve-web-melange print clean

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

JSOO_WEB_DIR := _build/default/web-jsoo
MELANGE_WEB_DIR := _build/default/web-melange/web

build-melange:
	opam exec -- dune build @melange

build-web-melange: build-melange
	mkdir -p $(MELANGE_WEB_DIR)/static
	printf 'var m=require("./output/web-melange/web/tfview_mel_web.js");window.tfview={parse:m.parse};\n' > $(MELANGE_WEB_DIR)/entry.js
	npx esbuild $(MELANGE_WEB_DIR)/entry.js --bundle --outfile=$(MELANGE_WEB_DIR)/static/tfview.js
	cp web/static/index.html $(MELANGE_WEB_DIR)/static/

download:
	@$(DL) tgz mobilenet_v1_1.0_224.tflite \
		"https://storage.googleapis.com/download.tensorflow.org/models/mobilenet_v1_2018_08_02/mobilenet_v1_1.0_224.tgz" \
		./mobilenet_v1_1.0_224.tflite

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

test-jsoo: build
	@if [ -z "$(ALL_MODELS)" ]; then echo "No models found in $(MODEL_DIR)/"; exit 1; fi
	@mkdir -p $(TEST_MODEL_DIR)
	@for m in $(ALL_MODELS); do \
		name=$$(basename "$$m" .tflite); \
		opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $$m > $(TEST_MODEL_DIR)/$$name.native.txt || exit 1; \
		node _build/default/bin/tfview.bc.js $$m > $(TEST_MODEL_DIR)/$$name.jsoo.txt || exit 1; \
		diff $(TEST_MODEL_DIR)/$$name.native.txt $(TEST_MODEL_DIR)/$$name.jsoo.txt || { echo "FAIL: $$name jsoo output differs from native"; exit 1; }; \
		echo "OK: $$name"; \
	done
	@echo "All models: jsoo output matches native"

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

test-web-jsoo: build $(MODEL)
	opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $(MODEL) > _build/expected.txt
	SERVE_DIR=$(JSOO_WEB_DIR) node web/test_web.js $(MODEL) api > _build/actual_web_jsoo.txt
	diff _build/expected.txt _build/actual_web_jsoo.txt
	@echo "web-jsoo API output matches native"
	SERVE_DIR=$(JSOO_WEB_DIR) NODE_PATH=$(NODE_PATH) node web/test_web.js $(MODEL) dom _build/expected.txt
	@echo "web-jsoo DOM test passed"

test-web-jsoo-browser: build $(MODEL)
	opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $(MODEL) > _build/expected.txt
	SERVE_DIR=$(JSOO_WEB_DIR) NODE_PATH=$(NODE_PATH) PLAYWRIGHT_BROWSERS_PATH=$${PLAYWRIGHT_BROWSERS_PATH:-/usr/local/ms-playwright} node web/test_browser.js $(MODEL) _build/expected.txt
	@echo "web-jsoo browser test passed"

test-web-melange: build-web-melange $(MODEL)
	opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $(MODEL) > _build/expected.txt
	SERVE_DIR=$(MELANGE_WEB_DIR)/static node web/test_web.js $(MODEL) api > _build/actual_web_melange.txt
	diff _build/expected.txt _build/actual_web_melange.txt
	@echo "web-melange API output matches native"
	SERVE_DIR=$(MELANGE_WEB_DIR)/static NODE_PATH=$(NODE_PATH) node web/test_web.js $(MODEL) dom _build/expected.txt
	@echo "web-melange DOM test passed"

test-web-melange-browser: build-web-melange $(MODEL)
	opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $(MODEL) > _build/expected.txt
	SERVE_DIR=$(MELANGE_WEB_DIR)/static NODE_PATH=$(NODE_PATH) PLAYWRIGHT_BROWSERS_PATH=$${PLAYWRIGHT_BROWSERS_PATH:-/usr/local/ms-playwright} node web/test_browser.js $(MODEL) _build/expected.txt
	@echo "web-melange browser test passed"

serve-web-melange: build-web-melange
	SERVE_DIR=$(MELANGE_WEB_DIR)/static node web/serve.js 0.0.0.0 8080

serve-web-jsoo: build
	SERVE_DIR=$(JSOO_WEB_DIR) node web/serve.js 0.0.0.0 8080

print: run

clean:
	opam exec -- dune clean
	rm -f $(GENERATED).ml $(GENERATED).mli
