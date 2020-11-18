/*
    This is the documentation for `module7`.

    It features:
    - this,
    - *that*; and
    - this **other** thing.
 */

module module7 #(
    /* The width of the data interface. */
    parameter WIDTH = 32
)(
    /* The clock. */
    input wire clk_i,
    /* The data input. */
    input wire [WIDTH-1:0] data_i,
    /* The data output. */
    output wire [WIDTH-1:0] data_o
);

    mymodule #(.)

endmodule
