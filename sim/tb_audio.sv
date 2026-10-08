// Sauro audio board only (sound CPU, YM3812, SP0256 model): no video or main CPU, so seconds of sound take minutes to
// simulate rather than the quarter hour the full core needs. The sound ROM is loaded from the assembled ROM image and
// sound commands (+CMD=<hex>) are sent at +CMD_AT=<ms>, as the main CPU would. Logs speech writes and peaks.
//   +IMAGE=<hex> +CMD=<hex> [+CMD2=<hex> +CMD2_AT=<ms>] +CMD_AT=<ms> +MS=<run ms> +OUT=<prefix>
`timescale 1ps/1ps
module tb_audio;
	reg clk = 1'b0;
	always #6250 clk = ~clk;
	reg reset_n = 1'b0, rom_we = 1'b0, snd_cmd_wr = 1'b0;
	reg [14:0] rom_wa = 0;
	reg [7:0] rom_wd = 0, snd_cmd = 0;
	wire signed [15:0] ym_out, speech_out, mix_out;
	wire dbg_ym_wr, dbg_ym_a0, dbg_ald_wr, dbg_cmd_rd;
	wire [7:0] dbg_ym_d, dbg_ald_d;

	tecfri_audio dut (
		.clk(clk), .reset_n(reset_n), .pause(1'b0), .tricky(1'b0), .speech_mute(1'b0), .tone_en(1'b0), .dbg_sel(4'd0),
		.rom_we(rom_we), .rom_wa(rom_wa), .rom_wd(rom_wd),
		.snd_cmd_wr(snd_cmd_wr), .snd_cmd(snd_cmd), .main_ym_wr(1'b0), .main_ym_a0(1'b0), .main_ym_d(8'h00),
		.ym_out(ym_out), .speech_out(speech_out), .mix_out(mix_out),
		.dbg_ym_wr(dbg_ym_wr), .dbg_ym_a0(dbg_ym_a0), .dbg_ym_d(dbg_ym_d),
		.dbg_ald_wr(dbg_ald_wr), .dbg_ald_d(dbg_ald_d), .dbg_cmd_rd(dbg_cmd_rd));

	reg [7:0] img [0:'h60000];
	reg [1023:0] imgname, outname, fname;
	integer log_f, raw_f, i, cmd = 0, cmd_at = 1000, cmd2 = -1, cmd2_at = 0, stop_ms = 4000, div = 0, n_ald = 0;
	integer sp_peak = 0, mix_peak = 0, sp_after = 0;
	reg [15:0] s16;
	time t_cmd = 0;

	task send(input [7:0] c);
		begin @(posedge clk); snd_cmd <= c; snd_cmd_wr <= 1'b1; @(posedge clk); snd_cmd_wr <= 1'b0; end
	endtask

	initial begin
		if (!$value$plusargs("IMAGE=%s", imgname)) $fatal(1, "need +IMAGE=");
		if (!$value$plusargs("OUT=%s", outname)) outname = "audio";
		if ($value$plusargs("CMD=%h", cmd)) ;
		if ($value$plusargs("CMD_AT=%d", cmd_at)) ;
		if ($value$plusargs("CMD2=%h", cmd2)) ;
		if ($value$plusargs("CMD2_AT=%d", cmd2_at)) ;
		if ($value$plusargs("MS=%d", stop_ms)) ;
		$readmemh(imgname, img);
		$sformat(fname, "%0s.log", outname); log_f = $fopen(fname, "w");
		$sformat(fname, "%0s.raw", outname); raw_f = $fopen(fname, "wb");
		for (i = 0; i < 32768; i = i + 1) begin
			@(posedge clk); rom_wa <= i; rom_wd <= img['h10000 + i]; rom_we <= 1'b1;
			@(posedge clk); rom_we <= 1'b0;
		end
		#1000000 reset_n = 1'b1;
		#(cmd_at * 64'd1000000000);
		t_cmd = $time;
		if (cmd >= 0) begin send(cmd[7:0]); $fwrite(log_f, "%0t CMD %02x\n", $time, cmd[7:0]); end
		if (cmd2 >= 0) begin #(cmd2_at * 64'd1000000000); send(cmd2[7:0]); $fwrite(log_f, "%0t CMD %02x\n", $time, cmd2[7:0]); end
		#((stop_ms - cmd_at) * 64'd1000000000);
		$display("audio-only: %0d speech writes, peaks speech=%0d mix=%0d", n_ald, sp_peak, mix_peak);
		$fclose(log_f); $fclose(raw_f);
		$finish;
	end

	always @(posedge clk) begin
		if (dbg_ald_wr) begin n_ald = n_ald + 1; $fwrite(log_f, "%0t ALD %02x\n", $time, dbg_ald_d); end
		if ((speech_out < 0 ? -speech_out : speech_out) > sp_peak) sp_peak = (speech_out < 0 ? -speech_out : speech_out);
		if ((mix_out < 0 ? -mix_out : mix_out) > mix_peak) mix_peak = (mix_out < 0 ? -mix_out : mix_out);
		div = div + 1;
		if (div >= 1667) begin div = 0; s16 = mix_out; $fwrite(raw_f, "%c%c", s16[7:0], s16[15:8]); end
	end
endmodule
