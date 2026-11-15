
`ifndef FP8_DEFS_VH
`define FP8_DEFS_VH

    // Floating-point exponent biases
    `define FP32_BIAS 127
    `define FP8_BIAS  7

    // FP8 product classification encodings
    `define ZERO      3'b000
    `define SUBNORMAL 3'b001
    `define NORMAL    3'b010
    `define INFINITY  3'b011
    `define NAN       3'b100

`endif
