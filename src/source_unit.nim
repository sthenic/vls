import streams
import vltoml
import vparse

import ./log

type
   SourceUnit* = object
      filename*: string
      cache*: IdentifierCache
      graph*: Graph
      configuration*: Configuration
      text*: string


proc get_configuration*(source_filename: string): Configuration =
   # Search for a configuration file starting at the ``source_filename`` and
   # walking up to the root directory. If we find a file but fail to parse it,
   # we fall back to default values.
   log.debug("Searching for a configuration file.")
   let filename = find_configuration_file(source_filename)
   init(result)
   if len(filename) > 0:
      try:
         result = vltoml.parse_file(filename)
         log.debug("Using configuration file '$1'.", filename)
         log.debug($result)
      except ConfigurationParseError as e:
         log.error("Failed to parse configuration file: '$1'.", e.msg)


proc update*(unit: var SourceUnit, text: string) =
   unit.cache = new_ident_cache()
   unit.graph = new_graph(unit.cache)
   unit.text = text
   let ss = new_string_stream(text)
   discard parse(unit.graph, ss, unit.filename, unit.configuration.include_paths,
                 unit.configuration.defines)
   close(ss)


proc open*(unit: var SourceUnit, filename, text, force_configuration_file: string) =
   var search = len(force_configuration_file) == 0
   if not search:
      try:
         unit.configuration = vltoml.parse_file(force_configuration_file)
         log.debug("Using configuration file '$1'.", force_configuration_file)
      except ConfigurationParseError:
         log.error("Failed to parse the forced configuration file '$1', " &
                   "falling back to the regular search strategy.", force_configuration_file)
         search = true

   if search:
      unit.configuration = get_configuration(filename)

   unit.filename = filename
   update(unit, text)


proc close*(unit: var SourceUnit) =
   discard
