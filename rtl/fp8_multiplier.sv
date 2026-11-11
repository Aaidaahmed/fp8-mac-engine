// E4M3FN

module fp8_multiplier(
    input logic [7:0]a,
    input logic [7:0]b,
    output logic signed[7:0]normalized_exponent,
    output logic [21:0]normalized_fraction,
    output logic fraction_sign,
    output logic [2:0] product_class_out
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

//SIGNALS
logic [3:0]sig_a;
logic [3:0]sig_b;
logic signed[7:0]unbiased_e_a;
logic signed[7:0]unbiased_e_b;
logic signed[7:0]exp;
logic [7:0]prod_sig;
logic [7:0]shifted_norm_prod_sig;
logic signed[7:0]exp_new;

//CLASSIFY NUMBER TYPE
typedef enum logic[1:0]{
    ZERO, SUBNORMAL, NORMAL, NAN
}fp8_class_t;

fp8_class_t product_class;

function  automatic fp8_class_t classify_fp8(
    input logic [3:0]exponent,
    input logic [2:0]fraction
);
    if(exponent == 4'b0000 && fraction == 3'b000)
        return(ZERO);
    else if(exponent == 4'b0000 && fraction != 3'b000)
        return(SUBNORMAL);
    else if(exponent == 4'b1111 && fraction == 3'b111)
        return(NAN);
    else  
        return(NORMAL);
    
endfunction

fp8_class_t classify_a;
fp8_class_t classify_b;

assign classify_a = classify_fp8(e_a, f_a);
assign classify_b = classify_fp8(e_b, f_b);

//PRODUCT CLASSIFICATION

always@(*) begin
    if(classify_a == NAN || classify_b == NAN)
        product_class = NAN;
    else if (classify_a == ZERO || classify_b == ZERO)
        product_class = ZERO;
    else
        product_class = NORMAL;
end

//SUBNORMAL AND NORMAL SIGNIFICAND HANDLING
always@(*) begin 
    sig_a = 4'b0000;
    unbiased_e_a = 8'sd0;
    if (classify_a == NORMAL)begin
        sig_a = {1'b1, f_a};
        unbiased_e_a = e_a - 7;
    end
    else if(classify_a == SUBNORMAL)begin
        sig_a = {1'b0, f_a};
        unbiased_e_a = -8'sd6;
    end
end

always@(*) begin 
    sig_b = 4'b0000;
    unbiased_e_b = 8'sd0;
    if(classify_b == NORMAL)begin
        sig_b = {1'b1, f_b};
        unbiased_e_b = e_b - 7;
    end
    else if(classify_b == SUBNORMAL)begin 
        sig_b = {1'b0, f_b};
        unbiased_e_b = -8'sd6;
    end
end

// PRODUCT SIGN CALCULATION
assign fraction_sign = s_a ^ s_b;
//EXPONENT CALCULATION [BIAS FACTOR FOR E4M3 = 7]
assign exp = unbiased_e_a + unbiased_e_b;
//SIGNIFICAND CALCULATION
assign prod_sig = sig_a * sig_b;

always@(*) begin
    shifted_norm_prod_sig = prod_sig;
    exp_new = exp;
    normalized_exponent = exp;

    if (prod_sig != 8'b0) begin

        if (prod_sig[7] == 1'b1) begin
            shifted_norm_prod_sig = prod_sig >> 1;
            exp_new = exp + 1;
        end
        else begin
            for (int i = 0; i < 7; i++) begin
                if (shifted_norm_prod_sig[6] == 1'b0) begin
                    shifted_norm_prod_sig = shifted_norm_prod_sig << 1;
                    exp_new = exp_new - 1;
                end
            end
        end
    end

    normalized_exponent = exp_new;
end

assign normalized_fraction = {shifted_norm_prod_sig[6:0], 15'b0};

/* Leading 1 in product	Action
Bit [7]	                Shift right once; exponent +1
Bit [6]	                No shift
Bit [5]	                Shift left once; exponent -1
Bit [4]	                Shift left twice; exponent -2
Bit [3]	                Shift left three times; exponent -3
Bit [2]	                Shift left four times; exponent -4 */

always@(*) begin
    case(product_class)
        ZERO: product_class_out = 3'b000;
        SUBNORMAL: product_class_out = 3'b001;
        NORMAL: product_class_out = 3'b010;
        NAN: product_class_out = 3'b100;
        default: product_class_out = 3'b010;
    endcase
end
endmodule