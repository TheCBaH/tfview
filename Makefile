SCHEMA := modules/tflite-micro/tensorflow/compiler/mlir/lite/schema/schema.fbs
FLATC := modules/flatbuffers/flatc
MODEL_DIR := models
MODEL := $(MODEL_DIR)/mobilenet_v1_1.0_224.tflite

.PHONY: all build flatc deps generate download run print clean

all: build

flatc:
	$(MAKE) -C modules/flatbuffers flatc

deps:
	opam install ./modules/flatbuffers --deps-only -t -y

generate: $(FLATC)
	$(FLATC) --ocaml $(SCHEMA)
	mv tflite.ml tflite.mli lib/ 2>/dev/null || true
	@# If flatc outputs schema.ml instead, move that
	mv schema.ml schema.mli lib/ 2>/dev/null || true
	@echo "Generated files in lib/"

build:
	opam exec -- dune build --ignore-promoted-rules

download:
	mkdir -p $(MODEL_DIR)
	curl -L -o $(MODEL_DIR)/mobilenet_v1_1.0_224.tgz \
		"https://storage.googleapis.com/download.tensorflow.org/models/mobilenet_v1_2018_08_02/mobilenet_v1_1.0_224.tgz" \
		--fail
	cd $(MODEL_DIR) && tar xzf mobilenet_v1_1.0_224.tgz mobilenet_v1_1.0_224.tflite
	rm -f $(MODEL_DIR)/mobilenet_v1_1.0_224.tgz

run: $(MODEL)
	opam exec -- dune exec --ignore-promoted-rules bin/tfview.exe -- $(MODEL)

print: run

clean:
	opam exec -- dune clean
	rm -f lib/schema.ml lib/schema.mli lib/tflite.ml lib/tflite.mli
