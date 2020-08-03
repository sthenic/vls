module module6 (
    input wire clk_i
);

    /* Compute something between `parameter1` and `parameter2`. */
    function [FOO:0] compute_something(input [FOO-1:0] parameter1, input [FOO-1:0] parameter2);
        compute_something = parameter1 + parameter2;
    endfunction

    /* Do some work provided `input1` and `input2`. The output is stored in `result`. */
    task do_work(input [FOO:0] input1, input [FOO:0] input2, output [FOO:0] result);
    begin
        input1 = input1 | {1'b1, {(FOO-1){1'b0}}};
        result = input1 & (~input2);
    end
    endtask

    reg [FOO-1:0] my_input1, my_input2;
    reg [FOO:0] computation_result;
    reg [FOO:0] work_result;

    always @(posedge clk_i) begin
        computation_result <= compute_something(my_input1, my_input2);
        do_work(~computation_result, computation_result, work_result);
    end

    initial begin
        do_work({undeclared1, undeclared1},
    end

endmodule
