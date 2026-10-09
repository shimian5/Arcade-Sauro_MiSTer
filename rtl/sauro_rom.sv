// Simple dual-port synchronous memory: one write port (ROM download), one read port.
// One clk of read latency, matching what sauro_video and sauro_main assume.
// Inferred as M10K block RAM; the Quartus fit report must confirm the mapping.
module sauro_rom #(
	parameter int AW = 16
)(
	input  logic          clk,
	input  logic          we,
	input  logic [AW-1:0] wa,
	input  logic [7:0]    wd,
	input  logic [AW-1:0] ra,
	output logic [7:0]    q
);
	logic [7:0] mem [0:(1 << AW) - 1];

	always_ff @(posedge clk) begin
		if (we) mem[wa] <= wd;
		q <= mem[ra];
	end
endmodule
