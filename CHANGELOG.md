# CHANGELOG

All notable changes to this project will be documented in this file.

## [v0.3.1] - 2020-11-28

### Fixed

- Support the syntax `` `WIDTH'hF0``, i.e. where the *size* specifier of a sized
  integer literal is the result of a macro expansion. Many parsers seem to
  support this syntax even though the standard appears to define this as not
  legal Verilog since macros are not allowed to break number tokens.

## [v0.3.0] - 2020-11-25

### Added

- The diagnostic messages published for a source file now include:

  - undeclared identifiers (disable with `diagnostics.undeclared_identifiers =
    false`),
  - unconnected input ports of a module instance (disable with
    `diagnostics.unconnected_ports = false`),
  - ports missing from a module instance (disable with
    `diagnostics.missing_ports = false`),
  - parameters missing from a module instance (enable with
    `diagnostics.missing_parameters = true`); and
  - unassigned parameters, e.g. `.WIDTH()` (disable with
    `diagnostics.unassigned_parameters = false`).

- Enable hover requests for module instantiations.

- Module completions, inserting an instantiation of the selected module.

- The define `VLS` is always present when the language server processes a file.
  Add code that should only be seen by the language server by using `` `ifdef
  VLS ... `endif ``. Hide code from the the language server by using `` `ifndef
  VLS ... `endif``.

### Changed

- Require Nim v1.4.0.
- Diagnostic messages are no longer shown for Verilog header files (`.vh`).

### Fixed

- Fix always listing the parameters declared in the module body in completion
  requests. According to the standard, these should only get included if the
  parameter port list is omitted.
- Fix `textDocument/rename` when targeting an external port identifier in a
  list of ports.
- Fix `textDocument/references` not including identifiers from the port
  reference (in the list of ports) when targeting the port identifier from
  within the module body.
- Fix not showing named port and parameter completion suggestions when the dot
  was immediately followed by e.g. a left parenthesis `)`.

## [v0.2.2] - 2020-08-31

### Fixed

- Fix symbol renaming when a module port or parameter port was targeted
  indirectly via an internal reference when that reference was used in a named
  port connection.
- Fix docstrings not showing up for localparam and parameter declarations.

## [v0.2.1] - 2020-08-30

### Fixed

- When parsing files from the include path, e.g. when looking up external
  symbols, browse for the corresponding configuration file to correctly set up
  the environment.
- Fix an issue which prevented symbol renaming of localparams.
- Fix symbol renaming when a module port or parameter port was targeted
  indirectly via an internal reference.
- Fix declaration lookup of parameter ports that are declared inside the module
  body, i.e. not in the module parameter port list.
- Fix parameter port completions not including parameters that are declared
  inside the module body.
- Fix port completions for ports declared with the 'port list' syntax using
  concatenations.

## [v0.2.0] - 2020-08-24

### Added

- Completion suggestions now make use of the optional 'kind' field.
- Reference lookups targeting a module instantiation or the module declaration
  itself will now browse through the include paths and report back all the
  instantiations of that module.
- Symbol renaming is now able to target module names, ports and parameter ports
  to rename these across all files found on the include paths.

### Fixed

- The `documentSymbol` request now correctly lists all module instances.
- Looking up the references of a symbol with the same name as a module parameter
  port no longer returns a match for the named parameter port.
- Renaming a symbol with the same name as a module parameter port no longer
  changes the name of the parameter port.

### Changed

- Only read the configuration file when the a source file is opened (`didOpen`)
  instead of every time the source file changes (`didChange`).
- If available, completion suggestions now include information about the
  identifier's declaration and any attached docstring.

## [v0.1.1] - 2020-08-10

### Fixed

- Fix infinite loop when looking up completions in a file containing a ranged
  module instantiation.
- Speed up the parameter/port connection completion request.
- Fix the type of the `signatureHelpProvider` field (response to an `initialize`
  request).
- Avoid hover requests for internal module declarations (until properly
  implemented).
- The hover information for task & function declarations now correctly includes
  the type information (`vparse` v0.1.1).

## [v0.1.0] - 2020-08-08

- This is the first release of the project.
