// Standalone replay of the speech writes seen in the scripted Sauro run (absolute machine times, from the core simulation
// audio log), to compare the synthesiser's output with the same writes inside the full core.
`timescale 1ps/1ps
module tb_speech_game;
	reg clk = 1'b0;
	always #6250 clk = ~clk;
	reg reset_n = 1'b0, ald_wr = 1'b0;
	reg [7:0] ald_data = 8'h00;
	wire lrq_n;
	wire signed [15:0] sample;
	tecfri_speech dut (.clk(clk), .reset_n(reset_n), .hold(1'b0), .ald_wr(ald_wr), .ald_data(ald_data), .lrq_n(lrq_n), .sample(sample));

	task put(input longint t_ps, input [7:0] d);
		begin
			#(t_ps - $time);
			@(posedge clk); ald_data <= d; ald_wr <= 1'b1; @(posedge clk); ald_wr <= 1'b0;
		end
	endtask

	integer peak = 0, spt_n = 0, ph = 0;
	longint t28 = 64'd10600000000000;
	initial if ($value$plusargs("PH=%d", ph)) t28 = t28 + ph * 6250;
	reg signed [15:0] spt_last = 0;
	always @(posedge clk) if ($time > t28 && dut.ce && dut.speech.sample_stb && dut.s_out !== spt_last && spt_n < 30) begin
		spt_last = dut.s_out; spt_n = spt_n + 1;
		$display("SPT %0d period=%0d dur=%0d amp=%0d", $signed(dut.s_out), dut.speech.period, dut.speech.dur, dut.speech.amp);
	end
	always @(posedge clk) if ($time > t28 && (sample < 0 ? -sample : sample) > peak) peak = (sample < 0 ? -sample : sample);

	integer cf_n = 0;
	always @(posedge clk) if ($time > t28 && dut.ce && dut.speech.coef_load && cf_n < 60) begin
		cf_n = cf_n + 1;
		$display("COEF %0d", $signed(dut.speech.coef_bus));
	end

	initial begin
		#1000000 reset_n = 1'b1;
		put(64'd9768800768750, 8'h1b);
		put(64'd9829672768750, 8'h07);
		put(64'd9839814518750, 8'h2d);
		put(64'd9925924768750, 8'h20);
		put(64'd10098150768750, 8'h00);
		put(t28, 8'h28);
		#(64'd1500000000000);
		$display("peak after the game-over write: %0d", peak);
		$finish;
	end
endmodule
