// Standalone speech check: plays an allophone sequence through tecfri_speech (80 MHz system clock), feeding
// each next byte when LRQ asserts (as the firmware's NMI handler does), then logs the time of every write and
// writes ~48 kHz raw 16-bit mono PCM of the speech sample stream.
//   +SEQ=<n>   0: 28 28 14 00 29 04 38 20 00   1: 1B 07 2D 20 00   2: 28 3B 2C 0D 3B 37 0D 0C 29 00   +OUT=<prefix>
`timescale 1ps/1ps
module tb_speech;
	reg clk = 1'b0;
	always #6250 clk = ~clk;                // 80 MHz
	reg reset_n = 1'b0;
	reg ald_wr = 1'b0;
	reg [7:0] ald_data = 8'h00;
	wire lrq_n;
	wire signed [15:0] sample;
	tecfri_speech dut (.clk(clk), .reset_n(reset_n), .hold(1'b0), .ald_wr(ald_wr), .ald_data(ald_data), .lrq_n(lrq_n), .sample(sample));

	reg [7:0] seq [0:15];
	integer n = 0, idx = 0, seqsel = 0, raw_f, log_f, div = 0, samples = 0, peak = 0;
	reg [1023:0] outname, fname;
	reg lrq_q = 1'b1;
	longint t_last = 0;
	reg [15:0] s16;

	initial begin
		if (!$value$plusargs("OUT=%s", outname)) outname = "speech";
		if (!$value$plusargs("SEQ=%d", seqsel)) seqsel = 0;
		case (seqsel)
			0: begin n = 9;  {seq[0],seq[1],seq[2],seq[3],seq[4],seq[5],seq[6],seq[7],seq[8]} = {8'h28,8'h28,8'h14,8'h00,8'h29,8'h04,8'h38,8'h20,8'h00}; end
			1: begin n = 5;  {seq[0],seq[1],seq[2],seq[3],seq[4]} = {8'h1B,8'h07,8'h2D,8'h20,8'h00}; end
			3: begin n = 14; {seq[0],seq[1],seq[2],seq[3],seq[4],seq[5],seq[6],seq[7],seq[8],seq[9],seq[10],seq[11],seq[12],seq[13]} = {8'h1B,8'h07,8'h2D,8'h20,8'h00,8'h28,8'h28,8'h14,8'h00,8'h29,8'h04,8'h38,8'h20,8'h00}; end
			default: begin n = 10; {seq[0],seq[1],seq[2],seq[3],seq[4],seq[5],seq[6],seq[7],seq[8],seq[9]} = {8'h28,8'h3B,8'h2C,8'h0D,8'h3B,8'h37,8'h0D,8'h0C,8'h29,8'h00}; end
		endcase
		$sformat(fname, "%0s.raw", outname);  raw_f = $fopen(fname, "wb");
		$sformat(fname, "%0s.log", outname);  log_f = $fopen(fname, "w");
		#1000000 reset_n = 1'b1;
	end

	// Firmware-like driver: when LRQ falls, write the next byte after 20 us (NMI latency + handler)
	integer spt_n = 0; reg signed [15:0] spt_last = 0;
	always @(posedge clk) if (idx >= 6 && dut.ce && dut.speech.sample_stb && dut.s_out !== spt_last && spt_n < 40) begin
		spt_last = dut.s_out; spt_n = spt_n + 1;
		$display("SPT %0d period=%0d dur=%0d amp=%0d", $signed(dut.s_out), dut.speech.period, dut.speech.dur, dut.speech.amp);
	end
	integer wait_cnt = 0, delay_clk = 0;
	initial if ($value$plusargs("DELAY=%d", delay_clk)) ;
	reg pending = 1'b0;
	always @(posedge clk) begin
		ald_wr <= 1'b0;
		lrq_q  <= lrq_n;
		if (reset_n && !lrq_n && lrq_q) begin pending <= 1'b1; wait_cnt <= 0; end
		if (pending) begin
			wait_cnt <= wait_cnt + 1;
			if (wait_cnt == ((seqsel == 3 && idx == 5) ? 640_000_000 : (idx == 0 ? 1600 + delay_clk : 1600)) && idx < n) begin           // 20 us at 80 MHz
				ald_data <= seq[idx]; ald_wr <= 1'b1; pending <= 1'b0;
				$fwrite(log_f, "write %02x at %0d us (since previous write %0d us)\n", seq[idx], $time / 1000000, ($time - t_last) / 1000000);
				t_last = $time; idx <= idx + 1;
			end
			if (idx >= n) pending <= 1'b0;
		end
		div = div + 1;
		if (div >= 1667) begin
			div = 0; s16 = sample; $fwrite(raw_f, "%c%c", s16[7:0], s16[15:8]); samples = samples + 1;
			if ((sample < 0 ? -sample : sample) > peak) peak = (sample < 0 ? -sample : sample);
		end
	end

	initial begin
		#(seqsel == 3 ? 64'd1500000000000 + 64'd8000000000000 : 64'd1500000000000);   // 1.5 s (+8 s idle gap for SEQ 3)
		$fclose(raw_f); $fclose(log_f);
		$display("speech: %0d writes, %0d PCM samples, peak %0d", idx, samples, peak);
		$finish;
	end
endmodule
