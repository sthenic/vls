import strutils

import vparse
import ./diagnostic
import ./log

proc check_syntax*(n: PNode, locs: PLocations): seq[LspDiagnostic] =
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


proc find_identifier_at(n: PNode, loc: Location): PNode =
   case n.kind
   of IdentifierTypes:
      # If the node is an identifier type, check if the location is pointing to
      # anywhere within the identifier. Otherwise, we skip it.
      if loc.line == n.loc.line and loc.col >= n.loc.col and
         loc.col <= (n.loc.col + len(n.identifier.s) - 1):
         result = n
      else:
         result = nil
   of PrimitiveTypes - IdentifierTypes:
      result = nil
   else:
      # FIXME: Perhaps we can improve the search here? Skipping entire subtrees
      #        depending on the location of the first node within?
      for s in n.sons:
         result = find_identifier_at(s, loc)
         if not is_nil(result):
            break


proc find_declaration_of(n: PNode, identifier: PIdentifier): PNode =
   ## Find the AST node declaring ``identifier`` (which is assumed to be in the
   ## set IdentifierTypes).
   # TODO: Should we just look for any IdentifierTypes within Declaration types
   #       instead? Assuming nothing about the syntax and making the code below
   #       more compact?
   result = nil
   case n.kind
   of NkPortDecl:
      for s in n.sons:
         if s.kind == NkPortIdentifier and s.identifier.s == identifier.s:
            result = s
            # FIXME: Maybe don't break here to find all declarations?
            break

   of NkRegDecl, NkIntegerDecl, NkRealDecl, NkRealtimeDecl, NkTimeDecl, NkNetDecl:
      for s in n.sons:
         case s.kind
         of NkArrayIdentifer, NkAssignment:
            # The first son is expected to be the identifier.
            if s.sons[0].kind == NkIdentifier and s.sons[0].identifier.s == identifier.s:
               result = s.sons[0]
               break
         of NkIdentifier:
            if s.identifier.s == identifier.s:
               result = s
               break
         else:
            discard

   of NkTaskDecl, NkFunctionDecl, NkGenvarDecl:
      for s in n.sons:
         case s.kind
         of NkIdentifier:
            if s.identifier.s == identifier.s:
               result = s
               break
         else:
            discard

   of NkParameterDecl, NkLocalparamDecl:
      for s in n.sons:
         # The first son is expected to be the identifier when we encounter an
         # NkParamAssignment node.
         if s.kind == NkParamAssignment and s.sons[0].kind == NkParameterIdentifier and s.sons[0].identifier.s == identifier.s:
            result = s
            break

   of NkSpecparamDecl:
      for s in n.sons:
         if s.kind == NkAssignment and s.sons[0].kind == NkIdentifier and s.sons[0].identifier.s == identifier.s:
            result = s
            break

   of NkEventDecl:
      for s in n.sons:
         case s.kind
         of NkArrayIdentifer:
            # The first son is expected to be the identifier.
            if s.sons[0].kind == NkIdentifier and s.sons[0].identifier.s == identifier.s:
               result = s.sons[0]
               break
         of NkIdentifier:
            if s.identifier.s == identifier.s:
               result = s
               break
         else:
            discard

   of NkModuleDecl:
      # Module declarations are special, we have to continue searching the
      # subtree like the else branch.
      # FIXME: Search through the include paths as well.
      for s in n.sons:
         if s.kind == NkModuleIdentifier and s.identifier.s == identifier.s:
            result = s
            break
         else:
            result = find_declaration_of(s, identifier)
            if not is_nil(result):
               break

   of NkDefparamDecl:
      # Defparam declarations specifically targets an existing parameter and
      # changes its value. Looking up a declaration should never lead to this
      # node.
      discard

   of PrimitiveTypes:
      discard

   else:
      for s in n.sons:
         result = find_declaration_of(s, identifier)
         if not is_nil(result):
            break


proc find_declaration*(g: Graph, line, col: int): seq[LspLocation] =
   ## Find where the identifier at ``pos`` is declared. This proc returns a
   ## sequence of LSP locations (which may be empty or just include one element).

   # We begin by finding the identifier at the input position, keeping in mind
   # that the position doesn't have point to the start of the token. The return
   # value is nil if there's no identifier at the target location.
   let identifier = find_identifier_at(g.root_node, new_location(1, line, col))
   if is_nil(identifier):
      return

   # Now that we've found the identifier, we look for the matching declaration.
   let declaration = find_declaration_of(g.root_node, identifier.identifier)
   if is_nil(declaration):
      return

   let declaration_uri = g.locations.file_maps[declaration.loc.file - 1].filename
   let declaration_line = declaration.loc.line - 1
   let declaration_col = declaration.loc.col
   add(result, new_lsp_location(declaration_uri, int(declaration_line), int(declaration_col)))
