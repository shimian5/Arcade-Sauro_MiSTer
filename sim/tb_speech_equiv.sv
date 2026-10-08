// Equivalence of the clock-enabled Speech256 copy (rtl/sound/speech256_ce) with the pristine import.
// Both receive the same allophone sequence (from a MAME trace of Sauro's firmware). The adapted copy runs
// on the system clock with ce high once in three; the original runs on a clock whose rising edge falls on
// the same system edge that precedes each enabled one, so both complete update k within the same window.
// Outputs are compared once both have updated (at the system edge where div == 1). Any difference in
// sample, sample strobe, ldq or the PWM output is a mismatch.
`timescale 1ns/1ps
module tb_speech_equiv;
	reg clk = 1'b0;                     // system clock
	always #5 clk = ~clk;
	reg [1:0] div = 2'd0;
	always @(posedge clk) div <= (div == 2'd2) ? 2'd0 : div + 2'd1;
	wire ce    = (div == 2'd0);         // adapted copy updates at the edge ending this state
	wire clk_o = (div == 2'd0);         // original copy's clock rises when div enters state 0

	reg rst_an = 1'b0;
	reg [5:0] data = 6'd0;
	reg       stb = 1'b0;               // high across exactly one update of each design
	wire ldq_o, ldq_a, pwm_o, pwm_a, st_o, st_a;
	wire signed [15:0] s_o, s_a;

	SPEECH256_TOP orig (.clk(clk_o), .rst_an(rst_an), .ldq(ldq_o), .data_in(data), .data_stb(stb),
		.pwm_out(pwm_o), .sample_out(s_o), .sample_stb(st_o));
	TCE_SPEECH256_TOP adapted (.clk(clk), .ce(ce), .rst_an(rst_an), .ldq(ldq_a), .data_in(data), .data_stb(stb),
		.pwm_out(pwm_a), .sample_out(s_a), .sample_stb(st_a));

	integer seq_i = 0, n_samples = 0, mismatches = 0, n_cmp = 0, peak = 0, loads = 0;
	reg [5:0] seq [0:8];
	reg ldq_q = 1'b0;
	initial begin
		seq[0] = 6'h28; seq[1] = 6'h28; seq[2] = 6'h14; seq[3] = 6'h00; seq[4] = 6'h29;
		seq[5] = 6'h04; seq[6] = 6'h38; seq[7] = 6'h20; seq[8] = 6'h00;
		#200 rst_an = 1'b1;
	end

	always @(posedge clk) if (rst_an && div == 2'd1) begin
		stb   <= 1'b0;
		ldq_q <= ldq_a;
		if (ldq_a && !ldq_q && seq_i < 9) begin
			data  <= seq[seq_i];
			stb   <= 1'b1;
			seq_i <= seq_i + 1;
			loads <= loads + 1;
		end
		// both designs have completed their update by now
		n_cmp = n_cmp + 1;
		if (n_cmp > 4 && (s_o !== s_a || st_o !== st_a || ldq_o !== ldq_a || pwm_o !== pwm_a)) begin
			mismatches = mismatches + 1;
			if (mismatches < 5) $display("MISMATCH at compare %0d: sample %0d vs %0d, stb %b/%b ldq %b/%b pwm %b/%b",
				n_cmp, s_o, s_a, st_o, st_a, ldq_o, ldq_a, pwm_o, pwm_a);
		end
		if (st_a) begin
			n_samples = n_samples + 1;
			if ((s_a < 0 ? -s_a : s_a) > peak) peak = (s_a < 0 ? -s_a : s_a);
		end
	end

	initial begin
		#150000000;                         // 150 ms of system time: the whole test sequence plays
		$display("%s: %0d compares, %0d samples, peak |sample| %0d, %0d allophones loaded, %0d mismatches",
			mismatches == 0 && n_samples > 100 && loads == 9 ? "PASS" : "FAIL", n_cmp, n_samples, peak, loads, mismatches);
		$finish;
	end
endmodule
