
`timescale 1ns/1ps

module fp8_multiplier_tb;

    logic [7:0] a, b;

    wire signed [7:0] normalized_exponent;
    wire [21:0] normalized_fraction;
    wire fraction_sign;
    wire [2:0] product_class_out;

    integer pass_count = 0;
    integer fail_count = 0;

    fp8_multiplier DUT (
        .a(a),
        .b(b),
        .normalized_exponent(normalized_exponent),
        .normalized_fraction(normalized_fraction),
        .fraction_sign(fraction_sign),
        .product_class_out(product_class_out)
    );

    task automatic run_test(
        input [7:0] input_a,
        input [7:0] input_b,
        input integer expected_exp,
        input [21:0] expected_fraction,
        input expected_sign,
        input [2:0] expected_class,
        input [255:0] test_name
    );
    begin
        a = input_a;
        b = input_b;
        #10;

        $display("\n%s", test_name);

        if (normalized_exponent === expected_exp &&
            normalized_fraction === expected_fraction &&
            fraction_sign === expected_sign &&
            product_class_out === expected_class) begin
            $display("PASS");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL");
            $display("Expected: exp=%0d frac=%b sign=%b class=%b",
                expected_exp, expected_fraction,
                expected_sign, expected_class);
            $display("Actual:   exp=%0d frac=%b sign=%b class=%b",
                normalized_exponent, normalized_fraction,
                fraction_sign, product_class_out);
            fail_count = fail_count + 1;
        end
    end
    endtask

    initial begin

        $display("\n==================================");
        $display("       FP8 MULTIPLIER TESTS");
        $display("==================================");

        // 1. Normal x Normal
        run_test(8'h42, 8'h38, 1,
            {7'b1010000,15'b0}, 0, 3'b010, "TEST 1: Normal x Normal");

        // 2. Normal x Normal
        run_test(8'h3C, 8'h3C, 1,
            {7'b1001000,15'b0}, 0, 3'b010, "TEST 2: 1.5 x 1.5");

        // 3. Normal x Smallest Subnormal
        run_test(8'h38, 8'h01, -9,
            {7'b1000000,15'b0}, 0, 3'b010, "TEST 3: Normal x Subnormal");

        // 4. Smallest Subnormal x Smallest Subnormal
        run_test(8'h01, 8'h01, -18,
            {7'b1000000,15'b0}, 0, 3'b010, "TEST 4: Subnormal x Subnormal");

        // 5. Zero x Normal
        run_test(8'h00, 8'h38, 0,
            22'b0, 0, 3'b000, "TEST 5: Zero x Normal");

        // 6. NaN x Normal
        run_test(8'h7F, 8'h38, 0,
            22'b0, 0, 3'b100, "TEST 6: NaN x Normal");

        // 7. NaN x Zero: NaN takes priority
        run_test(8'h7F, 8'h00, 0,
            22'b0, 0, 3'b100, "TEST 7: NaN x Zero");

        // 8. Negative x Positive
        run_test(8'hB8, 8'h38, 0,
            {7'b1000000,15'b0}, 1, 3'b010, "TEST 8: Negative x Positive");

        // 9. Negative x Negative
        run_test(8'hB8, 8'hB8, 0,
            {7'b1000000,15'b0}, 0, 3'b010, "TEST 9: Negative x Negative");

        // 10. Positive x Negative
        run_test(8'h38, 8'hB8, 0,
            {7'b1000000,15'b0}, 1, 3'b010, "TEST 10: Positive x Negative");

        // 11. Subnormal fraction = 2
        run_test(8'h02, 8'h38, -8,
            {7'b1000000,15'b0}, 0, 3'b010, "TEST 11: Subnormal fraction 2");

        // 12. Subnormal fraction = 3
        run_test(8'h03, 8'h38, -8,
            {7'b1100000,15'b0}, 0, 3'b010, "TEST 12: Subnormal fraction 3");

        // 13. Maximum finite x 1.0
        run_test(8'h7E, 8'h38, 8,
            {7'b1110000,15'b0}, 0, 3'b010, "TEST 13: Maximum finite x 1.0");

        // 14. Maximum finite x Maximum finite
        run_test(8'h7E, 8'h7E, 17,
            {7'b1100010,15'b0}, 0, 3'b010, "TEST 14: Maximum finite x Maximum finite");

        $display("\n==================================");
        $display("           TEST SUMMARY");
        $display("==================================");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("==================================");

        $finish;
    end

endmodule
