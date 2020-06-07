# This module collects the operations

import streams
import vparse

import ./configuration
import ./log

type
   SourceUnit* = object
      filename*: string
      cache*: IdentifierCache
      graph*: Graph
      configuration*: Configuration


proc get_configuration(source_filename: string): Configuration =
   # Search for a configuration file starting at the ``source_filename`` and
   # walking up to the root directory. If we find a file but fail to parse it,
   # we fall back to default values.
   log.debug("Searching for a configuration file.")
   let filename = find_configuration_file(source_filename)
   try:
      result = configuration.parse_file(filename)
      log.debug("Parsed configuration file '$1'.", filename)
      log.debug($result)
   except ConfigurationParseError as e:
      log.error("Failed to parse configuration file: $1", e.msg)
      init(result)


proc open*(unit: var SourceUnit, filename, text: string) =
   unit.configuration = get_configuration(filename)
   unit.cache = new_ident_cache()
   unit.filename = filename
   let ss = new_string_stream(text)
   open_graph(unit.graph, unit.cache, ss, filename,
              unit.configuration.include_paths, unit.configuration.defines)
   close(ss)


proc close*(unit: var SourceUnit) =
   close_graph(unit.graph)
