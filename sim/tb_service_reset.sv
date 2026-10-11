// sauro_service_reset unit test: no reset at power-up or while the switch is steady, a reset of exactly HOLD_CYCLES clocks
// after a change in either direction, and a retrigger when it changes again during a reset.
`timescale 1ns/1ps
module tb_service_reset;
	reg clk = 1'b0;
	always #5 clk = ~clk;
	reg service = 1'b0;
	wire req;
	sauro_service_reset #(.HOLD_CYCLES(100)) dut (.clk(clk), .service(service), .reset_request(req));

	integer errors = 0, n;
	task check(input cond, input [255:0] what);
	begin if (!cond) begin errors = errors + 1; $display("FAIL: %0s", what); end end
	endtask
	task count_high;
	begin n = 0; while (req) begin @(posedge clk); n = n + 1; end end
	endtask

	initial begin
		repeat (20) @(posedge clk);
		check(!req, "no reset at power-up");
		service = 1'b1; @(posedge clk); @(posedge clk);
		check(req, "reset after the switch turns on");
		count_high; check(n >= 98 && n <= 101, "reset lasts about HOLD_CYCLES clocks (on)");
		repeat (50) @(posedge clk); check(!req, "no further reset while steady on");
		service = 1'b0; @(posedge clk); @(posedge clk);
		check(req, "reset after the switch turns off");
		count_high; check(n >= 98 && n <= 101, "reset lasts about HOLD_CYCLES clocks (off)");
		// change again in the middle of a reset: extended, not shortened
		service = 1'b1; @(posedge clk); @(posedge clk); repeat (60) @(posedge clk);
		service = 1'b0; @(posedge clk); @(posedge clk);
		count_high; check(n >= 98, "a second change restarts the hold");
		if (errors == 0) $display("PASS: sauro_service_reset"); else $display("FAIL: %0d errors", errors);
		$finish;
	end
endmodule
