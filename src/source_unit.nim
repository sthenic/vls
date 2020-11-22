import streams
import vltoml
import vparse
import os
import tables
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


proc cache_workspace(unit: SourceUnit) =
   # TODO: Think about doing this in another thread and updating/merging the
   #       module cache once the operation is complete.
   log.debug("Caching workspace.")
   when defined(logdebug):
      let t_start = cpu_time()
   let cache = new_ident_cache()
   let graph = new_graph(cache, unit.graph.module_cache, unit.graph.locations)
   for filename in walk_verilog_files(unit.configuration.include_paths):
      let fs = new_file_stream(filename)
      if is_nil(fs):
         continue
      elif not has_matching_checksum(unit.graph.module_cache, filename, compute_md5(fs)):
         discard parse(graph, fs, filename, unit.configuration.include_paths,
                       unit.configuration.defines, cache_submodules = false)
      close(fs)
   when defined(logdebug):
      let t_diff_ms = (cpu_time() - t_start) * 1000
      log.debug("Cached workspace in $1 ms.", format_float(t_diff_ms, ffDecimal, 1))
      log.debug("The module cache contains $1 objects.", unit.graph.module_cache.count)


proc get_configuration*(source_filename: string): Configuration =
   # Search for a configuration file starting at the ``source_filename`` and
   # walking up to the root directory. If we find a file but fail to parse it,
   # we fall back to default values. The ``VLS`` define is always added to the
   # list of external defines.
   log.debug("Searching for a configuration file.")
   let filename = find_configuration_file(source_filename)
   init(result)
   if len(filename) > 0:
      try:
         result = vltoml.parse_file(filename)
         if "VLS" notin result.defines:
            add(result.defines, "VLS")
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
   if unit.configuration.cache_workspace_on_open:
      cache_workspace(unit)


proc close*(unit: var SourceUnit) =
   discard
