# CHANGELOG

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed

- When parsing files from the include path, e.g. when looking up external
  symbols, browse for the corresponding configuration file to correctly set up
  the environment.

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
