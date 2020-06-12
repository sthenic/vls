import strutils
import streams
import os
import vparse

import ./protocol
import ./source_unit
import ./log

type
   # An AST context item represents a specific node and its position in the
   # parent node's list of sons.
   AstContextItem = object
      pos: int
      n: PNode

   AstContext = seq[AstContextItem]

   AnalyzeError* = object of ValueError


const
   VERILOG_EXTENSIONS = [".v"]


proc new_analyze_error(msg: string, args: varargs[string, `$`]): ref AnalyzeError =
   new result
   result.msg = format(msg, args)


proc init(c: var AstContext, len: int) =
   c = new_seq_of_cap[AstContextItem](len)


proc add(c: var AstContext, pos: int, n: PNode) =
   add(c, AstContextItem(pos: pos, n: n))


proc in_bounds(x, y: Location, len: int): bool =
   result = x.file == y.file and x.line == y.line and
            x.col >= y.col and x.col <= (y.col + len - 1)


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


iterator walk_ports(n: PNode): PNode {.inline.} =
   if n.kind == NkModuleDecl:
      for s in n.sons:
         if s.kind in {NkListOfPortDeclarations, NkListOfPorts}:
            for p in s.sons:
               if p.kind in {NkPortDecl, NkPort}:
                  yield p


iterator walk_parameter_ports(n: PNode): PNode {.inline.} =
   if n.kind == NkModuleDecl:
      for s in n.sons:
         if s.kind == NkModuleParameterPortList:
            for p in s.sons:
               if p.kind == NkParameterDecl:
                  yield p


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


proc find_identifier(n: PNode, loc: Location, context: var AstContext): PNode =
   case n.kind
   of IdentifierTypes:
      # If the node is an identifier type, check if the location is pointing to
      # anywhere within the identifier. Otherwise, we skip it.
      if in_bounds(loc, n.loc, len(n.identifier.s)):
         result = n
      else:
         result = nil
   of PrimitiveTypes - IdentifierTypes:
      result = nil
   else:
      # FIXME: Perhaps we can improve the search here? Skipping entire subtrees
      #        depending on the location of the first node within?
      for i, s in n.sons:
         add(context, i, n)
         result = find_identifier(s, loc, context)
         if not is_nil(result):
            return
         discard pop(context)


proc unroll_location(macro_maps: seq[MacroMap], loc: var Location) =
   for i, map in macro_maps:
      for j, lpair in map.locations:
         if loc == lpair.x:
            loc = new_location(-(i + 1), j, 0)


proc find_identifier_physical(g: Graph, loc: Location, context: var AstContext): PNode =
   ## Find the identifier at the physical location ``loc``, i.e. ``loc.file`` is
   ## expected to not point at a macro entry.
   var lookup_loc = loc
   var start_col = 0
   for i, map in g.locations.macro_maps:
      for j, lpair in map.locations:
         # The macro map's location database only stores the locations of the
         # first character in the token and not the length of the token. Given
         # that the location we're given as an input argument may point to
         # anywhere within the token, we have to guess what to translate the
         # physical location to.
         if loc.file == lpair.x.file and loc.line == lpair.x.line and loc.col >= lpair.x.col:
            lookup_loc = new_location(-(i + 1), j, 0)
            start_col = lpair.x.col

         # We don't break out of the loops since a better location may present
         # itself by looking at later macro maps. The macro maps are organized
         # in the order they appear in the source file, i.e. left to right, top
         # to bottom.

   if lookup_loc.file < 0:
      unroll_location(g.locations.macro_maps, lookup_loc)

   # Make the lookup.
   result = find_identifier(g.root_node, lookup_loc, context)

   # If we made the lookup using a virtual location, we have to be ready to roll
   # back the lookup result if it turns out that the input location points
   # beyond the identifier.
   if not is_nil(result) and lookup_loc.file < 0 and loc.col > (start_col + len(result.identifier.s) - 1):
      result = nil


proc find_declaration(n: PNode, identifier: PIdentifier): PNode =
   # We have to hande each type of declaration node individually in order to
   # find the correct identifier node.
   result = nil
   case n.kind
   of NkPortDecl:
      let id = find_first(n, NkPortIdentifier)
      if not is_nil(id) and id.identifier.s == identifier.s:
         result = id

   of NkTaskDecl, NkFunctionDecl, NkGenvarDecl:
      let id = find_first(n, NkIdentifier)
      if not is_nil(id) and id.identifier.s == identifier.s:
         result = id

   of NkRegDecl, NkIntegerDecl, NkRealDecl, NkRealtimeDecl, NkTimeDecl, NkNetDecl, NkEventDecl:
      for s in n.sons:
         case s.kind
         of NkArrayIdentifer, NkAssignment:
            let id = find_first(s, NkIdentifier)
            if not is_nil(id) and id.identifier.s == identifier.s:
               result = id
         of NkIdentifier:
            if s.identifier.s == identifier.s:
               result = s
               break
         else:
            discard

   of NkParameterDecl, NkLocalparamDecl:
      # When we find a NkParamAssignment node, the first son is expected to be
      # the identifier.
      for s in walk_sons(n, NkParamAssignment):
         let id = find_first(s, NkParameterIdentifier)
         if not is_nil(id) and id.identifier.s == identifier.s:
            result = id

   of NkSpecparamDecl:
      # When we find a NkAssignment node, the first son is expected to be the
      # identifier.
      for s in walk_sons(n, NkAssignment):
         let id = find_first(s, NkIdentifier)
         if not is_nil(id) and id.identifier.s == identifier.s:
            result = id

   of NkModuleDecl:
      # This path is never taken since a the lookup of a module declaration is
      # handled by find_module_declaration() which performs a lookup.
      let id = find_first(n, NkModuleIdentifier)
      if not is_nil(id) and id.identifier.s == identifier.s:
         result = id

   of PrimitiveTypes + {NkDefparamDecl}:
      # Defparam declarations specifically targets an existing parameter and
      # changes its value. Looking up a declaration should never lead to this
      # node.
      discard

   else:
      for s in n.sons:
         result = find_declaration(s, identifier)
         if not is_nil(result):
            break


proc find_declaration(context: AstContext, identifier: PIdentifier): PNode =
   # Traverse the context bottom-up, descending into any declaration nodes we
   # find along the way.
   result = nil
   for i in countdown(high(context), 0):
      let context_item = context[i]
      if context_item.n.kind notin PrimitiveTypes:
         for pos in countdown(context_item.pos, 0):
            let s = context_item.n.sons[pos]
            if s.kind in DeclarationTypes - {NkDefparamDecl}:
               result = find_declaration(s, identifier)
               if not is_nil(result):
                  return


proc find_module_declaration(unit: SourceUnit, identifier: PIdentifier): LspLocation =
   for filename, module in walk_module_declarations(unit.configuration.include_paths):
      for s in module.sons:
         if s.kind == NkModuleIdentifier and s.identifier.s == identifier.s:
            return new_lsp_location(construct_uri(filename), int(s.loc.line - 1), int(s.loc.col))
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
                                       int(id.loc.col))
         of NkPort:
            # If we find a port identifier as the first node, that's the
            # name that this port is known by from the outside. Otherwise,
            # we're looking for the first identifier in a port reference.
            let id = find_first(port, NkPortIdentifier)
            if not is_nil(id) and id.identifier.s == port_id.s:
               return new_lsp_location(construct_uri(filename),
                                       int(id.loc.line - 1),
                                       int(id.loc.col))
            else:
               let port_ref = find_first(port, NkPortReference)
               if not is_nil(port_ref):
                  let id = find_first(port_ref, NkPortIdentifier)
                  if not is_nil(id) and id.identifier.s == port_id.s:
                     return new_lsp_location(construct_uri(filename),
                                             int(id.loc.line - 1),
                                             int(id.loc.col))
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
               return new_lsp_location(construct_uri(filename), int(id.loc.line - 1), int(id.loc.col))

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
            result = context[^2].n.kind == NkParameterValueAssignment
      else:
         result = false
   else:
      result = false


proc find_internal_declaration(unit: SourceUnit, context: AstContext, identifier: PIdentifier): LspLocation =
   log.debug("Looking up an internal declaration for '$1'.", identifier.s)
   let n = find_declaration(context, identifier)
   if not is_nil(n):
      let uri = construct_uri(unit.graph.locations.file_maps[n.loc.file - 1].filename)
      result = new_lsp_location(uri, int(n.loc.line - 1), int(n.loc.col))
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


proc find_declaration*(unit: SourceUnit, line, col: int): LspLocation =
   ## Find where the identifier at (``line``, ``col``) is declared. This proc
   ## returns an LSP locations if successful. Otherwise, it raises an AnalyzeError.
   let g = unit.graph

   # Before we can assume that the input location is pointing to an identifier,
   # we have to deal with the possibility that it's pointing to a macro.
   let loc = new_location(1, line, col)
   for i, map in g.locations.macro_maps:
      # +1 is to compensate for the expansion location starting at the backtick.
      if in_bounds(loc, map.expansion_loc, len(map.name) + 1):
         let uri = construct_uri(g.locations.file_maps[map.define_loc.file - 1].filename)
         return new_lsp_location(uri, int(map.define_loc.line - 1), int(map.define_loc.col))

   # We begin by finding the identifier at the input position, keeping in mind
   # that the position doesn't have point to the start of the token. The return
   # value is nil if there's no identifier at the target location.
   var context: AstContext
   init(context, 32)
   let identifier = find_identifier_physical(g, new_location(1, line, col), context)
   if is_nil(identifier):
      raise new_analyze_error("Failed to find at identifer at the target location.")

   # We have to determine if we should look for an internal (in the context) or
   # an external declaration. In the case of the latter, we only support lookup
   # of module instantiations and their ports.
   if is_external_identifier(context):
      return find_external_declaration(unit, context, identifier.identifier)
   else:
      return find_internal_declaration(unit, context, identifier.identifier)
