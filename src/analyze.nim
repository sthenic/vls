import strutils

import vparse
import ./diagnostic

proc check_syntax*(n: PNode, locs: PLocations): seq[Diagnostic] =
   case n.kind
   of NkTokenErrorSync:
      # Don't generate a diagnostic message for synchronization events.
      discard

   of {NkTokenError, NkCritical}:
      # Create a diagnostic message representing the error node.
      var start: Position
      var message = ""
      if n.loc.file == 0:
         # A zero-valued file index is invalid (and unexpected).
         return
      elif n.loc.file == 1:
         # The error node originates in the current file. Put the diagnostic
         # message at the location in the buffer.
         start = new_position(int(n.loc.line - 1), int(n.loc.col))
      elif n.loc.file < 0:
         # The error node has been created as a result of a macro expansion.
         # That means that the error node has a virtual location that cannot be
         # marked in the file so we put the diagnostic message at the expansion
         # location.
         # TODO: There is enough information to fully trace any errors through
         #       the full macro stack, i.e. we could improve the message.
         let macro_map = locs.macro_maps[abs(n.loc.file + 1)]
         start = new_position(int(macro_map.expansion_loc.line - 1),
                              int(macro_map.expansion_loc.col))
         message = format("In expansion of `$1: ", macro_map.name)
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
               start = new_position(int(map.loc.line - 1), int(map.loc.col))
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

      result = @[new_diagnostic(start, stop, ERROR, message)]

   of PrimitiveTypes - ErrorTypes:
      result = @[]

   else:
      for s in n.sons:
         add(result, check_syntax(s, locs))
