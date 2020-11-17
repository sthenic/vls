import streams
import vltoml
import vparse
import os
when defined(logdebug):
   import times
   import strutils

import ./log

type
   SourceUnit* = object
      filename*: string
      identifier_cache*: IdentifierCache
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


proc update*(unit: var SourceUnit, module_cache: ModuleCache, locations: Locations, text: string,
             cache_submodules: bool) =
   unit.identifier_cache = new_ident_cache()
   unit.graph = new_graph(unit.identifier_cache, module_cache, locations)
   unit.text = text
   let ss = new_string_stream(text)
   when defined(logdebug):
      let t_start = cpu_time()
   discard parse(unit.graph, ss, unit.filename, unit.configuration.include_paths,
                 unit.configuration.defines, cache_submodules)
   when defined(logdebug):
      let t_diff_ms = (cpu_time() - t_start) * 1000
      log.debug("Parsed '$1' in $2 ms.", unit.filename, format_float(t_diff_ms, ffDecimal, 1))
      log.debug("The module cache contains $1 objects.", module_cache.count)
   close(ss)


proc open*(unit: var SourceUnit, module_cache: ModuleCache, locations: Locations,
           filename, text, force_configuration_file: string) =
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
   let parent_dir = parent_dir(filename)
   if parent_dir notin unit.configuration.include_paths:
      add(unit.configuration.include_paths, parent_dir)
   update(unit, module_cache, locations, text, cache_submodules = true)


proc close*(unit: var SourceUnit) =
   discard
