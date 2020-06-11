(* some_attr = "true" *) module module4 (
    input wire clk_i,
    output wire data_o
);

    reg tmp = 1'b0;
    always @(posedge clk_i)
        tmp <= ~tmp;
    assign data_o = tmp;

endmodule
