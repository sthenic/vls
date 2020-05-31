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

    wire my_wire;
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

    assign my_wire = reg_default;

    task an_empty_task;
        reg_no_default <= 1'b0;
    endtask

    function add_one(input a);
        add_one = a + 1;
    endfunction

    initial begin
        an_empty_task();
    end

    reg my_counter = 8'd0;

    always @(posedge clk_i) begin
        my_counter <= add_one(my_counter);
    end

    genvar k;

    reg reg_individual_bits = 3'b000;
    generate
    for (k = 0; k < 3; k = k + 1) begin
        always @(posedge clk_i) begin
            if (rst_i) begin
                reg_individual_bits[k] <= 1'b0;
            end else begin
                reg_individual_bits[k] <= 1'b1;
            end
        end
    end
    endgenerate

endmodule