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
    reg reg_default = 1'b0;
    reg reg_no_default;
    reg reg_packed[7:0];
    integer i;

    always @(posedge clk_i) begin
        if (rst_i) begin
            reg_default <= 1'b1;
            reg_no_default <= 1'b0;
            for (i = 0; i < 8; i = i + 1)
               reg_packed[i] <= 1'b0;
        end else begin
            reg_default <= `MYMACRO(2);
            reg_no_default <= 1'b1;
            reg_packed[4] <= 1'b1;
        end
    end

   initial begin
       an_empty_task();
   end

   reg thing = 1'b0;

endmodule
