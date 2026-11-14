
`timescale 1ns/1ps

module fp32_to_fp8_tb;

    logic [31:0] acc_out;
    logic [7:0] conv_out;

    integer passed = 0;
    integer failed = 0;

    // DUT
    fp32_to_fp8 dut (
        .acc_out(acc_out),
        .conv_out(conv_out)
    );

    // Test task
    task automatic check_result(
        input logic [31:0] fp32_input,
        input logic [7:0] expected,
        input string test_name
    );
    begin
        acc_out = fp32_input;
        #10;

        if (conv_out === expected) begin
            $display("PASS: %-30s Input=%h Output=%h",
                     test_name, fp32_input, conv_out);
            passed = passed + 1;
        end
        else begin
            $display("FAIL: %-30s Input=%h Expected=%h Got=%h",
                     test_name, fp32_input, expected, conv_out);
            failed = failed + 1;
        end
    end
    endtask

    initial begin

        $dumpfile("fp32_to_fp8.vcd");
        $dumpvars(0, fp32_to_fp8_tb);

        $display("----------------------------------------------");
        $display("       FP32 TO FP8 CONVERTER TESTBENCH");
        $display("----------------------------------------------");

        // ZERO TESTS
        check_result(32'h00000000, 8'h00, "Positive zero");
        check_result(32'h80000000, 8'h80, "Negative zero");

        // NORMAL NUMBER TESTS
        check_result(32'h3F800000, 8'h38, "Positive 1.0");
        check_result(32'h40000000, 8'h40, "Positive 2.0");
        check_result(32'h40400000, 8'h44, "Positive 3.0");
        check_result(32'h40800000, 8'h48, "Positive 4.0");
        check_result(32'h3F000000, 8'h30, "Positive 0.5");
        check_result(32'h3FC00000, 8'h3C, "Positive 1.5");
        check_result(32'hBF800000, 8'hB8, "Negative 1.0");
        check_result(32'hC0000000, 8'hC0, "Negative 2.0");

        // FP8 SUBNORMAL AND NORMAL BOUNDARY TESTS
        check_result(32'h3C800000, 8'h08, "FP8 minimum normal");
        check_result(32'h3C000000, 8'h04, "FP8 subnormal");
        check_result(32'h3B800000, 8'h02, "FP8 subnormal");
        check_result(32'h3B000000, 8'h01, "FP8 minimum subnormal");
        
        // UNDERFLOW TEST
        check_result(32'h00000001, 8'h00, "FP32 smallest subnormal");

        // SPECIAL VALUE TESTS
        check_result(32'h7FC00000, 8'h7F, "Positive NaN");
        check_result(32'hFFC00000, 8'hFF, "Negative NaN");
        check_result(32'h7F800000, 8'h7E, "Positive infinity");
        check_result(32'hFF800000, 8'hFE, "Negative infinity");

        // OVERFLOW TESTS
        check_result(32'h43E00000, 8'h7E, "Maximum FP8 finite");
        check_result(32'h44000000, 8'h7E, "Positive overflow");
        check_result(32'hC4000000, 8'hFE, "Negative overflow");

        // ROUNDING TESTS
        check_result(32'h3F900000, 8'h39, "Rounding test");
        check_result(32'h3F880000, 8'h38, "Tie to even test");

        #10;

        $display("----------------------------------------------");
        $display("             TEST SUMMARY");
        $display("----------------------------------------------");
        $display("Passed : %0d", passed);
        $display("Failed : %0d", failed);
        $display("Total  : %0d", passed + failed);
        $display("----------------------------------------------");

        if (failed == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");

        $finish;
    end

endmodule
