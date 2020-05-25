import parsetoml
import strutils
import os

type
   Configuration* = object
      include_paths*: seq[string]
      defines*: seq[string]
      max_nof_diagnostics*: int

   ConfigurationParseError* = object of ValueError


proc new_configuration_parse_error(msg: string, args: varargs[string, `$`]): ref ConfigurationParseError =
   new result
   result.msg = format(msg, args)


proc `$`*(cfg: Configuration): string =
   const INDENT = 2
   if len(cfg.include_paths) > 0:
      add(result, "Include paths:\n")
   for i, path in cfg.include_paths:
      add(result, indent(format("$1: $2", i, path), INDENT) & "\n")

   if len(cfg.defines) > 0:
      add(result, "Defines:\n")
   for i, define in cfg.defines:
      add(result, indent(format("$1: $2", i, define), INDENT) & "\n")

   add(result, "Maximum number of diagnostic messages: ")
   if cfg.max_nof_diagnostics < 0:
      add(result, "unlimited")
   else:
      add(result, $cfg.max_nof_diagnostics)


proc init*(cfg: var Configuration) =
   set_len(cfg.include_paths, 0)
   set_len(cfg.defines, 0)
   cfg.max_nof_diagnostics = -1


proc find_configuration_file*(path: string): string =
   const FILENAMES = [".vls.toml", "vls.toml", ".vls/.vls.toml", ".vls/vls.toml",
                      "vls/.vls.toml", "vls/vls.toml"]
   let expanded_path =
      try:
         expand_filename(path)
      except OSError:
         return ""

   # Walk from the provided path up to the root directory, searching for a
   # configuration file.
   for p in parent_dirs(expanded_path, false, true):
      for filename in FILENAMES:
         let tmp = p / filename
         if file_exists(tmp):
            return tmp


template ensure_array(t: TomlValueRef, scope: string) =
   if t.kind != TomlValueKind.Array:
      raise new_configuration_parse_error("An array is expected for value '$1'.", scope)


template ensure_string(t: TomlValueRef, scope: string) =
   if t.kind != TomlValueKind.String:
      raise new_configuration_parse_error("Expected a string when parsing '$1'.", scope)


template ensure_int(t: TomlValueRef, scope: string) =
   if t.kind != TomlValueKind.Int:
      raise new_configuration_parse_error("Expected an integer when parsing '$1'.", scope)


proc parse_verilog_table(t: TomlValueRef, cfg: var Configuration) =
   if has_key(t, "include_paths"):
      let include_paths = t["include_paths"]
      ensure_array(include_paths, "verilog.include_paths")
      for val in get_elems(include_paths):
         ensure_string(val, "verilog.include_paths")
         add(cfg.include_paths, strip(get_str(val)))

   if has_key(t, "defines"):
      let defines = t["defines"]
      ensure_array(defines, "verilog.defines")
      for val in get_elems(defines):
         ensure_string(val, "verilog.defines")
         add(cfg.defines, get_str(val))


proc parse_vls_table(t: TomlValueRef, cfg: var Configuration) =
   if has_key(t, "max_nof_diagnostics"):
      let val = t["max_nof_diagnostics"]
      ensure_int(val, "vls.max_nof_diagnostics")
      cfg.max_nof_diagnostics = get_int(val)


proc parse(t: TomlValueRef): Configuration =
   init(result)
   if has_key(t, "verilog"):
      parse_verilog_table(t["verilog"], result)

   if has_key(t, "vls"):
      parse_vls_table(t["vls"], result)


proc parse_string*(s: string): Configuration =
   # Used by the test framework.
   try:
      result = parse(parsetoml.parse_string(s))
   except TomlError:
      raise new_configuration_parse_error(
         "Error while parsing configuration from a string.")


proc parse_file*(filename: string): Configuration =
   if not exists_file(filename):
      raise new_configuration_parse_error("The file '$1' does not exist.", filename)

   let lfilename = expand_filename(filename)
   try:
      result = parse(parsetoml.parse_file(lfilename))
      # When we're parsing a file, any
      let parent_dir = parent_dir(lfilename)
      for path in mitems(result.include_paths):
         if not is_absolute(path):
            path = join_path(parent_dir, path)
   except TomlError:
      raise new_configuration_parse_error(
         "Error while parsing configuration file '$1'.", lfilename)

