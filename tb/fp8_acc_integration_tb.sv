
`timescale 1ns/1ps

module fp8_acc_integration_tb;

    logic clk, rst, en;
    logic [7:0] a, b;

    wire signed [7:0] normalized_exponent;
    wire [21:0] normalized_fraction;
    wire fraction_sign;
    wire [2:0] product_class;
    wire [31:0] acc_out_fp32;

    integer passed = 0;
    integer failed = 0;

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // FP8 multiplier
    fp8_multiplier multiplier (
        .a(a),
        .b(b),
        .normalized_exponent(normalized_exponent),
        .normalized_fraction(normalized_fraction),
        .fraction_sign(fraction_sign),
        .product_class_out(product_class)
    );

    // FP32 accumulator with feedback
    FP32_ACC accumulator (
        .clk(clk),
        .rst(rst),
        .en(en),
        .normalized_exponent(normalized_exponent),
        .normalized_fraction(normalized_fraction),
        .fraction_sign(fraction_sign),
        .product_class(product_class),
        .acc_in_fp32(acc_out_fp32),
        .acc_out_fp32(acc_out_fp32)
    );

    // Reset task
    task reset_accumulator;
        begin
            @(negedge clk);
            rst = 1;
            en = 0;

            @(posedge clk);
            #1;

            if (acc_out_fp32 == 32'h00000000)
                $display("RESET PASSED");
            else begin
                $display("RESET FAILED");
                failed = failed + 1;
            end

            @(negedge clk);
            rst = 0;
            en = 1;
        end
    endtask

    // Apply one multiplication and check accumulated result
    task check_mac(
        input [7:0] operand_a,
        input [7:0] operand_b,
        input [31:0] expected,
        input [200*8:1] test_name
    );
        begin
            a = operand_a;
            b = operand_b;

            @(posedge clk);
            #1;

            $display("\n%s", test_name);
            $display("A = %h, B = %h", a, b);
            $display("Exponent = %0d", normalized_exponent);
            $display("Fraction = %h", normalized_fraction);
            $display("Class = %b", product_class);
            $display("Expected = %h, Actual = %h",
                     expected, acc_out_fp32);

            if (acc_out_fp32 === expected) begin
                $display("PASS");
                passed = passed + 1;
            end
            else begin
                $display("FAIL");
                failed = failed + 1;
            end

            @(negedge clk);
        end
    endtask

    // Test enable hold
    task check_enable_hold;
        reg [31:0] previous_result;
        begin
            previous_result = acc_out_fp32;

            en = 0;
            a = 8'h38;
            b = 8'h38;

            @(posedge clk);
            #1;

            $display("\nENABLE HOLD TEST");

            if (acc_out_fp32 === previous_result) begin
                $display("PASS: Accumulator held its value");
                passed = passed + 1;
            end
            else begin
                $display("FAIL: Accumulator changed while disabled");
                failed = failed + 1;
            end

            @(negedge clk);
            en = 1;
        end
    endtask

    initial begin

        $dumpfile("fp8_acc_integration.vcd");
        $dumpvars(0, fp8_acc_integration_tb);

        rst = 1;
        en = 0;
        a = 0;
        b = 0;

        $display("========================================");
        $display("   FP8 MAC INTEGRATION TEST SUITE");
        $display("========================================");

        // Reset
        reset_accumulator();

        // 1. Normal multiplication
        check_mac(8'h40, 8'h38, 32'h40000000,
                  "TEST 1: 2.0 * 1.0 = 2.0");

        // 2. Fractional multiplication and accumulation
        check_mac(8'h3C, 8'h3C, 32'h40880000,
                  "TEST 2: 1.5 * 1.5 + 2.0 = 4.25");

        // 3. Repeated accumulation
        check_mac(8'h38, 8'h38, 32'h40A80000,
                  "TEST 3: 4.25 + 1.0 = 5.25");

        // 4. Negative product
        check_mac(8'hB8, 8'h38, 32'h40880000,
                  "TEST 4: 5.25 + (-1.0) = 4.25");

        // 5. Subtraction and cancellation
        check_mac(8'hC0, 8'h40, 32'h3E800000,
                  "TEST 5: 4.25 + (-4.0) = 0.25");

        // 6. Zero multiplication
        check_mac(8'h00, 8'h38, 32'h3E800000,
                  "TEST 6: 0.0 * 1.0; accumulator unchanged");

        // 7. Enable hold
        check_enable_hold();

        // 8. Resume accumulation
        check_mac(8'h38, 8'h38, 32'h3FA00000,
                  "TEST 7: 0.25 + 1.0 = 1.25");

        // 9. Negative result
        reset_accumulator();

        check_mac(8'hB8, 8'h40, 32'hC0000000,
                  "TEST 8: (-1.0) * 2.0 = -2.0");

        // 10. Smallest FP8 subnormal * 1.0
        reset_accumulator();

        check_mac(8'h01, 8'h38, 32'h3B000000,
                  "TEST 9: Smallest FP8 subnormal * 1.0");

        // 11. Smallest subnormal * smallest subnormal
        reset_accumulator();

        check_mac(8'h01, 8'h01, 32'h36800000,
                  "TEST 10: Smallest subnormal squared");

        // 12. NaN handling
        reset_accumulator();

        check_mac(8'h7F, 8'h38, 32'h7FC00000,
                  "TEST 11: NaN * 1.0");

        // 13. Reset after NaN
        reset_accumulator();

        check_mac(8'h38, 8'h38, 32'h3F800000,
                  "TEST 12: Verify operation after reset");

        // Summary
        $display("\n========================================");
        $display("             TEST SUMMARY");
        $display("========================================");
        $display("Passed : %0d", passed);
        $display("Failed : %0d", failed);
        $display("========================================");

        if (failed == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");

        $finish;
    end

endmodule
