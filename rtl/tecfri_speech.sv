// SP0256-AL2 voice, Sauro family. Wraps the clock-enabled Speech256 copy (rtl/sound/speech256_ce).
//
// What this is and is not: Speech256 does not execute the SP0256's microcode ROM. It takes a 6-bit
// allophone number and synthesises it from its own parameter ROM (derived from the AL2 allophone set).
// Sauro's firmware only ever writes allophone numbers 00-3B (checked in a 150 s MAME gameplay trace), so
// the interface is compatible, but the sound, allophone lengths and exact LRQ timing are the Speech256
// author's reconstruction, not the chip's. The AL2 ROM image in the MRA (sp0256-al2.bin) is therefore not
// used by this block.
//
// Clock: the SP0256 is clocked at 20 MHz / 5 = 4 MHz on the board (MAME, "verified on PCB") and produces one
// sample per 312 clocks, i.e. 12.82 kHz. Speech256 spends 256 of its clocks per sample, so its clock enable
// runs at 4 MHz * 256 / 312 = 3.28205 MHz, generated here by a phase accumulator from the 80 MHz clock.
//
// LRQ: the chip asserts LRQ (active low) when it can take a new allophone; the board wires it to the audio
// CPU's NMI. lrq_n is the inverse of Speech256's ldq. ALD writes are held until an enabled clock samples them.
module tecfri_speech #(
	parameter [31:0] NCO_INC = 32'd176203787,     // round(4e6 * 256 / 312 / 80e6 * 2^32)
	parameter int    BUSY_CYCLES = 240_000         // minimum LRQ-high time after a write: 3 ms at 80 MHz
)(
	input  logic               clk,
	input  logic               reset_n,
	input  logic               hold,            // freeze (pause): no enabled clocks
	input  logic               ald_wr,          // one-clk strobe: address load (allophone) write
	input  logic [7:0]         ald_data,
	output logic               lrq_n,
	output logic signed [15:0] sample           // updated at the speech sample rate
);

	logic [31:0] acc;
	wire  [32:0] acc_sum = {1'b0, acc} + {1'b0, NCO_INC};
	wire         ce      = acc_sum[32] && !hold;
	always_ff @(posedge clk) begin
		if (!hold) acc <= acc_sum[31:0];
	end

	logic       stb_pending;
	logic [5:0] data_l;
	always_ff @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			stb_pending <= 1'b0;
			data_l      <= 6'd0;
		end else begin
			if (ald_wr) begin
				data_l      <= ald_data[5:0];
				stb_pending <= 1'b1;
			end else if (ce) begin
				stb_pending <= 1'b0;
			end
		end
	end

	logic              ldq, sample_stb;
	logic signed [15:0] s_out;
	TCE_SPEECH256_TOP speech (
		.clk(clk), .ce(ce), .rst_an(reset_n),
		.ldq(ldq), .data_in(data_l), .data_stb(stb_pending),
		.pwm_out(), .sample_out(s_out), .sample_stb(sample_stb)
	);

	// LRQ stays high (busy) for at least BUSY_CYCLES after an ALD write. Speech256 can take an allophone and ask for the
	// next within microseconds, so the audio CPU's NMI would arrive while the sound routine that queues the rest of the
	// phrase is still running, find the queue empty, and no later LRQ edge would ever fetch the remainder (the chip then
	// sat on one noise allophone). MAME's SP0256 lets 3-5 ms pass between the first two writes of a phrase
	// (writes at 16.684 s and 16.687 s for the game-over phrase); the real chip's figure is unmeasured.
	logic [18:0] busy_cnt = 19'd0;
	always_ff @(posedge clk or negedge reset_n) begin
		if (!reset_n)                    busy_cnt <= 19'd0;
		else if (ald_wr)                 busy_cnt <= BUSY_CYCLES[18:0];
		else if (busy_cnt != 19'd0 && !hold) busy_cnt <= busy_cnt - 19'd1;
	end
	assign lrq_n = !ldq || (busy_cnt != 19'd0);

	always_ff @(posedge clk) if (ce && sample_stb) sample <= s_out;

endmodule
