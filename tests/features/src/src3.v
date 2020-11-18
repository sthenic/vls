module module3 #(
    parameter integer WIDTH = 0
)(
    input wire clk_i,
    input wire rst_i,

    input wire enable_i,

    input wire [WIDTH-1:0] data_i,
    output wire [WIDTH-1:0] data_o
);

    reg my_reg = 1'b0; wire one = 1'b1;
    `include "src3.vh"

    reg [WIDTH_FROM_HEADER-1:0] wider_reg = 0;

    always @(posedge clk_i) begin
        my_reg <= `AND(my_reg, one);
        wider_reg <= wider_reg + 1;
    end

    wire from_module4;
    module4 #(.MODULE4_PARAMETER (8)) module4_inst (
        (* some_attr = "true" *) .clk_i (clk_i),
        .data_o (from_module4)
    );
    /* This is the docstring for `a_common_wire`. */
    wire a_common_wire;
    generate
        if (WIDTH == 8) begin
            wire a_local_wire = 1'b0;
            assign a_common_wire = a_local_wire;
            integer i;
            for (i = 0; i < WIDTH - 1; i = i + 1) begin
                /* Do something WIDTH - 1 times. */
            end
            wire foo = `AND_WITH_ZERO(a_common_wire);
        end else begin
            wire a_local_wire = 1'b1;
            integer   i;
            assign a_common_wire = a_local_wire;
            for (i = 0; i < WIDTH + 3; i = i + 1) begin
                /* Do something WIDTH + 3 times. */
            end
            wire bar = `AND_WITH_ZERO(a_common_wire);
        end

        assign an_undeclared_wire = 1'b0;
    endgenerate

    wire baz = `AND(my_reg, one) || `AND(wider_reg[0], wider_reg[1]);
    wire fizz = `AND(my_reg || one,
                     wider_reg[0]);

    /* Redefine the `AND macro. */
    `define AND(x, y) (x & y)
    wire buzz = `AND(one, my_reg);

    `define FOO one
    wire some_wire = `FOO;
    wire another_wire = `FOO;

`ifndef VLS
    /* The test for diagnostic messages covers this case. */
    wire hidden_from_vls = an_undeclared_wire;
`endif

endmodule
