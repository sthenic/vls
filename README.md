[![NIM](https://img.shields.io/badge/Nim-1.2.0-orange.svg?style=flat-square)](https://nim-lang.org)
[![LICENSE](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT)

# vls
This tool is a Verilog IEEE 1364-2005 [language server](https://microsoft.github.io/language-server-protocol/) written in [Nim](https://nim-lang.org). The parsing is handled by [vparse](https://github.com/sthenic/vparse).

## Supported Protocol Features

### Workspace
- [ ] workspace/executeCommand
- [ ] workspace/symbol
- [x] workspace/configuration
- [x] workspace/didChangeConfiguration

### Text synchronization
- [x] textDocument/didChange
- [ ] textDocument/didClose
- [x] textDocument/didOpen
- [ ] textDocument/didSave

### Language features
- [ ] textDocument/completion
- [ ] textDocument/hover
- [ ] textDocument/signatureHelp
- [ ] textDocument/declaration
- [ ] textDocument/definition
- [ ] ~~textDocument/typeDefinition~~
- [ ] ~~textDocument/implementation~~
- [ ] textDocument/references
- [ ] textDocument/documentHighlight
- [ ] ~~textDocument/documentSymbol~~
- [ ] ~~textDocument/codeAction~~
- [ ] ~~textDocument/codeLens~~
- [ ] ~~textDocument/documentLink~~
- [ ] ~~textDocument/documentColor~~
- [ ] ~~textDocument/colorPresentation~~
- [ ] ~~textDocument/formatting~~
- [ ] ~~textDocument/rangeFormatting~~
- [ ] ~~textDocument/onTypeFormatting~~
- [ ] textDocument/rename
- [ ] textDocument/prepareRename
- [ ] ~~textDocument/foldingRange~~
- [ ] ~~textDocument/selectionRange~~

## Configuration

The language server is configured by using a [TOML](https://github.com/toml-lang/toml) file. When a text document is opened and passed to the language server with the `textDocument/didOpen` request, the server looks for a configuration file. The search walks from the directory of the input text file up to the root directory looking for one of the following files (listed in the order of precedence):

1. `.vls.toml`
2. `vls.toml`
3. `.vls/.vls.toml`
4. `.vls/vls.toml`
5. `vls/.vls.toml`
6. `vls/vls.toml`

In short, the configuration file can have two different names: `.vls.toml` or `vls.toml` and can reside immediately on the ascended path, or inside a directory named: `.vls/` or `vls/`.

### Example

```toml
[verilog]
include_paths = [
    "/path/to/some/directory",
    "/path/to/another/directory",
    "../a/relative/path"
]

defines = [
    "FOO",
    "WIDTH=8",
    "ONES(x) = {(x){1'b1}}"
]

[vls]
max_nof_diagnostics = 10
```

### Top-level tables

- The `verilog` table collects language-specific settings.
- The `vls` table collects settings specific to the language server.

### `verilog` table

- `include_paths` is an array of strings expressing the include paths where `vls` should look for externally defined modules and files targeted by `` `include`` directives.
- `defines` is an array of strings expressing the defines that should be passed to `vls`. The rules follow that of the `-D` option for [vparse](https://github.com/sthenic/vparse). It's possible to specify a macro by using the character `=` to separate the macro name from its body.

## `vls` table

- `max_nof_diagnostics` specifies the maximum number of diagnostic messages passed in a `textDocument/publishDiagnostics` notification.

In the future, configuration may also be handled through the LSP [workspace configuration](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_configuration) interface.

## Documentation
Coming soon.

## Version numbers
Releases follow [semantic versioning](https://semver.org/) to determine how the version number is incremented. If the specification is ever broken by a release, this will be documented in the changelog.

## Reporting a bug
If you discover a bug or what you believe is unintended behavior, please submit an issue on the [issue board](https://github.com/sthenic/vls/issues). A minimal working example and a short description of the context is appreciated and goes a long way towards being able to fix the problem quickly.

## License
This tool is free software released under the [MIT license](https://opensource.org/licenses/MIT).

## Third-party dependencies

* [Nim's standard library](https://github.com/nim-lang/Nim)
* [vparse](https://github.com/sthenic/vparse)

## Author
vls is maintained by [Marcus Eriksson](mailto:marcus.jr.eriksson@gmail.com).
