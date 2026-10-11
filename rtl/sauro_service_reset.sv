// Core reset when the Service DIP switch changes.
//
// The Sauro-family firmware samples DIP bank 1 once during start-up and decides there whether to enter its test mode
// (main ROM: IN A,(0) at 034E, bit 0 test in the init path; MAME's notes: switches "must be defined before resetting").
// Changing the Service switch while a game runs therefore does nothing until the machine restarts, so a change of the
// switch value requests a core reset, held for HOLD_CYCLES so the whole machine (both Z80s, YM3812, speech) restarts.
// The value is compared with its previous value, so the first DIP load after power-up (the MRA's value replacing the
// default) only causes a reset if it differs; the machine is held in reset during that download anyway.
module sauro_service_reset #(
	parameter int HOLD_CYCLES = 8_000_000      // 100 ms at 80 MHz
)(
	input  logic clk,
	input  logic service,                      // DSW1 bit 0 as captured from the MRA / OSD DIP menu
	output logic reset_request
);
	logic service_q = 1'b0;
	logic [$clog2(HOLD_CYCLES + 1) - 1:0] hold = '0;

	always_ff @(posedge clk) begin
		service_q <= service;
		if (service != service_q)  hold <= HOLD_CYCLES[$bits(hold) - 1:0];
		else if (hold != '0)       hold <= hold - 1'b1;
	end

	assign reset_request = (hold != '0);
endmodule
