# CHANGELOG

All notable changes to this project will be documented in this file.

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
  the type information (vparse v0.1.1).

## [v0.1.0] - 2020-08-08

- This is the first release of the project.
