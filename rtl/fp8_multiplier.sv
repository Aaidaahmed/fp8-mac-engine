// E4M3FN

module fp8_multiplier(
    input logic [7:0]a,
    input logic [7:0]b,
    output logic signed[7:0]normalized_exponent,
    output logic [21:0]normalized_fraction,
    output logic fraction_sign
);

//FIELD BIT EXTRCTION FOR E4M3FN
logic s_a;   // SIGN OF A - 1 BIT
logic [3:0]e_a; // EXP OF A - 4 BITS 
logic [2:0]f_a; // FRACTION OF A - 3 BITS

logic s_b;  // SIGN OF B - 1 BIT
logic [3:0]e_b; // EXP OF B - 4 BITS
logic [2:0]f_b; // FRACTION OF B - 3 BITS

// A FIELDS
assign s_a = a[7];
assign e_a = a[6:3];
assign f_a = a[2:0];
// B FIELDS
assign s_b = b[7];
assign e_b = b[6:3];
assign f_b = b[2:0];

// PRODUCT SIGN CALCULATION
assign fraction_sign = s_a ^ s_b;

//EXPONENT CALCULATION [BIAS FACTOR FOR E4M3 = 7]
logic signed[7:0]unbiased_e_a;
logic signed[7:0]unbiased_e_b;
logic signed[7:0]exp;

assign unbiased_e_a = {4'b0000, e_a} - 7;
assign unbiased_e_b = {4'b0000, e_b} - 7;
assign exp = unbiased_e_a + unbiased_e_b;

//SIGNIFICAND CALCULATION
logic [3:0]sig_a;
logic [3:0]sig_b;
logic [7:0]prod_sig;
logic [7:0]norm_prod_sig;
//logic signed[7:0]after_norm_exp;

assign sig_a = {1'b1, f_a};
assign sig_b = {1'b1, f_b};
assign prod_sig = sig_a * sig_b; // scaled integer product. 
/* example: f_a = 010 f_b = 000
 which gives us sig_a = 1010 sig_b = 1000 ie sig_a = 10 sig_b = 8
 which gives us prod_sig = 1010 * 1000 = 10 * 8 = 80 
 this is the scaled integer value. 
 to descale we divide it by 64. so 80/64 = 1.25 actual integer value.

 why descale by 64?? since individual fraction was scaled by 2^3 to get significand. 
 2^3 * 2^3 = 2^6 = 64.*/

 always_comb begin 
    if(prod_sig[7] == 1)begin 
        norm_prod_sig = prod_sig >> 1;
        normalized_exponent = exp + 1;
    end
    else begin
        norm_prod_sig = prod_sig;
        normalized_exponent = exp;
    end
 end
endmodule