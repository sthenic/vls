import vparse

proc check_syntax*(n: PNode): bool =
   result = has_errors(n)
