
`timescale 1ns/1ps

module fp8_multiplier_tb;

    logic [7:0] a, b;

    wire signed [7:0] normalized_exponent;
    wire [21:0] normalized_fraction;
    wire fraction_sign;
    wire [2:0] product_class_out;

    integer pass_count = 0;
    integer fail_count = 0;

    integer i, j;

    fp8_multiplier DUT (
        .a(a),
        .b(b),
        .normalized_exponent(normalized_exponent),
        .normalized_fraction(normalized_fraction),
        .fraction_sign(fraction_sign),
        .product_class_out(product_class_out)
    );

    task automatic check_pair(
        input logic [7:0] input_a,
        input logic [7:0] input_b
    );

        integer sig_a_ref, sig_b_ref;
        integer exp_a_ref, exp_b_ref;
        integer product_ref;
        integer exp_ref;

        reg [6:0] fraction_ref;
        reg [21:0] expected_fraction;
        reg expected_sign;
        reg [2:0] expected_class;

        reg class_a_nan, class_b_nan;
        reg class_a_zero, class_b_zero;

        begin
            a = input_a;
            b = input_b;

            #1;

            // Classify A and B
            class_a_nan =
                (input_a[6:3] == 4'b1111 &&
                 input_a[2:0] == 3'b111);

            class_b_nan =
                (input_b[6:3] == 4'b1111 &&
                 input_b[2:0] == 3'b111);

            class_a_zero =
                (input_a[6:0] == 7'b0000000);

            class_b_zero =
                (input_b[6:0] == 7'b0000000);

            // Expected sign
            expected_sign = input_a[7] ^ input_b[7];

            // Expected product classification
            if (class_a_nan || class_b_nan)
                expected_class = 3'b100;
            else if (class_a_zero || class_b_zero)
                expected_class = 3'b000;
            else
                expected_class = 3'b010;

            // Decode A
            if (input_a[6:3] == 0) begin
                sig_a_ref = input_a[2:0];
                exp_a_ref = (sig_a_ref == 0) ? 0 : -6;
            end
            else begin
                sig_a_ref = 8 + input_a[2:0];
                exp_a_ref = input_a[6:3] - 7;
            end

            // Decode B
            if (input_b[6:3] == 0) begin
                sig_b_ref = input_b[2:0];
                exp_b_ref = (sig_b_ref == 0) ? 0 : -6;
            end
            else begin
                sig_b_ref = 8 + input_b[2:0];
                exp_b_ref = input_b[6:3] - 7;
            end

            exp_ref = exp_a_ref + exp_b_ref;

            // Calculate expected product
            product_ref = sig_a_ref * sig_b_ref;

            if (product_ref != 0) begin

                if (product_ref >= 128) begin
                    product_ref = product_ref >> 1;
                    exp_ref = exp_ref + 1;
                end
                else begin
                    while (product_ref < 64) begin
                        product_ref = product_ref << 1;
                        exp_ref = exp_ref - 1;
                    end
                end
            end

            fraction_ref = product_ref[6:0];
            expected_fraction = {fraction_ref, 15'b0};

            // Compare against DUT
            if (expected_class == 3'b000 ||
    expected_class == 3'b100) begin

    if (fraction_sign === expected_sign &&
        product_class_out === expected_class) begin
        pass_count = pass_count + 1;
    end
    else begin
        fail_count = fail_count + 1;
    end

end
        
else begin

    if (normalized_exponent === exp_ref &&
        normalized_fraction === expected_fraction &&
        fraction_sign === expected_sign &&
        product_class_out === expected_class) begin

        pass_count = pass_count + 1;
    end
    else begin
        fail_count = fail_count + 1;
    end

end
        end
    endtask

    initial begin

        $display("\n======================================");
        $display("     EXHAUSTIVE FP8 MULTIPLIER TEST");
        $display("======================================");

        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                check_pair(i[7:0], j[7:0]);
            end
        end

        $display("\n======================================");
        $display("             TEST SUMMARY");
        $display("======================================");
        $display("Total combinations : 65536");
        $display("Passed             : %0d", pass_count);
        $display("Failed             : %0d", fail_count);
        $display("======================================");

        if (fail_count == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");

        $finish;
    end

endmodule
