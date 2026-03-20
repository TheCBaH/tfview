# tfview

[![OCaml Build](https://github.com/TheCBaH/tfview/actions/workflows/ocaml-build.yml/badge.svg)](https://github.com/TheCBaH/tfview/actions/workflows/ocaml-build.yml)
[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/TheCBaH/tfview)

A TensorFlow Lite model viewer written in OCaml. Parses `.tflite` FlatBuffers files and displays model structure: operator codes, subgraphs, operators with builtin options, and tensors with quantization parameters.

Compiles to native binary and JavaScript (via js_of_ocaml) for both Node.js and browser use.

## Usage

```sh
make build
make download
make run
```

## License

[MIT](LICENSE)
