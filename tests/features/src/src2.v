`define FOO(x) 7 + x
`define MYMACRO(x) 2 * 2 + `FOO(x)

module mymodule #(
    parameter integer WIDTH = 0,
    parameter integer SOMETHING = 0
)(
    input wire clk_i,
    input wire rst_i,

    input wire [WIDTH-1:0] data_i,
    output wire [WIDTH-1:0] data_o
);

   if (WIDTH == 0)
      ERROR_WIDTH_IS_BAD_VALUE();

   wire mytemp;
   reg tmp = 1'b0;
   `include "test2.vh"

    always @(posedge clk_i) begin
        if (rst_i) begin
        `ifdef FOO
            tmp <= 1'b1;
        `else
            tmp <= 1'b1;
         `endif
        end else begin
            tmp <= `MYMACRO(2);
        end
    end

`ifdef BAR
   something
`endif

    initial begin
      an_empty_task();
    end

    reg thing = 1'b0;

endmodule
