module fp32_to_fp8(
    input logic [31:0]acc_out,
    output logic [7:0]conv_out
);

import fp8_defs_pkg::*;

//internal signals
logic sign;           // 1 bit
logic [7:0]exponent;  // 8 bits
logic [22:0]fraction; // 23 bits 

//field extraction
assign sign = acc_out[31];
assign exponent = acc_out[30:23];
assign fraction = acc_out[22:0];

//CONVERSION

/* SIGN CONVERSION - NO CONVERSION REQ HERE, SINCE THE SIGN BITS
                     IS ONLY 1 BIT AND REMAINS THE SAME */

/* EXPONENT CONVERSION -  FP32 uses bias 127, 
                          whereas FP8 E4M3FN uses bias 7.
                          THERFORE FOR A "NORMAL NUMBER",
                          Eunbiased = Efp32 - 127
                          Efp8 = Eunbiased + 7
                          which gives us,
                          ----------------------
                          [[Efp8 = Efp32 - 120]]
                          -----------------------*/

logic signed[8:0]conv_exponent;/* because converted exponentcan
reach 134 for large normal fp32 numbers. thats why it is 9 bit */
logic is_zero;
logic is_subnormal;
logic is_normal;
logic is_special;
logic is_infinity;
logic is_nan;

logic [23:0] significand;
logic [23:0] normalized_significand;

logic [4:0] leading_zeros;
logic signed [9:0] adjusted_exponent;
logic signed [9:0] rounded_exp;

logic [4:0] rounded_normal;
logic [23:0] sub_quotient;

logic guard_bit;
logic sticky_bit;

integer i;
integer shift_amt;
logic [3:0] fp8_exp_field;

// NORMAL FP32 INPUTS
assign conv_exponent = $signed({1'b0, exponent}) - 
                             (FP32_BIAS - FP8_BIAS);

// FP32 input classification

assign is_zero      = (exponent == 8'h00) && (fraction == 23'h000000);

assign is_subnormal = (exponent == 8'h00) && (fraction != 23'h000000);

assign is_normal    = (exponent != 8'h00) && (exponent != 8'hFF);

assign is_special   = (exponent == 8'hFF);

assign is_infinity = (exponent == 8'hFF) && (fraction == 23'h000000);

assign is_nan = (exponent == 8'hFF) && (fraction != 23'h000000);

assign significand = is_normal ? {1'b1, fraction} : {1'b0, fraction};

always @(*) begin

    // Default values
    conv_out = 8'b0;
    leading_zeros = 0;
    normalized_significand = significand;
    adjusted_exponent = 0;
    rounded_exp = 0;
    rounded_normal = 0;
    sub_quotient = 0;
    guard_bit = 0;
    sticky_bit = 0;
    shift_amt = 0;
    fp8_exp_field = 0;

    // 1. NaN
    if (is_nan) begin
        conv_out = {sign, 4'b1111, 3'b111};
    end

    // 2. Infinity: saturate to maximum finite E4M3FN
    else if (is_infinity) begin
        conv_out = {sign, 4'b1111, 3'b110};
    end

    // 3. Zero
    else if (is_zero) begin
        conv_out = {sign, 7'b0000000};
    end

    // 4. Normal or subnormal FP32 input
    else begin

        // Normalize FP32 subnormal inputs
        if (is_subnormal) begin

            for (i = 23; i >= 0; i = i - 1) begin
                if (normalized_significand[23] == 1'b0) begin
                    normalized_significand =
                        normalized_significand << 1;
                    leading_zeros = leading_zeros + 1;
                end
            end

            adjusted_exponent = -126 - leading_zeros;

        end

        // Normal FP32 input
        else begin
            adjusted_exponent =
                $signed({1'b0, exponent}) - FP32_BIAS;
        end

        // 5. Convert to NORMAL FP8
        if (adjusted_exponent >= -6) begin

            // Keep 1 hidden bit + 3 fraction bits
            rounded_normal = {1'b0, normalized_significand[23:20]};

            // Guard and sticky bits for RNE
            guard_bit = normalized_significand[19];
            sticky_bit = |normalized_significand[18:0];

            if (guard_bit &&
                (sticky_bit || normalized_significand[20])) begin
                rounded_normal = rounded_normal + 1'b1;
            end

            rounded_exp = adjusted_exponent;

            // Handle significand rounding overflow
            if (rounded_normal[4]) begin
                rounded_exp = rounded_exp + 1;
                rounded_normal = 5'b01000;
            end

            // Overflow: saturate to maximum finite FP8
            if ((rounded_exp > 8) ||
                ((rounded_exp == 8) &&
                 (rounded_normal[2:0] == 3'b111))) begin

                conv_out = {sign, 4'b1111, 3'b110};

            end

            else begin
                fp8_exp_field = rounded_exp + FP8_BIAS;

                conv_out = {
                    sign,
                    fp8_exp_field,
                    rounded_normal[2:0]
                };
            end

        end

        // 6. Convert to SUBNORMAL FP8
        else begin

            // Calculate how many positions to shift right
            shift_amt = 14 - adjusted_exponent;

            sub_quotient = 0;
            guard_bit = 0;
            sticky_bit = 0;

            if (shift_amt <= 24) begin

                sub_quotient =
                    normalized_significand >> shift_amt;

                guard_bit =
                    normalized_significand[shift_amt - 1];

                // Calculate sticky bit
                for (i = 0; i < 24; i = i + 1) begin
                    if (i < shift_amt - 1)
                        sticky_bit =
                            sticky_bit | normalized_significand[i];
                end

                // Round to nearest, ties to even
                if (guard_bit &&
                    (sticky_bit || sub_quotient[0])) begin
                    sub_quotient = sub_quotient + 1'b1;
                end

            end

            // Rounded subnormal becomes minimum normal
            if (sub_quotient >= 8) begin
                conv_out = {sign, 4'b0001, 3'b000};
            end

            else begin
                conv_out = {
                    sign,
                    4'b0000,
                    sub_quotient[2:0]
                };
            end

        end

    end

end

endmodule