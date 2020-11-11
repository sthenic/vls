import strutils
import streams
import os
import vparse
import vlint

import ./protocol
import ./source_unit
import ./log

type
   AnalyzeError* = object of ValueError

   LocalParser {.final.} = object
      lex: Lexer
      tok: Token
      next_tok: Token

   ModulePortConnection = tuple
      module: Token
      cursor: Token
      is_parameter: bool


const
   VERILOG_EXTENSIONS = [".v"]


proc new_analyze_error(msg: string, args: varargs[string, `$`]): ref AnalyzeError =
   new result
   result.msg = format(msg, args)


proc get_token(p: var LocalParser) =
   p.tok = p.next_tok
   if p.next_tok.kind != TkEndOfFile:
      get_token(p.lex, p.next_tok)
      while p.next_tok.kind in {TkComment, TkBlockComment}:
         get_token(p.lex, p.next_tok)


proc open_local_parser(p: var LocalParser, cache: IdentifierCache, s: Stream, filename: string) =
   init(p.tok)
   init(p.next_tok)
   open_lexer(p.lex, cache, s, filename, 1)
   get_token(p)


proc close_local_parser(p: var LocalParser) =
   close_lexer(p.lex)


template run_local_parser(unit: SourceUnit, cache: IdentifierCache, parser, body: untyped) =
   let ss = new_string_stream(unit.text)
   if is_nil(ss):
      raise new_analyze_error("Failed to create a stream for file '$1'.", unit.filename)

   var parser: LocalParser
   open_local_parser(parser, cache, ss, unit.filename)
   get_token(parser)
   while parser.tok.kind != TkEndOfFile:
      body

   close_local_parser(parser)
   close(ss)


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
      let graph = new_graph(cache)
      log.debug("Parsing file '$1'.", filename)
      let configuration = get_configuration(filename)
      let root = parse(graph, fs, filename, configuration.include_paths, configuration.defines)
      close(fs)
      if root.kind == NkSourceText:
         for s in root.sons:
            if s.kind == NkModuleDecl:
               yield s


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
   result = check_syntax(unit.graph.root, unit.graph.locations)


proc construct_diagnostic(n: PNode, severity: LspSeverity,
                          msg: string, args: varargs[string, `$`]): LspDiagnostic =
   var lmsg = format("$1:$2: ", n.loc.line, n.loc.col + 1) & format(msg, args)
   let start = new_lsp_position(int(n.loc.line - 1), int(n.loc.col))
   let stop = start
   result = new_lsp_diagnostic(start, stop, severity, lmsg)


proc find_undeclared_identifiers*(unit: SourceUnit): seq[LspDiagnostic] =
   if not unit.configuration.diagnostics.undeclared_identifiers:
      return

   # FIXME: Find redeclared identifiers.
   let (internal, external) = find_undeclared_identifiers(unit.graph)
   for id in internal & external:
      if id.loc.file != 1:
         continue
      add(result, construct_diagnostic(id, ERROR, "Undeclared identifier '$1'.", id.identifier.s))


proc find_port_connection_errors*(unit: SourceUnit):
      seq[LspDiagnostic] =
   # To avoid doing unnecessary work, check the configuration if these
   # diagnostics are both disabled.
   if not unit.configuration.diagnostics.missing_ports and
      not unit.configuration.diagnostics.unconnected_ports:
      return

   for error in find_connection_errors(unit.graph):
      case error.kind
      of CkMissing:
         if unit.configuration.diagnostics.missing_ports:
            add(result, construct_diagnostic(error.instance, ERROR, "Missing port '$1'.",
                                             error.identifier.s))
      of CkUnconnected:
         if unit.configuration.diagnostics.unconnected_ports:
            let port = find_first(error.meta, NkIdentifier)
            add(result, construct_diagnostic(port, ERROR, "Unconnected input port '$1'.",
                                             port.identifier.s))


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
      of NkNamedPortConnection, NkNamedParameterAssignment:
         # We only perform an external lookup if the target identifier is the
         # one following the dot.
         var seen_another_identifier = false
         for i in 0..<pos:
            seen_another_identifier = (n.sons[i].kind == NkIdentifier)
         result = not seen_another_identifier
      else:
         result = false
   else:
      result = false


proc find_internal_declaration(unit: SourceUnit, context: AstContext, identifier: PIdentifier):
      tuple[declaration, identifier: PNode, filename: string] =
   log.debug("Looking up an internal declaration for '$1'.", identifier.s)
   let (decl, id, _, _) = find_declaration(context, identifier)
   if not is_nil(decl):
      let filename = unit.graph.locations.file_maps[id.loc.file - 1].filename
      result = (decl, id, filename)
   else:
      raise new_analyze_error("Failed to find the declaration of identifier '$1'.", identifier.s)


proc find_external_declaration(unit: SourceUnit, context: AstContext, identifier: PIdentifier):
      tuple[declaration, identifier: PNode, filename: string] =
   log.debug("Looking up an external declaration for '$1'.", identifier.s)
   result = find_external_declaration(unit.graph, context, identifier)
   if is_nil(result.declaration):
      raise new_analyze_error("External declaration lookup failed (no match).")


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
   let cache = new_ident_cache()
   var found = false
   run_local_parser(unit, cache, parser):
      # If the target location points to the string argument of an include
      # directory, we construct an LSP location pointing to the target file if
      # it exists on the current path. We have to add two to the length since
      # the actual string literal token is enclosed in two double quotes (").
      if (
         parser.tok.kind == TkDirective and
         parser.tok.identifier.s == "include" and
         parser.next_tok.kind == TkStrLit and
         in_bounds(loc, parser.next_tok.loc, len(parser.next_tok.literal) + 2)
      ):
         let filename = get_include_file(unit, parser.next_tok.literal)
         if len(filename) > 0:
            result = new_lsp_location(construct_uri(filename), 0, 0, 0)
            found = true
         break
      get_token(parser)

   if not found:
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
   let identifier = find_identifier_physical(g.root, g.locations, loc, context)
   if is_nil(identifier):
      return find_include_directive(unit, loc)

   # We have to determine if we should look for an internal (in the context) or
   # an external declaration. In the case of the latter, we only support lookup
   # of module instantiations and their ports.
   let (_, id, filename) =  if is_external_identifier(context):
      find_external_declaration(unit, context, identifier.identifier)
   else:
      find_internal_declaration(unit, context, identifier.identifier)

   result = new_lsp_location(
      construct_uri(filename), int(id.loc.line - 1), int(id.loc.col), len(id.identifier.s)
   )


proc find_module_references*(unit: SourceUnit, identifier: PIdentifier,
                             include_declaration: bool): seq[LspLocation] =
   for filename, module in walk_module_declarations(unit.configuration.include_paths):
      let module_name = find_first(module, NkIdentifier)
      if include_declaration and not is_nil(module_name) and module_name.identifier.s == identifier.s:
         # Recursive declarations are not expected. So if we find the target
         # module's declaration, we skip looking for instantiations.
         add(result, new_lsp_location(construct_uri(filename),
                                      int(module_name.loc.line - 1),
                                      int(module_name.loc.col),
                                      len(module_name.identifier.s)))
         continue

      for module_instantiation in find_all_module_instantiations(module):
         let module_name = find_first(module_instantiation, NkIdentifier)
         if is_nil(module_name) or module_name.identifier.s != identifier.s:
            continue

         for s in walk_sons(module_instantiation, NkModuleInstance):
            let module_instance_name = find_first(s, NkIdentifier)
            if is_nil(module_instance_name):
               continue
            # TODO: Need to map module_instance_name.loc to a physical location?
            #       If so we need to extract the graph's locations.
            add(result, new_lsp_location(construct_uri(filename),
                                         int(module_instance_name.loc.line - 1),
                                         int(module_instance_name.loc.col),
                                         len(module_instance_name.identifier.s)))


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


proc find_references_in_list_of_ports(unit: SourceUnit, context: AstContext,
                                      identifier: PIdentifier): seq[LspLocation] =
   # This function exists to be able to locate the out-of-tree references to a
   # port when targeting any of its identifiers within the module body. We have
   # to detect if this function is called and the target identifier is within
   # the list of ports. In this case it's not an out-of-tree reference and we
   # should abort the search to avoid generating a duplicate entry.
   var module: PNode = nil
   for i in countdown(high(context), 0):
      if context[i].n.kind == NkListOfPorts:
         return
      elif context[i].n.kind == NkModuleDecl:
         module = context[i].n
         break
   if is_nil(module):
      return

   for port_ref in walk_port_references(module):
      let id = find_first(port_ref, NkIdentifier)
      if not is_nil(id) and id.identifier.s == identifier.s:
         let uri = construct_uri(unit.graph.locations.file_maps[id.loc.file - 1].filename)
         add(result, new_lsp_location(uri, int(id.loc.line - 1), int(id.loc.col), len(id.identifier.s)))


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
   let identifier = find_identifier_physical(g.root, g.locations, loc, identifier_context)
   if is_nil(identifier):
      raise new_analyze_error("Failed to find an identifer at the target location.")

   # Here we handle two special cases of the reference lookup:
   # - We have to abort the request if it turns out that we're targeting the
   #   first identifier in named port/parameter connection node. That's the port
   #   name, so there shouldn't be any references reported in that case.
   # - If we're targeting a module instantiation or the identifier in the module
   #   declaration itself, we look up all references to this module by browsing
   #   the include path.
   if len(identifier_context) > 0:
      let c = identifier_context[^1]
      if c.n.kind in {NkNamedPortConnection, NkNamedParameterAssignment} and
            c.pos == find_first_index(c.n, NkIdentifier):
         raise new_analyze_error("Failed to find an identifer at the target location.")
      elif c.n.kind == NkModuleInstantiation or
           c.n.kind == NkModuleDecl and c.pos == find_first_index(c.n, NkIdentifier):
         return find_module_references(unit, identifier.identifier, include_declaration)

   let (declaration, _, _, declaration_context) = find_declaration(identifier_context, identifier.identifier)
   if is_nil(declaration):
      raise new_analyze_error("Failed to find the declaration of identifier '$1'.", identifier.identifier.s)

   result = find_references(unit, declaration_context, identifier.identifier, include_declaration)
   # If we're targeting a port, we have to make an extra pass through the module
   # declaration looking for references in a potential list of ports. This is
   # the only legal out-of-tree reference that may occur.
   if declaration.kind == NkPortDecl:
      log.debug("Checking for extra things")
      add(result, find_references_in_list_of_ports(unit, identifier_context, identifier.identifier))


proc find_port_connection(p: var LocalParser, loc: Location): Token =
   # We only offer port completions if the cursor is in the whitespace after the
   # '.' character or in the following identifier.
   init(result)
   var paren_count = 0
   var brace_count = 0
   var seen_dot = false
   while true:
      if seen_dot:
         if p.tok.kind == TkSymbol and in_bounds(loc, p.tok.loc, len(p.tok.identifier.s) + 1):
            result = p.tok
            return
         elif p.tok.loc > loc:
            result.kind = TkDot
            return
      elif p.tok.loc >= loc:
         result.kind = TkInvalid
         return

      seen_dot = false

      case p.tok.kind
      of TkEndOfFile:
         result.kind = TkInvalid
         break
      of TkLbrace:
         inc(brace_count)
      of TkRbrace:
         if brace_count > 0:
            dec(brace_count)
      of TkLparen:
         inc(paren_count)
      of TkRparen:
         if paren_count > 0:
            dec(paren_count)
         else:
            result.kind = TkInvalid
            break
      of TkDot:
         if paren_count == 0 and brace_count == 0:
            seen_dot = true
      else:
         discard
      get_token(p)


proc skip_between(p: var LocalParser, start_kind, stop_kind: TokenKind) =
   var count = 0
   if p.tok.kind != start_kind:
      return
   while true:
      get_token(p)
      if p.tok.kind == TkEndOfFile:
         break
      elif p.tok.kind == start_kind:
         inc(count)
      elif p.tok.kind == stop_kind:
         if count > 0:
            dec(count)
         else:
            get_token(p)
            break


proc parse_module_instantiation(p: var LocalParser, loc: Location): ModulePortConnection =
   if p.tok.kind != TkSymbol:
      result.module.kind = TkInvalid
      return
   result.module = p.tok
   result.is_parameter = false
   get_token(p)

   if p.tok.kind == TkHash and p.next_tok.kind == TkLparen:
      get_token(p)
      get_token(p)
      result.cursor = find_port_connection(p, loc)
      if result.cursor.kind != TkInvalid:
         result.is_parameter = true
         return
      if p.tok.kind != TkRparen:
         result.module.kind = TkInvalid
         return
      else:
         get_token(p)

   while true:
      if p.tok.kind == TkSymbol:
         get_token(p)

      if p.tok.kind == TkLbracket:
         skip_between(p, TkLbracket, TkRbracket)

      if p.tok.kind != TkLparen:
         result.module.kind = TkInvalid
         break
      else:
         get_token(p)
         result.cursor = find_port_connection(p, loc)
         if result.cursor.kind != TkInvalid:
            break

      if p.tok.kind != TkRparen:
         result.module.kind = TkInvalid
         break
      else:
         get_token(p)

      if p.tok.kind != TkComma:
         result.module.kind = TkInvalid
         break

      get_token(p)


proc find_module_port_connection(unit: SourceUnit, loc: Location): ModulePortConnection =
   let cache = new_ident_cache()
   run_local_parser(unit, cache, parser):
      if parser.tok.loc > loc:
         result.module.kind = TkInvalid
         break
      if parser.tok.kind == TkSymbol and parser.next_tok.kind in {TkHash, TkSymbol}:
         result = parse_module_instantiation(parser, loc)
         if result.module.kind != TkInvalid:
            break
      get_token(parser)


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
   template is_completable_string_literal(tok, next_tok: Token, loc: Location): bool =
      tok.kind == TkDirective and tok.identifier.s == "include" and
      next_tok.kind == TkStrLit and in_bounds(loc, next_tok.loc, len(next_tok.literal) + 2)

   run_local_parser(unit, cache, parser):
      if is_completable_identifier(parser.tok, loc):
         result = parser.tok
         break
      elif is_completable_string_literal(parser.tok, parser.next_tok, loc):
         result = parser.next_tok
         break
      get_token(parser)


proc add_declaration_information(unit: SourceUnit, item: var LspCompletionItem, n: PNode) =
   item.detail = $n

   let comment = find_first(n, NkComment)
   item.documentation.kind = LspMkMarkdown
   if not is_nil(comment):
      item.documentation.value = comment.s

   if n.loc.file > 1:
      let filename = extract_filename(unit.graph.locations.file_maps[n.loc.file - 1].filename)
      add(item.documentation.value, "\n\n---\nFile: " & filename)

   case n.kind
   of NkTaskDecl, NkFunctionDecl:
      item.kind = LspCkFunction
   of NkParameterDecl, NkLocalparamDecl, NkSpecparamDecl:
      item.kind = LspCkConstant
   of NkPortDecl, NkPort:
      item.kind = LspCkInterface
   else:
      item.kind = LspCkVariable


proc find_port_connection_completions(unit: SourceUnit, module_name, prefix: string): seq[LspCompletionItem] =
   # FIXME: Faster lookup by name instead of going through all the modules.
   for module, name, filename in walk_modules(unit.graph, WalkDefined):
      if name != module_name:
         continue

      for port, id in walk_ports(module):
         if starts_with(id.identifier.s, prefix):
            var item = new_lsp_completion_item(id.identifier.s & " ()")
            add_declaration_information(unit, item, port)
            add(result, item)
      return


proc find_parameter_port_connection_completions(unit: SourceUnit, module_name, prefix: string): seq[LspCompletionItem] =
   # FIXME: Faster lookup by name instead of going through all the modules.
   for module, name, filename in walk_modules(unit.graph, WalkDefined):
      if name != module_name:
         continue

      for declaration, id in walk_parameters(module):
         if starts_with(id.identifier.s, prefix):
            var item = new_lsp_completion_item(id.identifier.s & " ()")
            add_declaration_information(unit, item, declaration)
            add(result, item)
      return


proc find_completions*(unit: SourceUnit, line, col: int): seq[LspCompletionItem] =
   # TODO: We should perhaps add some fuzzy matching?
   # Before we do anything else, we check if the target location is pointing to
   # a port connection. If the module is on the include path, we fetch the
   # completion information from the external file and return early.
   let loc = new_location(1, line, col)
   let (module, cursor, is_parameter) = find_module_port_connection(unit, loc)
   if module.kind != TkInvalid:
      let prefix = if cursor.kind == TkSymbol:
         substr(cursor.identifier.s, 0, loc.col - cursor.loc.col - 1)
      else:
         ""
      if is_parameter:
         return find_parameter_port_connection_completions(unit, module.identifier.s, prefix)
      else:
         return find_port_connection_completions(unit, module.identifier.s, prefix)

   # Now we can be faced with one of two situations: either
   #   1. the AST is intact at least up until the target location; or
   #   2. the AST is broken and attempting to find an identifier at the target
   #      location will not be successful.
   # The ideal case is (1) because we can construct a more accurate list of
   # completion items if we know the context AST. However, if we're faced with
   # (2), we still want to return something. We run the lexer to manually
   # tokenize the file and attempt to find an identifier at the target location
   var context: AstContext
   let identifier = find_identifier_physical(unit.graph.root, unit.graph.locations,
                                             loc, context, added_length = 1)
   if not is_nil(identifier):
      let prefix = substr(identifier.identifier.s, 0, loc.col - identifier.loc.col - 1)
      for (declaration, identifier) in find_all_declarations(context):
         if starts_with(identifier.identifier.s, prefix):
            var item = new_lsp_completion_item(identifier.identifier.s)
            add_declaration_information(unit, item, declaration)
            add(result, item)
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
            var item = new_lsp_completion_item(path)
            item.kind = LspCkFile
            add(result, item)
         log.debug("Found include string '$1', $2.", prefix, loc.col - tok.loc.col - 2)
      else:
         raise new_analyze_error("Failed to find a token at the target location.")


proc find_symbols*(unit: SourceUnit): seq[LspSymbolInformation] =
   # Add an entry for each declaration in the AST.
   for (_, n) in find_all_declarations(unit.graph.root, recursive = true):
      # Filter out declarations not in the current file.
      if n.loc.file != 1:
         continue
      let loc = new_lsp_location(construct_uri(unit.filename),
                                 int(n.loc.line - 1),
                                 int(n.loc.col), len(n.identifier.s))
      add(result, new_lsp_symbol_information(n.identifier.s, LspSkVariable, loc))

   # Add an entry for each module instantiation in the AST.
   for n in find_all_module_instantiations(unit.graph.root):
      if n.loc.file != 1:
         continue

      let module_name = find_first(n, NkIdentifier)
      if is_nil(module_name):
         continue

      for s in walk_sons(n, NkModuleInstance):
         let module_instance_name = find_first(s, NkIdentifier)
         if is_nil(module_instance_name):
            continue
         let loc = new_lsp_location(construct_uri(unit.filename),
                                    int(module_instance_name.loc.line - 1),
                                    int(module_instance_name.loc.col),
                                    len(module_instance_name.identifier.s))
         var symbol = new_lsp_symbol_information(module_name.identifier.s, LspSkModule, loc)
         symbol.container_name = module_instance_name.identifier.s
         add(result, symbol)


proc add(x: var seq[LspTextDocumentEdit], n: PNode, filename, s: string) =
   let start = new_lsp_position(int(n.loc.line - 1), int(n.loc.col))
   let stop = new_lsp_position(int(n.loc.line - 1), int(n.loc.col + len(n.identifier.s)))
   let text_edit = new_lsp_text_edit(start, stop, s)
   add(x, new_lsp_text_document_edit(construct_uri(filename), [text_edit]))


proc rename_external_module(unit: SourceUnit, identifier: PIdentifier, new_name: string): seq[LspTextDocumentEdit] =
   for (filename, module) in walk_module_declarations(unit.configuration.include_paths):
      let module_name = find_first(module, NkIdentifier)
      if not is_nil(module_name) and module_name.identifier.s == identifier.s:
         # We've encountered the definition of the module itself. Replace the
         # module name in the declaration and continue walking the verilog
         # files.
         add(result, module_name, filename, new_name)
         continue

      for module_instantiation in find_all_module_instantiations(module):
         let module_name = find_first(module_instantiation, NkIdentifier)
         if not is_nil(module_name) and module_name.identifier.s == identifier.s:
            # We've encountered an instantiation of the module. Replace the name.
            add(result, module_name, filename, new_name)


proc rename_external_module_port(unit: SourceUnit, module_id, port_id: PIdentifier,
                                 new_name: string): seq[LspTextDocumentEdit] =
   for (filename, module) in walk_module_declarations(unit.configuration.include_paths):
      let module_name = find_first(module, NkIdentifier)
      if not is_nil(module_name) and module_name.identifier.s == module_id.s:
         # FIXME: If the port identifier only represents the external name for a
         #        module which only has a list of ports, then internal
         #        identifiers with the same name are renamed by mistake. See
         #        comment in src5.v.
         for reference in find_references(module, port_id):
            add(result, reference, filename, new_name)
         continue

      for module_instantiation in find_all_module_instantiations(module):
         let module_name = find_first(module_instantiation, NkIdentifier)
         if is_nil(module_name) or module_name.identifier.s != module_id.s:
            continue

         for module_instance in walk_sons(module_instantiation, NkModuleInstance):
            for named_connection in walk_sons(module_instance, NkNamedPortConnection):
               let id = find_first(named_connection, NkIdentifier)
               if not is_nil(id) and id.identifier.s == port_id.s:
                  add(result, id, filename, new_name)


proc rename_external_module_parameter_port(unit: SourceUnit, module_id, parameter_id: PIdentifier,
                                           new_name: string): seq[LspTextDocumentEdit] =
   for (filename, module) in walk_module_declarations(unit.configuration.include_paths):
      let module_name = find_first(module, NkIdentifier)
      if not is_nil(module_name) and module_name.identifier.s == module_id.s:
         for reference in find_references(module, parameter_id):
            add(result, reference, filename, new_name)
         continue

      for module_instantiation in find_all_module_instantiations(module):
         let module_name = find_first(module_instantiation, NkIdentifier)
         if is_nil(module_name) or module_name.identifier.s != module_id.s:
            continue

         let parameter_ports = find_first(module_instantiation, NkParameterValueAssignment)
         if not is_nil(parameter_ports):
            for named_assignment in walk_sons(parameter_ports, NkNamedParameterAssignment):
               let id = find_first(named_assignment, NkIdentifier)
               if not is_nil(id) and id.identifier.s == parameter_id.s:
                  add(result, id, filename, new_name)


proc rename_external_symbol(unit: SourceUnit, context: AstContext, identifier: PIdentifier,
                            new_name: string): seq[LspTextDocumentEdit] =
   if context[^1].n.kind in {NkModuleInstantiation, NkModuleDecl}:
      return rename_external_module(unit, identifier, new_name)

   elif context[^1].n.kind in {NkNamedPortConnection, NkNamedParameterAssignment}:
      # Named port or parameter port connections of a module instantiation. We
      # only perform an external rename if a port is targeted, the context
      # position is equal to the first identifier that we find.
      if find_first_index(context[^1].n, NkIdentifier) == context[^1].pos and len(context) >= 3:
         let module = find_first(context[^3].n, NkIdentifier)
         if not is_nil(module):
            if context[^1].n.kind == NkNamedPortConnection:
               return rename_external_module_port(unit, module.identifier, identifier, new_name)
            else:
               return rename_external_module_parameter_port(unit, module.identifier, identifier, new_name)

   elif context[^1].n.kind == NkPortDecl:
      let module = find_first(context[^3].n, NkIdentifier)
      if not is_nil(module):
         return rename_external_module_port(unit, module.identifier, identifier, new_name)

   elif len(context) >= 4 and context[^3].n.kind == NkModuleParameterPortList:
      let module = find_first(context[^4].n, NkIdentifier)
      if not is_nil(module):
         return rename_external_module_parameter_port(unit, module.identifier, identifier, new_name)

   elif len(context) >= 3 and context[^1].n.kind == NkPort:
      # Renaming a port by targeting a port identifier in a list of ports.
      let module = find_first(context[^3].n, NkIdentifier)
      if not is_nil(module):
         return rename_external_module_port(unit, module.identifier, identifier, new_name)

   # We use the raw declaration search interface to get the context in which it
   # applies. Since we're looking to handle port and parameter port
   # declarations, the context will hold the AST for the full module
   # declaration. We'll use this tree to find the name of the module.
   let (declaration, _, _, declaration_context) = find_declaration(context, identifier)
   if not is_nil(declaration) and declaration.kind in {NkPortDecl, NkParameterDecl}:
      let module = find_first(declaration_context.n, NkIdentifier)
      if not is_nil(module):
         if declaration.kind == NkPortDecl:
            return rename_external_module_port(unit, module.identifier, identifier, new_name)
         else:
            return rename_external_module_parameter_port(unit, module.identifier, identifier, new_name)

   raise new_analyze_error("External rename failed.")


proc rename_symbol*(unit: SourceUnit, line, col: int, new_name: string): seq[LspTextDocumentEdit] =
   # Renaming a symbol is the same as first finding all references (including
   # the declaration) and constructing the text edits describing the changes
   # based on that. However, we have to make an exception for symbols where a
   # rename has external side effects, e.g. when a module instance or a module
   # port is targeted. We don't know what we're targeting until we've tried
   # locating the identifier at the target location.
   var context: AstContext
   init(context, 32)
   let identifier = find_identifier_physical(unit.graph.root, unit.graph.locations,
                                             new_location(1, line, col), context)
   if not is_nil(identifier):
      try:
         return rename_external_symbol(unit, context, identifier.identifier, new_name)
      except AnalyzeError:
         discard

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


proc construct_hover(n: PNode, highlight_location: Location, highlight_length: int): LspHover =
   ## Construct the LSP hover information given the node ``n`` and the highlight
   ## range specified by ``highlight_location`` and ``highlight_length``.
   var markdown = format("```verilog\n$1\n```", $n)
   let comment = find_first(n, NkComment)
   if not is_nil(comment):
      # TODO: We potentially need to figure out if the whitespace following a
      #       newline needs some manipulation to render the markdown
      #       properly. In the worst case, the comment may need to inform us
      #       of the comment's indentation so we can subtrace accordingly.
      add(markdown, "\n\n" & comment.s)
   result = new_lsp_hover(int(highlight_location.line - 1), int(highlight_location.col),
                          highlight_length, LspMkMarkdown, markdown)


proc construct_module_hover(unit: SourceUnit, n: PNode, highlight_location: Location,
                            highlight_length: int): LspHover =
   ## Construct the LSP hover information for the module declaration ``n`` at the
   ## highlight range specified by ``highlight_location`` and ``highlight_length``.
   let name = find_first(n, NkIdentifier)
   if is_nil(name):
      raise new_analyze_error("Failed to find module name.")

   var markdown = format("```verilog\nmodule $1\n```", name.identifier.s)
   let comment = find_first(n, NkComment)
   if not is_nil(comment):
      add(markdown, "\n\n" & comment.s)

   let filename = extract_filename(unit.graph.locations.file_maps[n.loc.file - 1].filename)
   add(markdown, "\n\n---\nFile: " & filename)
   result = new_lsp_hover(int(highlight_location.line - 1), int(highlight_location.col),
                          highlight_length, LspMkMarkdown, markdown)


proc find_external_hover(unit: SourceUnit, context: AstContext, identifier: PIdentifier,
                         highlight_location: Location): LspHover =
   let (n, _, _) = find_external_declaration(unit.graph, context, identifier)
   if is_nil(n):
      raise new_analyze_error("External declaration lookup failed (no match).")
   if n.kind == NkModuleDecl:
      result = construct_module_hover(unit, n, highlight_location, len(identifier.s))
   else:
      result = construct_hover(n, highlight_location, len(identifier.s))


proc find_internal_hover(unit: SourceUnit, context: AstContext, identifier: PIdentifier,
                         highlight_location: Location): LspHover =
   let (declaration, _, _, _) = find_declaration(context, identifier)
   if is_nil(declaration):
      raise new_analyze_error("Failed to find the declaration of identifier '$1'.", identifier.s)
   elif declaration.kind in {NkModuleDecl, NkModuleInstance}:
      # FIXME: Implement
      raise new_analyze_error("Not implemented.")
   result = construct_hover(declaration, highlight_location, len(identifier.s))


proc hover*(unit: SourceUnit, line, col: int): LspHover =
   ## Hover over the identifier at (``line``, ``col``), returning a markdown
   ## string with the identifier's declaration and any attached docstring. If the
   ## operation fails, an AnalyzeError is raised.
   let g = unit.graph

   # Before we can assume that the input location is pointing to an identifier,
   # we have to deal with the possibility that it's pointing to a macro.
   let loc = new_location(1, line, col)
   for map in g.locations.macro_maps:
      # +1 is to compensate for the expansion location starting at the backtick.
      if in_bounds(loc, map.expansion_loc, len(map.name) + 1):
         # TODO: We don't have access to the replacement list from the macro map
         #       so we can't recreate the macro declaration unless that changes.
         if len(map.comment) > 0:
            return new_lsp_hover(int(map.expansion_loc.line - 1), int(map.expansion_loc.col),
                                 len(map.name) + 1, LspMkMarkdown, map.comment)
         else:
            raise new_analyze_error("Failed to find hover information for the macro expansion " &
                                    "at the target location.")

   var context: AstContext
   init(context, 32)
   let identifier = find_identifier_physical(g.root, g.locations, loc, context)
   if is_nil(identifier):
      raise new_analyze_error("Failed to find an identifer at the target location.")

   let highlight_location = if identifier.loc.file < 0:
      to_physical(unit.graph.locations, identifier.loc)
   else:
      identifier.loc

   if is_external_identifier(context):
      result = find_external_hover(unit, context, identifier.identifier, highlight_location)
   else:
      result = find_internal_hover(unit, context, identifier.identifier, highlight_location)


proc parse_function_like_call(p: var LocalParser, loc: Location): tuple[token: Token, arg: int] =
   var paren_count = 0
   var brace_count = 0
   if p.tok.kind != TkSymbol or p.next_tok.kind != TkLparen:
      result.token.kind = TkInvalid
      return
   result.token = p.tok
   result.arg = 0

   if in_bounds(loc, p.tok.loc, len(p.tok.identifier.s) + 1):
      result.arg = -1
      return

   # Remove the identifier and the opening parenthesis.
   get_token(p)
   get_token(p)

   while true:
      # Check if we're at or if we've gone past the target location.
      if p.tok.loc >= loc:
         break

      case p.tok.kind
      of TkEndOfFile:
         result.token.kind = TkInvalid
         break
      of TkComma:
         if paren_count == 0 and brace_count == 0:
            inc(result.arg)
      of TkLbrace:
         inc(brace_count)
      of TkRbrace:
         if brace_count > 0:
            dec(brace_count)
      of TkSymbol:
         if p.next_tok.kind == TkLparen:
            let recursive_result = parse_function_like_call(p, loc)
            if recursive_result.token.kind != TkInvalid:
               return recursive_result
      of TkLparen:
         inc(paren_count)
      of TkRparen:
         if paren_count > 0:
            dec(paren_count)
         else:
            result.token.kind = TkInvalid
            break
      else:
         discard
      get_token(p)


proc find_function_like_call(unit: SourceUnit, loc: Location): tuple[token: Token, arg: int] =
   let cache = new_ident_cache()
   run_local_parser(unit, cache, parser):
      if parser.tok.loc > loc:
         result.token.kind = TkInvalid
         break
      if parser.tok.kind == TkSymbol and parser.next_tok.kind == TkLparen:
         result = parse_function_like_call(parser, loc)
         if result.token.kind != TkInvalid:
            break
      get_token(parser)


proc construct_parameter_information(n: PNode): LspParameterInformation =
   result.label = $n


proc construct_signature_information(n: PNode): LspSignatureInformation =
   ## Construct signature information for the task or function declaration ``n``.
   if n.kind notin {NkTaskDecl, NkFunctionDecl, NkPortDecl}:
      raise new_analyze_error("Unsupported node kind for signature information construction.")

   let comment = find_first(n, NkComment)
   if not is_nil(comment):
      result.documentation = LspMarkupContent(kind: LspMkMarkdown, value: comment.s)
   result.label = $n

   for port in walk_sons(n, NkTaskFunctionPortDecl):
      add(result.parameters, construct_parameter_information(port))


proc find_internal_signature_help(unit: SourceUnit, context: AstContext, identifier: PIdentifier, arg: int): LspSignatureHelp =
   log.debug("Looking up internal signature help for '$1'.", identifier.s)
   if context[^1].n.kind notin {NkTaskEnable, NkConstantFunctionCall}:
      raise new_analyze_error("Signature help not requested for a task/function call.")

   let name = find_first(context[^1].n, NkIdentifier)
   if is_nil(name):
      raise new_analyze_error("Failed to find the name of the function.")
   let (declaration, _, _, _) = find_declaration(context, name.identifier)
   if is_nil(declaration):
      raise new_analyze_error("Failed to find the declaration of identifier '$1'.", name.identifier.s)

   result.signatures = @[construct_signature_information(declaration)]
   result.active_signature = 0
   result.active_parameter = arg


proc signature_help*(unit: SourceUnit, line, col: int): LspSignatureHelp =
   # Get signature help for the identifier at (``line``, ``col``). If the
   # operation fails, an AnalyzeError is raised. Signature help is only
   # available for functions and tasks. Declarations etc. are available via
   # hover requests.
   let g = unit.graph

   # TODO: Implement for macros. We need some more information from the
   # preprocessor, just as for hover requests.
   let loc = new_location(1, line, col)
   for map in g.locations.macro_maps:
      # +1 is to compensate for the expansion location starting at the backtick.
      if in_bounds(loc, map.expansion_loc, len(map.name) + 1):
         raise new_analyze_error("Signature help not implemented for macros.")

   # We have to use a lexing based approach since we want to offer signature
   # help (at least the lookup part) while typing. That means that the AST will
   # likely be broken most of the time.
   let (tf_token, tf_arg) = find_function_like_call(unit, loc)
   if tf_token.kind == TkInvalid:
      raise new_analyze_error("Failed to find a function-like call at the target location.")

   # Now that we've made sure that the location points to somewhere within a
   # function-like call, we need to lookup the declaration. For that, we need
   # the context so we use the token we got from the lexing to convert it into
   # the corresponding identifier node in the AST.
   var context: AstContext
   init(context, 32)
   let identifier = find_identifier_physical(g.root, g.locations, tf_token.loc, context)
   if is_nil(identifier):
      raise new_analyze_error("Failed to find an identifer at the target location.")

   # Since only task and function identifiers may be targeted, we only have to
   # look in the internal tree to construct the reply.
   result = find_internal_signature_help(unit, context, identifier.identifier, tf_arg)
