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

### Language Features
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

Configuration is handled through the LSP [workspace configuration](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_configuration) interface. The client is responsible of notifying `vls` about any changes to the configuration by sending a `workspace/didChangeConfiguration` notification. Upon receiving this notification the server will make a `workspace/configuration` request, fetching the `vls` section from the client.

The `vls` section is a JSON object with the following structure:
```json
{
    "env": {
        "myDefines": [
            "FOO",
            "WIDTH=8",
            "ONES(x) = {(x){1'b1}}"
        ],
    },
    "configurations": [
        {
            "name": "win",
            "includePaths": [
                "C:\\path\\to\\some\\directory",
                "C:\\path\\to\\some\\other\\directory",
            ],
            "defines": [
                "${myDefines}",
                "WINDOWS_DEFINE"
            ]
        },
        {
            "name": "linux",
            "includePaths": [
                "/path/to/some/directory",
                "/path/to/some/other/directory"
            ],
            "defines": [
                "${myDefines}",
                "LINUX_DEFINE"
            ]
        }
    ]
}
```

### Top-level properties

- `env` An array of user-defined variables that will be available for substitution in the configuration objects. Strings and arrays of strings are supported.
- `configuration` An array of configuration objects, see the section below.

### Configuration properties

- `name` The name of the configuration (case-insensitive). The names `win`, `mac` and `linux` are reserved for the respective platforms and automatically chosen by a server running on one of these platforms. Running `vls` in WSL chooses the `linux` configuration by default.
- `includePaths` An array of strings expressing the include paths where `vls` should look for externally defined modules and files targeted by `` `include`` directives.
- `defines` An array of strings expressing the defines that should be passed to `vls`. The rules follow that of the `-D` option for [vparse](https://github.com/sthenic/vparse). It's possible to specify a macro by using the character `=` to separate the macro name from its body.

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
