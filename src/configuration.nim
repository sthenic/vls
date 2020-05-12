import parsetoml
import strutils
import os

type
   Configuration* = object
      include_paths*: seq[string]
      defines*: seq[string]

   ConfigurationParseError* = object of ValueError


proc new_configuration_parse_error(msg: string, args: varargs[string, `$`]): ref ConfigurationParseError =
   new result
   result.msg = format(msg, args)


proc find_configuration_file*(path: string): string =
   const FILENAMES = [".vls.toml", "vls.toml", ".vls/.vls.toml", ".vls/vls.toml",
                      "vls/.vls.toml", "vls/vls.toml"]
   # Walk from the provided path up to the root directory, searching for a
   # configuration file.
   for p in parent_dirs(expand_filename(path), false, true):
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


proc parse(t: TomlValueRef): Configuration =
   if has_key(t, "verilog"):
      if has_key(t["verilog"], "include_paths"):
         let include_paths = t["verilog"]["include_paths"]
         ensure_array(include_paths, "verilog.include_paths")
         for val in get_elems(include_paths):
            ensure_string(val, "verilog.include_paths")
            add(result.include_paths, get_str(val))
      else:
         set_len(result.include_paths, 0)

      if has_key(t["verilog"], "defines"):
         let defines = t["verilog"]["defines"]
         ensure_array(defines, "verilog.defines")
         for val in get_elems(defines):
            ensure_string(val, "verilog.defines")
            add(result.defines, get_str(val))
      else:
         set_len(result.defines, 0)


proc parse_string*(s: string): Configuration =
   # Used by the test framework.
   try:
      result = parse(parsetoml.parse_string(s))
   except TomlError:
      raise new_configuration_parse_error(
         "Error while parsing configuration from a string.")


proc parse_file*(filename: string): Configuration =
   try:
      result = parse(parsetoml.parse_file(filename))
   except TomlError:
      raise new_configuration_parse_error(
         "Error while parsing configuration file '$1'.", filename)

