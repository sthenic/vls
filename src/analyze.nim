import vparse

import ./diagnostic


proc check_syntax*(n: PNode): seq[Diagnostic] =
   case n.kind
   of ErrorTypes:
      # Create a diagnostic message representing the error node.
      let start = new_position(int(n.loc.line - 1), int(n.loc.col))
      let stop = start
      result = @[new_diagnostic(start, stop, ERROR, n.msg)]
   of PrimitiveTypes - ErrorTypes:
      result = @[]
   else:
      for s in n.sons:
         add(result, check_syntax(s))
