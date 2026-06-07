# mltorch

OCaml parser and code generator for [PyTorch](https://pytorch.org/) export schema, built on [Jsont](https://erratique.ch/software/jsont) and [Yamlt](https://github.com/TheCBaH/ocaml-yamlt).

Reads the PyTorch operator schema YAML and generates a typed OCaml JSON decoder for exported models.

[![build](https://github.com/TheCBaH/mltorch/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/TheCBaH/mltorch/actions/workflows/build.yml)

## Get started
* [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=master&repo=TheCBaH/mltorch)
* run
  * `make runtest` build and run test suite
