module FP8_MAC(
    input logic clk,
    input logic rst,
    input logic en,
    input logic [7:0]input_a,
    input logic [7:0]input_b,
    output logic [31:0]acc_out,
    output logic [7:0] fp8_out
);

//internal signals
logic signed[7:0]normalized_exponent;
logic [21:0]normalized_fraction;
logic fraction_sign;
logic [2:0] product_class_out;
wire [31:0] acc_feedback;
assign acc_out= acc_feedback;

fp8_multiplier fp8_mul(
    .normalized_exponent(normalized_exponent),
    .normalized_fraction(normalized_fraction),
    .product_class_out(product_class_out),
    .fraction_sign(fraction_sign),
    .a(input_a),
    .b(input_b)
);

FP32_ACC fp32_acc(
    .clk(clk),
    .rst(rst),
    .en(en),
    .normalized_exponent(normalized_exponent),
    .normalized_fraction(normalized_fraction),
    .fraction_sign(fraction_sign),
    .acc_in_fp32(acc_feedback), 
    .acc_out_fp32(acc_feedback),
    .product_class(product_class_out)

);

fp32_to_fp8 final_converter (
    .acc_out(acc_feedback),
    .conv_out(fp8_out)
);

endmodule