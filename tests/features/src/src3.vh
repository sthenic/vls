/* File with some defines used by src3.v */

`define AND(x, y) (x & y)
/* Docstring for `WIDTH_FROM_HEADER`. */
localparam WIDTH_FROM_HEADER = 8;









/* This location is important since it overlaps (line and column wise) with a localparam in src3.v. */
localparam ANOTHER_PARAMETER = 10;
/* Logic AND between `x` and `1'b0`. */
`define AND_WITH_ZERO(x) `AND(x, 1'b0)
