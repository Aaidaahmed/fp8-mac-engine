
`timescale 1ns/1ps

module fp8_mac_e2e_tb;

    logic clk;
    logic rst;
    logic en;

    logic [7:0] input_a;
    logic [7:0] input_b;

    logic [31:0] acc_out;
    logic [7:0] fp8_out;

    integer passed = 0;
    integer failed = 0;

    // DUT
    FP8_MAC dut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .input_a(input_a),
        .input_b(input_b),
        .acc_out(acc_out),
        .fp8_out(fp8_out)
    );

    // Clock generation: 10 ns period
    always #5 clk = ~clk;

    // Apply one MAC operation and check results
    task automatic mac_test(
        input logic [7:0] a,
        input logic [7:0] b,
        input logic [31:0] expected_fp32,
        input logic [7:0] expected_fp8,
        input string test_name
    );
    begin
        @(negedge clk);
        input_a = a;
        input_b = b;
        en = 1'b1;

        @(posedge clk);
        #1;

        if ((acc_out === expected_fp32) &&
            (fp8_out === expected_fp8)) begin

            $display("PASS: %s | FP32=%h | FP8=%h",
                     test_name, acc_out, fp8_out);
            passed = passed + 1;
        end
        else begin
            $display("FAIL: %s | Expected FP32=%h FP8=%h | Got FP32=%h FP8=%h",
                     test_name,
                     expected_fp32, expected_fp8,
                     acc_out, fp8_out);
            failed = failed + 1;
        end

        en = 1'b0;
    end
    endtask

    // Test accumulator hold when enable is low
    task automatic hold_test;
    begin
        @(negedge clk);
        input_a = 8'h40;
        input_b = 8'h40;
        en = 1'b0;

        @(posedge clk);
        #1;

        if ((acc_out === 32'h40500000) &&
            (fp8_out === 8'h45)) begin

            $display("PASS: Enable hold | FP32=%h | FP8=%h",
                     acc_out, fp8_out);
            passed = passed + 1;
        end
        else begin
            $display("FAIL: Enable hold | FP32=%h | FP8=%h",
                     acc_out, fp8_out);
            failed = failed + 1;
        end
    end
    endtask

    initial begin

        clk = 0;
        rst = 1;
        en = 0;
        input_a = 0;
        input_b = 0;

        $dumpfile("fp8_mac_e2e.vcd");
        $dumpvars(0, fp8_mac_e2e_tb);

        $display("------------------------------------------");
        $display("       FP8 MAC END-TO-END TESTBENCH");
        $display("------------------------------------------");

        // Reset
        repeat(2) @(posedge clk);
        #1;
        rst = 0;

        // Test 1: 2.0 * 1.0 = 2.0
        mac_test(
            8'h40, 8'h38,
            32'h40000000, 8'h40,
            "Positive multiplication"
        );

        // Test 2: 1.5 * 1.5 = 2.25
        // Accumulated result = 2.0 + 2.25 = 4.25
        mac_test(
            8'h3C, 8'h3C,
            32'h40880000, 8'h48,
            "Fractional multiplication and accumulation"
        );

        // Test 3: 1.0 * 1.0 = 1.0
        // Accumulated result = 5.25
        mac_test(
            8'h38, 8'h38,
            32'h40A80000, 8'h4A,
            "Repeated accumulation"
        );

        // Test 4: -2.0 * 1.0 = -2.0
        // Accumulated result = 3.25
        mac_test(
            8'hC0, 8'h38,
            32'h40500000, 8'h45,
            "Negative multiplication"
        );

        // Test 5: Enable hold
        hold_test();

        // Test 6: Zero multiplication
        // Accumulated result remains 3.25
        mac_test(
            8'h00, 8'h38,
            32'h40500000, 8'h45,
            "Zero multiplication"
        );


        // ==========================================
        // BOUNDARY VERIFICATION
        // ==========================================

        // A. Minimum FP8 subnormal: 2^-9
        check_result(32'h3A7FFFFF, 8'h00, "Below half minimum subnormal");
        check_result(32'h3A800000, 8'h00, "Half minimum subnormal - tie");
        check_result(32'h3A800001, 8'h01, "Above half minimum subnormal");
        check_result(32'h3B000000, 8'h01, "Minimum FP8 subnormal");

        // B. Rounding between subnormal values
        check_result(32'h3B3FFFFF, 8'h01, "Below 1.5 subnormal units");
        check_result(32'h3B400000, 8'h02, "Tie between subnormal 1 and 2");
        check_result(32'h3B400001, 8'h02, "Above 1.5 subnormal units");

        // C. Maximum subnormal / minimum normal boundary
        check_result(32'h3C600000, 8'h07, "Maximum FP8 subnormal");
        check_result(32'h3C6FFFFF, 8'h07, "Below normal boundary midpoint");
        check_result(32'h3C700000, 8'h08, "Tie at normal boundary");
        check_result(32'h3C700001, 8'h08, "Above normal boundary midpoint");
        check_result(32'h3C800000, 8'h08, "Minimum FP8 normal");

        // D. Maximum finite FP8 / overflow boundary
        check_result(32'h43E00000, 8'h7E, "Maximum finite FP8");
        check_result(32'h43E7FFFF, 8'h7E, "Below overflow midpoint");
        check_result(32'h43E80000, 8'h7E, "Overflow midpoint - tie");
        check_result(32'h43E80001, 8'h7E, "Above overflow midpoint");
        check_result(32'hC3E00000, 8'hFE, "Negative maximum finite FP8");


        // Final summary
        $display("------------------------------------------");
        $display("             TEST SUMMARY");
        $display("------------------------------------------");
        $display("Passed: %0d", passed);
        $display("Failed: %0d", failed);
        $display("Total : %0d", passed + failed);
        $display("------------------------------------------");

        if (failed == 0)
            $display("ALL END-TO-END TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");

        $finish;
    end

endmodule
