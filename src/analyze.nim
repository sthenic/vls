import strutils
import streams
import os
import vparse

import ./protocol
import ./source_unit
import ./log

type
   AnalyzeError* = object of ValueError


const
   VERILOG_EXTENSIONS = [".v"]


proc new_analyze_error(msg: string, args: varargs[string, `$`]): ref AnalyzeError =
   new result
   result.msg = format(msg, args)


iterator walk_verilog_files(dir: string): string {.inline.} =
   for kind, path in walk_dir(dir):
      let (_, _, ext) = split_file(path)
      if kind == pcFile and ext in VERILOG_EXTENSIONS:
         yield path


iterator walk_module_declarations(filename: string): PNode {.inline.} =
   # Module declarations cannot be nested and must occur on the outer level in
   # the source text,
   let fs = new_file_stream(filename)
   if not is_nil(fs):
      let cache = new_ident_cache()
      var graph: Graph
      log.debug("Parsing file '$1'.", filename)
      open_graph(graph, cache, fs, filename, [], [])
      close(fs)
      if graph.root_node.kind == NkSourceText:
         for s in graph.root_node.sons:
            if s.kind == NkModuleDecl:
               yield s
      close_graph(graph)


iterator walk_module_declarations(include_paths: seq[string]): tuple[filename: string, n: PNode] {.inline.} =
   for dir in include_paths:
      for filename in walk_verilog_files(dir):
         for module in walk_module_declarations(filename):
            yield (filename, module)


iterator walk_include_paths_starting_with(unit: SourceUnit, prefix: string): string {.inline.} =
   const EXTENSIONS = [".vh", ".v"]
   # We don't want to report duplicates, so if the source file's parent directory
   # (always on the include path) already exists, we don't add it again.
   var include_paths = unit.configuration.include_paths
   let parent_dir = parent_dir(unit.filename)
   if parent_dir notin include_paths:
      add(include_paths, parent_dir)

   if is_absolute(prefix):
      # FIXME: Implement
      discard
   else:
      let (head, tail) = split_path(prefix)
      for dir in include_paths:
         let ldir = dir / head
         for (kind, path) in walk_dir(ldir):
            case kind
            of pcFile, pcLinkToFile:
               let (_, name, ext) = split_file(path)
               if ext in EXTENSIONS and starts_with(name, tail):
                  yield name & ext
            of pcDir, pcLinkToDir:
               let last_dir = last_path_part(path)
               if starts_with(last_dir, tail):
                  yield(last_dir & "/")


proc check_syntax(n: PNode, locs: PLocations): seq[LspDiagnostic] =
   case n.kind
   of {NkTokenError, NkCritical}:
      # Create a diagnostic message representing the error node.
      var start: LspPosition
      var message = ""
      if n.loc.file == 0:
         # A zero-valued file index is invalid (and unexpected).
         return
      elif n.loc.file == 1:
         # The error node originates in the current file. Put the diagnostic
         # message at the location in the buffer.
         add(message, format("$1:$2: ", n.loc.line, n.loc.col + 1))
         start = new_lsp_position(int(n.loc.line - 1), int(n.loc.col))
      elif n.loc.file < 0:
         # The error node has been created as a result of a macro expansion.
         # That means that the error node has a virtual location that cannot be
         # marked in the file so we put the diagnostic message at the expansion
         # location.
         # TODO: Improve error messages.
         var map = locs.macro_maps[abs(n.loc.file + 1)]
         var token_idx = n.loc.line
         var inverted_macro_trace: seq[string]
         while true:
            if map.expansion_loc.file > 0:
               # We've fould the physical location, the search is complete.
               add(inverted_macro_trace, format("In expansion of `$1\n", map.name))
               start = new_lsp_position(int(map.expansion_loc.line - 1),
                                        int(map.expansion_loc.col))
               break
            elif map.expansion_loc.file == 0:
               # A zero-valued file index is invalid (and unexpected).
               return
            else:
               let token_loc_pair = map.locations[token_idx]
               add(inverted_macro_trace, format("In expansion of `$1 at $2:$3\n",
                                                map.name, token_loc_pair.y.line,
                                                token_loc_pair.y.col + 1))
               map = locs.macro_maps[abs(map.expansion_loc.file + 1)]

         # The macro trace is inverted since we begin with the error node and
         # search 'outwards'.
         for i in countdown(high(inverted_macro_trace), 0):
            add(message, inverted_macro_trace[i])

      elif n.loc.file > 1:
         # The error node originates from an external file. We have to use the
         # file map to discern where to put the diagnostic message in the
         # current file. Starting at the file index n.loc.file, there should
         # be a clear path leading back to file index 1 (the current file).
         var map = locs.file_maps[n.loc.file - 1]
         var inverted_file_trace: seq[string]
         while true:
            if map.loc.file == 1:
               # The search is complete, we've found a location in the current
               # file. Set the start location to the location reported by the map.
               add(inverted_file_trace, format("In file $1\n", map.filename))
               add(message, format("$1:$2: ", n.loc.line, n.loc.col + 1))
               start = new_lsp_position(int(map.loc.line - 1), int(map.loc.col))
               break
            elif map.loc.file == 0:
               # A zero-valued file index is invalid (and unexpected).
               return
            else:
               # FIXME: Is a macro expected? `include from a macro?
               add(inverted_file_trace, format("In file $1\n", map.filename))
               map = locs.file_maps[map.loc.file - 1]

         # The file trace is inverted since we begin with the error node and
         # search 'outwards'.
         for i in countdown(high(inverted_file_trace), 0):
            add(message, inverted_file_trace[i])

      let stop = start

      add(message, n.msg)
      if len(n.eraw) > 0:
         add(message, " " & n.eraw)

      result = @[new_lsp_diagnostic(start, stop, ERROR, message)]

   of PrimitiveTypes - {NkTokenError, NkCritical}:
      # Don't generate a diagnostic message for other primitive types
      # (synchronization events included).
      discard

   else:
      for s in n.sons:
         add(result, check_syntax(s, locs))


proc check_syntax*(unit: SourceUnit): seq[LspDiagnostic] =
   result = check_syntax(unit.graph.root_node, unit.graph.locations)


proc find_module_declaration(unit: SourceUnit, identifier: PIdentifier): LspLocation =
   for filename, module in walk_module_declarations(unit.configuration.include_paths):
      for s in module.sons:
         if s.kind == NkModuleIdentifier and s.identifier.s == identifier.s:
            return new_lsp_location(construct_uri(filename), int(s.loc.line - 1),
                                    int(s.loc.col), len(s.identifier.s))
   raise new_analyze_error("Failed to find the declaration of module '$1'.", identifier.s)


proc find_module_port_declaration(unit: SourceUnit, module_id, port_id: PIdentifier): LspLocation =
   for filename, module in walk_module_declarations(unit.configuration.include_paths):
      let id = find_first(module, NkModuleIdentifier)
      if is_nil(id) or id.identifier.s != module_id.s:
         continue

      # We've found the module. Start going through the ports looking for a match.
      for port in walk_ports(module):
         case port.kind
         of NkPortDecl:
            let id = find_first(port, NkPortIdentifier)
            if not is_nil(id) and id.identifier.s == port_id.s:
               return new_lsp_location(construct_uri(filename),
                                       int(id.loc.line - 1),
                                       int(id.loc.col),
                                       len(id.identifier.s))
         of NkPort:
            # If we find a port identifier as the first node, that's the
            # name that this port is known by from the outside. Otherwise,
            # we're looking for the first identifier in a port reference.
            let id = find_first(port, NkPortIdentifier)
            if not is_nil(id) and id.identifier.s == port_id.s:
               return new_lsp_location(construct_uri(filename),
                                       int(id.loc.line - 1),
                                       int(id.loc.col),
                                       len(id.identifier.s))
            else:
               let port_ref = find_first(port, NkPortReference)
               if not is_nil(port_ref):
                  let id = find_first(port_ref, NkPortIdentifier)
                  if not is_nil(id) and id.identifier.s == port_id.s:
                     return new_lsp_location(construct_uri(filename),
                                             int(id.loc.line - 1),
                                             int(id.loc.col),
                                             len(id.identifier.s))
         else:
            discard

   raise new_analyze_error("Failed to find the declaration of port '$1'.", port_id.s)


proc find_module_parameter_port_declaration(unit: SourceUnit, module_id, parameter_id: PIdentifier): LspLocation =
   for filename, module in walk_module_declarations(unit.configuration.include_paths):
      let id = find_first(module, NkModuleIdentifier)
      if is_nil(id) or id.identifier.s != module_id.s:
         continue

      for parameter in walk_parameter_ports(module):
         let assignment = find_first(parameter, NkParamAssignment)
         if not is_nil(assignment):
            let id = find_first(assignment, NkParameterIdentifier)
            if not is_nil(id) and id.identifier.s == parameter_id.s:
               return new_lsp_location(construct_uri(filename), int(id.loc.line - 1),
                                       int(id.loc.col), len(id.identifier.s))

   raise new_analyze_error("Failed to find the declaration of parameter port '$1'.", parameter_id.s)


proc is_external_identifier(context: AstContext): bool =
   # An external identifier is either a module instantiation or.
   if len(context) > 0:
      let n = context[^1].n
      let pos = context[^1].pos
      case n.kind
      of NkModuleInstantiation:
         # TODO: This fails to find a module declaration if it's located in the
         #       same file (context) and the file itself is _not_ on the include
         #       path.
         result = true
      of NkPortConnection:
         # We only perform an external lookup if the target identifier is the
         # one following the dot.
         var seen_another_identifier = false
         for i in 0..<pos:
            seen_another_identifier = (n.sons[i].kind == NkIdentifier)
         result = not seen_another_identifier
      of NkAssignment:
         if len(context) > 1:
            # We only perform an external lookup if the target identifier is the
            # one following the dot.
            var seen_another_identifier = false
            for i in 0..<pos:
               seen_another_identifier = (n.sons[i].kind == NkIdentifier)
            result = context[^2].n.kind == NkParameterValueAssignment and not seen_another_identifier
      else:
         result = false
   else:
      result = false


proc find_internal_declaration(unit: SourceUnit, context: AstContext, identifier: PIdentifier): LspLocation =
   log.debug("Looking up an internal declaration for '$1'.", identifier.s)
   let (n, _) = find_declaration(context, identifier, true)
   if not is_nil(n):
      let uri = construct_uri(unit.graph.locations.file_maps[n.loc.file - 1].filename)
      result = new_lsp_location(uri, int(n.loc.line - 1), int(n.loc.col), len(n.identifier.s))
   else:
      raise new_analyze_error("Failed to find the declaration of identifier '$1'.", identifier.s)


proc find_external_declaration(unit: SourceUnit, context: AstContext, identifier: PIdentifier): LspLocation =
   log.debug("Looking up an external declaration for '$1'.", identifier.s)
   case context[^1].n.kind
   of NkModuleInstantiation:
      result = find_module_declaration(unit, identifier)
   of NkPortConnection:
      # We first need to find the name of the module before we can proceed with
      # the lookup.
      let module = find_first(context[^3].n, IdentifierTypes)
      if not is_nil(module):
         result = find_module_port_declaration(unit, module.identifier, identifier)
   of NkAssignment:
      # When this proc is called, it's already been established that an
      # assignment node implies that we should look for an external port
      # declaration. But before we can do that, we need the module name.
      let module = find_first(context[^3].n, IdentifierTypes)
      if not is_nil(module):
         result = find_module_parameter_port_declaration(unit, module.identifier, identifier)
   else:
      raise new_analyze_error("Invalid context for an external declaration lookup.")


proc get_include_file(unit: SourceUnit, filename: string): string =
   let path_relative_parent_dir = parent_dir(unit.filename) / filename
   if file_exists(path_relative_parent_dir):
      return path_relative_parent_dir
   else:
      for dir in unit.configuration.include_paths:
         let tmp = dir / filename
         if file_exists(tmp):
            return tmp


proc find_include_directive(unit: SourceUnit, loc: Location): LspLocation =
   let ss = new_string_stream(unit.text)
   if is_nil(ss):
      raise new_analyze_error("Failed to create a stream for file '$1'.", unit.filename)

   let cache = new_ident_cache()
   var lexer: Lexer
   open_lexer(lexer, cache, ss, unit.filename, 1)
   var tok: Token
   var tok_prev: Token
   init(tok_prev)
   get_token(lexer, tok)
   while tok.kind != TkEndOfFile:
      # If the target location points to the string argument of an include
      # directory, we construct an LSP location pointing to the target file if
      # it exists on the current path. We have to add two to the length since
      # the actual string literal token is enclosed in two double quotes (").
      if (
         tok.kind == TkStrLit and
         in_bounds(loc, tok.loc, len(tok.literal) + 2) and
         tok_prev.kind == TkDirective and
         tok_prev.identifier.s == "include"
      ):
         let filename = get_include_file(unit, tok.literal)
         if len(filename) > 0:
            close_lexer(lexer)
            close(ss)
            return new_lsp_location(construct_uri(filename), 0, 0, 0)
         else:
            break

      tok_prev = tok
      get_token(lexer, tok)
   close_lexer(lexer)
   close(ss)
   raise new_analyze_error("Failed to find an include directive at the target location.")


proc find_declaration*(unit: SourceUnit, line, col: int): LspLocation =
   ## Find where the identifier at (``line``, ``col``) is declared. This proc
   ## returns an LSP locations if successful. Otherwise, it raises an AnalyzeError.
   let g = unit.graph

   # Before we can assume that the input location is pointing to an identifier,
   # we have to deal with the possibility that it's pointing to a macro.
   let loc = new_location(1, line, col)
   for map in g.locations.macro_maps:
      # +1 is to compensate for the expansion location starting at the backtick.
      if in_bounds(loc, map.expansion_loc, len(map.name) + 1):
         let uri = construct_uri(g.locations.file_maps[map.define_loc.file - 1].filename)
         return new_lsp_location(uri, int(map.define_loc.line - 1), int(map.define_loc.col),
                                 len(map.name))

   # We begin by finding the identifier at the input position, keeping in mind
   # that the position doesn't have point to the start of the token. The return
   # value is nil if there's no identifier at the target location. In that case,
   # we check if the location points to the string literal in an include
   # directive. If it's a valid path, we return the location to that file.
   var context: AstContext
   init(context, 32)
   let identifier = find_identifier_physical(g.root_node, g.locations, loc, context)
   if is_nil(identifier):
      return find_include_directive(unit, loc)

   # We have to determine if we should look for an internal (in the context) or
   # an external declaration. In the case of the latter, we only support lookup
   # of module instantiations and their ports.
   if is_external_identifier(context):
      result = find_external_declaration(unit, context, identifier.identifier)
   else:
      result = find_internal_declaration(unit, context, identifier.identifier)


proc find_references(unit: SourceUnit, context: AstContextItem, identifier: PIdentifier,
                     include_declaration: bool): seq[LspLocation] =
   let start = if include_declaration: context.pos else: context.pos + 1
   var seen_locations = new_seq_of_cap[Location](32)
   for i in countup(start, high(context.n.sons)):
      for n in find_references(context.n.sons[i], identifier):
         var loc = n.loc
         # Translate virtual locations into physical locations.
         if n.loc.file < 0:
            loc = to_physical(unit.graph.locations, n.loc)
         # Only add the location if we haven't seen it before.
         if loc notin seen_locations:
            let uri = construct_uri(unit.graph.locations.file_maps[loc.file - 1].filename)
            add(result, new_lsp_location(uri, int(loc.line - 1), int(loc.col), len(n.identifier.s)))
            add(seen_locations, loc)


proc find_references*(unit: SourceUnit, line, col: int, include_declaration: bool): seq[LspLocation] =
   # Before we can assume that the input location is pointing to an identifier,
   # we have to deal with the possibility that it's pointing to a macro.
   let g = unit.graph
   let loc = new_location(1, line, col)
   for map in g.locations.macro_maps:
      # +1 is to compensate for the expansion location starting at the backtick.
      if in_bounds(loc, map.define_loc, len(map.name)) or in_bounds(loc, map.expansion_loc, len(map.name) + 1):
         # If we find a match, loop through the macro maps again, looking for all
         # maps that use the same macro definition as the one we just found.
         if include_declaration:
            let uri = construct_uri(g.locations.file_maps[map.define_loc.file - 1].filename)
            add(result, new_lsp_location(uri, int(map.define_loc.line - 1), int(map.define_loc.col),
                                         len(map.name)))
         var seen_locations = new_seq_of_cap[Location](32)
         for m in g.locations.macro_maps:
            if m.define_loc == map.define_loc:
               var expansion_loc = m.expansion_loc
               if expansion_loc.file < 0:
                  expansion_loc = to_physical(g.locations, expansion_loc)
               if expansion_loc notin seen_locations:
                  let uri = construct_uri(g.locations.file_maps[expansion_loc.file - 1].filename)
                  add(result, new_lsp_location(uri, int(expansion_loc.line - 1),
                                               int(expansion_loc.col) + 1, len(m.name)))
                  add(seen_locations, expansion_loc)
         return

   var identifier_context: AstContext
   init(identifier_context, 32)
   let identifier = find_identifier_physical(g.root_node, g.locations, loc, identifier_context)
   if is_nil(identifier):
      raise new_analyze_error("Failed to find an identifer at the target location.")

   # We have to revert the identifier match if it turns out it's the first
   # identifier in a port connection node. That's the port name, so there
   # shouldn't be any references reported in that case.
   if len(identifier_context) > 0:
      let c = identifier_context[^1]
      if c.n.kind == NkPortConnection and c.pos == find_first_index(c.n, NkIdentifier):
         raise new_analyze_error("Failed to find an identifer at the target location.")

   let (declaration, declaration_context) = find_declaration(identifier_context, identifier.identifier, true)
   if is_nil(declaration):
      raise new_analyze_error("Failed to find the declaration of identifier '$1'.", identifier.identifier.s)

   result = find_references(unit, declaration_context, identifier.identifier, include_declaration)


proc find_completable_token_at(unit: SourceUnit, loc: Location, cache: IdentifierCache): Token =
   # Completable tokens are identifiers, and string literals that are arguments
   # to an include directive. In the case of the former, we have to pretend
   # that the token length is one character longer than it is in reality to
   # allow completion when the cursor (input location) is placed after the
   # last character. In the case of the latter, we have to add two to the
   # length since the actual string literal token is enclosed in two double
   # quotes (").
   template is_completable_identifier(tok: Token, loc: Location): bool =
      not is_nil(tok.identifier) and in_bounds(loc, tok.loc, len(tok.identifier.s) + 1)
   template is_completable_string_literal(tok, tok_prev: Token, loc: Location): bool =
      tok.kind == TkStrLit and
      in_bounds(loc, tok.loc, len(tok.literal) + 2) and
      tok_prev.kind == TkDirective and
      tok_prev.identifier.s == "include"

   let ss = new_string_stream(unit.text)
   if is_nil(ss):
      raise new_analyze_error("Failed to create a stream for file '$1'.", unit.filename)

   init(result)
   var lexer: Lexer
   open_lexer(lexer, cache, ss, unit.filename, 1)
   var tok: Token
   var tok_prev: Token
   init(tok_prev)
   get_token(lexer, tok)
   while tok.kind != TkEndOfFile:
      if is_completable_identifier(tok, loc) or is_completable_string_literal(tok, tok_prev, loc):
         result = tok
         break
      tok_prev = tok
      get_token(lexer, tok)
   close_lexer(lexer)
   close(ss)


proc find_completions*(unit: SourceUnit, line, col: int): seq[LspCompletionItem] =
   # We can be faced with one of two situations: either
   #   1. the AST is intact at least up until the target location; or
   #   2. the AST is broken and attempting to find an identifier at the target
   #      location will not be successful.
   # The ideal case is (1) because we can construct a more accurate list of
   # completion items if we know the context AST. However, if we're faced with
   # (2), we still want to return something. We run the lexer to manually
   # tokenize the file and attempt to find an identifier at the target location
   # TODO: We should perhaps add some fuzzy matching?
   let loc = new_location(1, line, col)
   var context: AstContext
   let identifier = find_identifier_physical(unit.graph.root_node, unit.graph.locations,
                                             loc, context, added_length = 1)
   if not is_nil(identifier):
      let prefix = substr(identifier.identifier.s, 0, loc.col - identifier.loc.col - 1)
      for n in walk_nodes_starting_with(find_all_declarations(context, true), prefix):
         add(result, new_lsp_completion_item(n.identifier.s))
   else:
      let cache = new_ident_cache()
      let tok = find_completable_token_at(unit, loc, cache)
      case tok.kind
      of TkSymbol, TkDirective:
         let prefix = substr(tok.identifier.s, 0, loc.col - tok.loc.col - 1)
         for id in walk_identifiers_starting_with(cache, prefix):
            add(result, new_lsp_completion_item(id.s))
      of TkStrLit:
         let prefix = substr(tok.literal, 0, loc.col - tok.loc.col - 2)
         for path in walk_include_paths_starting_with(unit, prefix):
            add(result, new_lsp_completion_item(path))
         log.debug("Found include string '$1', $2.", prefix, loc.col - tok.loc.col - 2)
      else:
         raise new_analyze_error("Failed to find a token at the target location.")


proc find_symbols*(unit: SourceUnit): seq[LspSymbolInformation] =
   # Add an entry for each declaration in the AST.
   for n in find_all_declarations(unit.graph.root_node, true):
      # Filter out declarations not in the current file.
      if n.loc.file != 1:
         continue
      let loc = new_lsp_location(construct_uri(unit.filename),
                                 int(n.loc.line - 1),
                                 int(n.loc.col), len(n.identifier.s))
      add(result, new_lsp_symbol_information(n.identifier.s, LspSkVariable, loc))

   # Add an entry for each module instantiation in the AST.
   for n in find_all_module_instantiations(unit.graph.root_node):
      if n.loc.file != 1:
         continue
      let loc = new_lsp_location(construct_uri(unit.filename),
                                 int(n.loc.line - 1),
                                 int(n.loc.col), len(n.identifier.s))
      add(result, new_lsp_symbol_information(n.identifier.s, LspSkModule, loc))


proc rename_symbol*(unit: SourceUnit, line, col: int, new_name: string): seq[LspTextDocumentEdit] =
   # Renaming a symbol is the same as first finding all references (including the declaration)
   # and constructing the text edits describing the changes based on that.
   for loc in find_references(unit, line, col, true):
      let text_edit = new_lsp_text_edit(loc.range.start, loc.range.stop, new_name)
      add(result, new_lsp_text_document_edit(loc.uri, [text_edit]))


proc document_highlight*(unit: SourceUnit, line, col: int): seq[LspDocumentHighlight] =
   ## Highlight all references to the symbol at the target position.
   let uri = construct_uri(unit.filename)
   for loc in find_references(unit, line, col, true):
      # Ensure that only references from the current file show up in the output.
      if loc.uri != uri:
         continue
      add(result, new_lsp_document_highlight(loc.range.start, loc.range.stop, LspHkText))
