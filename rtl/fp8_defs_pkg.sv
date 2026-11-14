package fp8_defs_pkg;

    // Floating-point exponent biases
    parameter int FP32_BIAS = 127;
    parameter int FP8_BIAS  = 7;

    // FP8 product classification encodings
    parameter logic [2:0] ZERO      = 3'b000;
    parameter logic [2:0] SUBNORMAL = 3'b001;
    parameter logic [2:0] NORMAL    = 3'b010;
    parameter logic [2:0] INFINITY  = 3'b011;
    parameter logic [2:0] NAN       = 3'b100;

endpackage