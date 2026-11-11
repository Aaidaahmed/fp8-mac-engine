
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
        input [80*8:1] test_name
    );
    begin
        a = input_a;
        b = input_b;
        #10;

        $display("\n%s", test_name);
        $display("A = %b, B = %b", a, b);
        $display("Exponent = %0d", normalized_exponent);
        $display("Fraction = %b", normalized_fraction);
        $display("Sign = %b", fraction_sign);
        $display("Class = %b", product_class_out);

        if (normalized_exponent === expected_exp &&
            normalized_fraction === expected_fraction &&
            fraction_sign === expected_sign &&
            product_class_out === expected_class) begin
            $display("RESULT: PASS");
            pass_count = pass_count + 1;
        end
        else begin
            $display("RESULT: FAIL");
            $display("Expected exponent = %0d", expected_exp);
            $display("Expected fraction = %b", expected_fraction);
            $display("Expected sign = %b", expected_sign);
            $display("Expected class = %b", expected_class);
            fail_count = fail_count + 1;
        end
    end
    endtask

    initial begin

        $display("\n==================================");
        $display("       FP8 MULTIPLIER TESTS");
        $display("==================================");

        // 1. Normal x Normal: 2.5 x 1.0 = 2.5
        run_test(
            8'b01000010, 8'b00111000,
            1, {7'b1010000,15'b0}, 0, 3'b010,
            "TEST 1: Normal x Normal"
        );

        // 2. Normal x Normal: 1.5 x 1.5 = 2.25
        run_test(
            8'b00111100, 8'b00111100,
            1, {7'b1001000,15'b0}, 0, 3'b010,
            "TEST 2: Normal x Normal"
        );

        // 3. Normal x Subnormal: 1.0 x 0.125 = 0.125
        run_test(
            8'b00111000, 8'b00000001,
            -9, {7'b1000000,15'b0}, 0, 3'b010,
            "TEST 3: Normal x Subnormal"
        );

        // 4. Subnormal x Subnormal: 0.125 x 0.125 = 0.015625
        run_test(
            8'b00000001, 8'b00000001,
            -18, {7'b1000000,15'b0}, 0, 3'b010,
            "TEST 4: Subnormal x Subnormal"
        );

        // 5. Zero x Normal
        run_test(
            8'b00000000, 8'b00111000,
            0, 22'b0, 0, 3'b000,
            "TEST 5: Zero x Normal"
        );

        // 6. NaN x Normal
        run_test(
            8'b01111111, 8'b00111000,
            0, 22'b0, 0, 3'b100,
            "TEST 6: NaN x Normal"
        );

        // 7. Negative x Positive: -1.0 x 1.0
        run_test(
            8'b10111000, 8'b00111000,
            0, {7'b1000000,15'b0}, 1, 3'b010,
            "TEST 7: Negative x Positive"
        );

        // 8. Negative x Negative: -1.0 x -1.0
        run_test(
            8'b10111000, 8'b10111000,
            0, {7'b1000000,15'b0}, 0, 3'b010,
            "TEST 8: Negative x Negative"
        );

        // 9. Positive x Negative: 1.0 x -1.0
        run_test(
            8'b00111000, 8'b10111000,
            0, {7'b1000000,15'b0}, 1, 3'b010,
            "TEST 9: Positive x Negative"
        );

        $display("\n==================================");
        $display("           TEST SUMMARY");
        $display("==================================");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("==================================");

        $finish;
    end

endmodule
