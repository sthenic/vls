module module3 #(
    parameter integer WIDTH = 0
)(
    input wire clk_i,
    input wire rst_i,

    input wire enable_i,

    input wire [WIDTH-1:0] data_i,
    output wire [WIDTH-1:0] data_o
);

    reg my_reg = 1'b0;
    `include "src3.vh"

    reg [WIDTH_FROM_HEADER-1:0] wider_reg = 0;

    always @(posedge clk_i) begin
        my_reg <= `NOT(my_reg);
        wider_reg <= wider_reg + 1;
    end

    wire my_reg_from_module4;
    module4 module4_inst (
        .a (my_reg),
        .b (my_reg_from_module4)
    );

    wire a_common_wire;
    generate
        if (WIDTH == 8) begin
            wire a_local_wire = 1'b0;
            assign a_common_wire = a_local_wire;
            integer i;
            for (i = 0; i < WIDTH - 1; i = i + 1) begin
                /* Do something WIDTH - 1 times. */
            end
        end else begin
            wire a_local_wire = 1'b1;
            integer   i;
            assign a_common_wire = a_local_wire;
            for (i = 0; i < WIDTH + 3; i = i + 1) begin
                /* Do something WIDTH + 3 times. */
            end
        end

        assign an_undeclared_wire = 1'b0;
    endgenerate

endmodule
