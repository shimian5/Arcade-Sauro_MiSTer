// End-to-end: ROM download through the ioctl interface, reset, original-ROM execution, video.
// Frames are dumped at the Nth interrupt acknowledge, which matches sim/mame/dump_frame.lua
// (it snapshots at interrupt entry), so the files compare directly with MAME's dumps.
//
//   +IMAGE=<hex>  assembled image (tools/make_core_vectors.py)   +TRICKY
//   +F0..+F7=<n>  acknowledge counts at which the last complete frame is written
//   +OUT=<prefix> output prefix (files <prefix>_<n>.hex)
//   +WAV             write the mixed audio as 16-bit mono raw PCM at ~48 kHz to <prefix>.raw (tools/raw2wav.py)
//                    and the sound-chip write log to <prefix>_audio.log
//   +NVIMAGE=<hex>   restore this 2048-byte battery RAM image (index 4) after the ROM download
//   +NVSAVE=<n>      at the nth acknowledge run an upload (save) and write <prefix>_nvsave.hex
//   +PAUSE_AT=<n> +PAUSE_FRAMES=<m>  hold pause for m frame times after the nth acknowledge
`timescale 1ps/1ps
module tb_core;
	reg clk = 1'b0;
	always #6250 clk = ~clk;                // 80 MHz

	reg        reset = 1'b1;
	reg        pause = 1'b0;
	reg        ioctl_download = 1'b0, ioctl_wr = 1'b0;
	reg [15:0] ioctl_index = 16'd0;
	reg [24:0] ioctl_addr = 25'd0;
	reg [7:0]  ioctl_data = 8'd0;

	reg        ioctl_upload = 1'b0, ioctl_rd = 1'b0;
	wire [7:0] nv_data;
	wire       nv_save_request, nv_transfer;
	wire signed [15:0] audio, dbg_ym, dbg_speech;
	wire        dbg_ym_wr, dbg_ym_a0, dbg_ald_wr, dbg_cmd_rd;
	wire [7:0]  dbg_ym_d, dbg_ald_d;
	wire        ce_pix, hblank, vblank, hsync, vsync, rom_ready, dbg_int_ack, dbg_bus_wr, dbg_bus_io;
	wire [7:0]  vid_r, vid_g, vid_b, dbg_bus_d;
	wire [8:0]  pix_x, pix_y;
	wire [15:0] dbg_bus_a;

	tecfri_core core (
		.clk(clk), .reset(reset), .pause(pause),
		.ioctl_download(ioctl_download), .ioctl_upload(ioctl_upload), .ioctl_rd(ioctl_rd), .ioctl_wr(ioctl_wr), .ioctl_index(ioctl_index),
		.ioctl_addr(ioctl_addr), .ioctl_data(ioctl_data),
		.dsw1(8'h66), .dsw2(8'h2f), .p1(8'h00), .p2(8'h00),
		.ce_pix(ce_pix), .vid_r(vid_r), .vid_g(vid_g), .vid_b(vid_b),
		.hblank(hblank), .vblank(vblank), .hsync(hsync), .vsync(vsync),
		.pix_x(pix_x), .pix_y(pix_y), .rom_ready(rom_ready), .audio(audio), .nv_data(nv_data), .nv_save_request(nv_save_request), .nv_transfer(nv_transfer),
		.dbg_ym(dbg_ym), .dbg_speech(dbg_speech), .dbg_ym_wr(dbg_ym_wr), .dbg_ym_a0(dbg_ym_a0), .dbg_ym_d(dbg_ym_d),
		.dbg_ald_wr(dbg_ald_wr), .dbg_ald_d(dbg_ald_d), .dbg_cmd_rd(dbg_cmd_rd),
		.dbg_int_ack(dbg_int_ack), .dbg_bus_wr(dbg_bus_wr), .dbg_bus_io(dbg_bus_io),
		.dbg_bus_a(dbg_bus_a), .dbg_bus_d(dbg_bus_d));

	reg [7:0]  image [0:'h593FF];
	reg [7:0]  nvimg [0:2047];
	reg        nv_restore = 1'b0;
	integer    nvsave_at = 0, hs_writes = 0, bus_writes_during_save = 0, nv_req_seen = 0;
	reg        nv_saving = 1'b0;
	reg [1023:0] nvname;
	reg [23:0] cur  [0:240*224-1];
	reg [23:0] snap [0:240*224-1];
	integer want [0:7];
	integer nwant = 0, maxwant = 0, acks = 0, i, k, fo;
	reg [1023:0] imgname, outname, fname, key;
	reg tricky_arg = 1'b0;

	// Pause test: the CPU must stop (no bus writes, no new interrupt acknowledges) while video
	// timing keeps running; afterwards the machine must carry on.
	integer pause_at = 0, pause_frames = 0, pause_clks_left = 0, p_writes = 0, p_ce = 0, p_acks = 0, p_vsync = 0, after_acks = 0;
	reg paused_once = 1'b0, vsync_q = 1'b0;
	always @(posedge clk) begin
		vsync_q <= vsync;
		if (pause) begin
			if (dbg_bus_wr) p_writes = p_writes + 1;
			if (dbg_int_ack) p_acks = p_acks + 1;
			if (ce_pix) p_ce = p_ce + 1;
			if (vsync && !vsync_q) p_vsync = p_vsync + 1;
			pause_clks_left = pause_clks_left - 1;
			if (pause_clks_left == 0) begin
				pause <= 1'b0;
				$display("PAUSE released: bus writes=%0d interrupt acks=%0d pixel clocks=%0d vsync pulses=%0d", p_writes, p_acks, p_ce, p_vsync);
			end
		end else if (paused_once && dbg_int_ack) after_acks = after_acks + 1;
	end

	always @(posedge clk) if (ce_pix && !hblank && !vblank) cur[pix_y * 240 + pix_x] <= {vid_r, vid_g, vid_b};

	// Audio export: sample the mix at about 48 kHz, and log chip writes with machine time in ps.
	integer wav_f = 0, log_f = 0, wav_div = 0, wav_n = 0, ym_writes = 0, ald_writes = 0, cmd_reads = 0;
	integer ym_peak = 0, sp_peak = 0, mix_peak = 0;
	reg [15:0] wav_s;
	always @(posedge clk) begin
		if (wav_f != 0) begin
			wav_div = wav_div + 1;
			if (wav_div >= 1667) begin
				wav_div = 0;
				wav_s = audio;
				$fwrite(wav_f, "%c%c", wav_s[7:0], wav_s[15:8]);
				wav_n = wav_n + 1;
			end
		end
		if (dbg_ym_wr)  begin ym_writes = ym_writes + 1;   if (log_f != 0) $fwrite(log_f, "%0t YM a0=%b d=%02x\n", $time, dbg_ym_a0, dbg_ym_d); end
		if (dbg_ald_wr) begin ald_writes = ald_writes + 1; if (log_f != 0) $fwrite(log_f, "%0t ALD %02x\n", $time, dbg_ald_d); end
		if (core.snd_cmd_wr) if (log_f != 0) $fwrite(log_f, "%0t CMD %02x\n", $time, core.snd_cmd);
		if (dbg_cmd_rd) begin cmd_reads = cmd_reads + 1; end
		if ((dbg_ym < 0 ? -dbg_ym : dbg_ym) > ym_peak) ym_peak = (dbg_ym < 0 ? -dbg_ym : dbg_ym);
		if ((dbg_speech < 0 ? -dbg_speech : dbg_speech) > sp_peak) sp_peak = (dbg_speech < 0 ? -dbg_speech : dbg_speech);
		if ((audio < 0 ? -audio : audio) > mix_peak) mix_peak = (audio < 0 ? -audio : audio);
	end

	// hi-score bytes (E057-E059): the game writes its default here only when it rejects the battery RAM image
	always @(posedge clk) begin
		if (dbg_bus_wr && !dbg_bus_io && dbg_bus_a >= 16'hE057 && dbg_bus_a <= 16'hE059) begin
			hs_writes = hs_writes + 1;
			if (log_f != 0) $fwrite(log_f, "%0t HISCORE write %04x=%02x\n", $time, dbg_bus_a, dbg_bus_d);
		end
		if (nv_saving && dbg_bus_wr) bus_writes_during_save = bus_writes_during_save + 1;
		if (nv_save_request) nv_req_seen = nv_req_seen + 1;
	end

	reg vb_q = 1'b0;
	always @(posedge clk) begin
		vb_q <= vblank;
		if (vblank && !vb_q) for (k = 0; k < 240 * 224; k = k + 1) snap[k] = cur[k];
	end

	always @(posedge clk) if (dbg_int_ack) begin
		acks = acks + 1;
		if (pause_at != 0 && acks == pause_at && !paused_once) begin
			paused_once = 1'b1; pause <= 1'b1; pause_clks_left = pause_frames * 316 * 284 * 16;
		end
		for (i = 0; i < nwant; i = i + 1) if (want[i] == acks) begin
			$sformat(fname, "%0s_%0d.hex", outname, acks);
			fo = $fopen(fname, "w");
			for (k = 0; k < 240 * 224; k = k + 1) $fwrite(fo, "%06x\n", snap[k]);
			$fclose(fo);
			// Machine state at the same instant: E000-FFFF as the CPU sees it, then latch and scrolls
			$sformat(fname, "%0s_%0d_ram.hex", outname, acks);
			fo = $fopen(fname, "w");
			for (k = 0; k < 2048; k = k + 1) $fwrite(fo, "%02x\n", core.nvram.mem[k]);
			for (k = 0; k < 1024; k = k + 1) $fwrite(fo, "%02x\n", core.main.spr[k]);
			for (k = 0; k < 1024; k = k + 1) $fwrite(fo, "%02x\n", core.main.bgv[k]);
			for (k = 0; k < 1024; k = k + 1) $fwrite(fo, "%02x\n", core.main.bgc[k]);
			for (k = 0; k < 1024; k = k + 1) $fwrite(fo, "%02x\n", core.main.fgv[k]);
			for (k = 0; k < 1024; k = k + 1) $fwrite(fo, "%02x\n", core.main.fgc[k]);
			$fwrite(fo, "%02x\n%02x\n%02x\n", core.scroll_bg, core.scroll_fg, core.main.latch_q);
			$fclose(fo);
			$display("frame at acknowledge %0d written (t=%0t ps)", acks, $time);
		end
		if (acks > maxwant) begin
			$display("done after %0d interrupt acknowledges (%0d after resume)", acks, after_acks);
			$display("hi-score writes (E057-E059) by the CPU: %0d; NVRAM save requests seen: %0d cycles", hs_writes, nv_req_seen);
			$display("audio: %0d YM writes, %0d speech writes, %0d sound-command reads, %0d PCM samples, peaks ym=%0d speech=%0d mix=%0d",
				ym_writes, ald_writes, cmd_reads, wav_n, ym_peak, sp_peak, mix_peak);
			if (wav_f != 0) $fclose(wav_f);
			if (log_f != 0) $fclose(log_f);
			$finish;
		end
	end

	task do_upload;
		integer n;
		reg [7:0] img [0:2047];
	begin
		nv_saving = 1'b1;
		@(posedge clk); ioctl_index <= 16'd4; ioctl_upload <= 1'b1; ioctl_addr <= 25'd0; ioctl_rd <= 1'b1;
		@(posedge clk); ioctl_rd <= 1'b0;
		for (n = 0; n < 2048; n = n + 1) begin
			@(posedge clk); @(posedge clk);
			img[n] = nv_data;
			ioctl_addr <= n + 1; ioctl_rd <= 1'b1;
			@(posedge clk); ioctl_rd <= 1'b0;
		end
		@(posedge clk); ioctl_upload <= 1'b0; repeat (4) @(posedge clk);
		nv_saving = 1'b0;
		$sformat(nvname, "%0s_nvsave.hex", outname);
		fo = $fopen(nvname, "w");
		for (n = 0; n < 2048; n = n + 1) $fwrite(fo, "%02x\n", img[n]);
		$fclose(fo);
		$display("NVRAM upload written (CPU bus writes during the transfer: %0d)", bus_writes_during_save);
	end
	endtask

	task send(input [15:0] idx, input [24:0] addr, input [7:0] data);
	begin
		@(posedge clk); ioctl_index <= idx; ioctl_addr <= addr; ioctl_data <= data; ioctl_wr <= 1'b1;
		@(posedge clk); ioctl_wr <= 1'b0;
		@(posedge clk);
	end
	endtask

	initial begin
		if (!$value$plusargs("IMAGE=%s", imgname)) $fatal(1, "need +IMAGE=");
		if (!$value$plusargs("OUT=%s", outname)) outname = "core";
		tricky_arg = $test$plusargs("TRICKY");
		if ($value$plusargs("NVIMAGE=%s", nvname)) begin nv_restore = 1'b1; $readmemh(nvname, nvimg); end
		if ($value$plusargs("NVSAVE=%d", nvsave_at)) ;
		if ($test$plusargs("WAV")) begin
			$sformat(fname, "%0s.raw", outname);       wav_f = $fopen(fname, "wb");
			$sformat(fname, "%0s_audio.log", outname); log_f = $fopen(fname, "w");
		end
		if ($value$plusargs("PAUSE_AT=%d", k)) pause_at = k;
		if ($value$plusargs("PAUSE_FRAMES=%d", k)) pause_frames = k;
		for (i = 0; i < 8; i = i + 1) begin
			$sformat(key, "F%0d=%%d", i);
			if ($value$plusargs(key, k)) begin want[nwant] = k; nwant = nwant + 1; if (k > maxwant) maxwant = k; end
		end
		for (i = 0; i <= 'h593FF; i = i + 1) image[i] = 8'h00;
		$readmemh(imgname, image);
		repeat (40) @(posedge clk);
		ioctl_download <= 1'b1;
		send(16'd1, 25'd0, {7'd0, tricky_arg});
		for (i = 0; i <= 'h593FF; i = i + 1) send(16'd0, i, image[i]);
		if (nv_restore) for (i = 0; i < 2048; i = i + 1) send(16'd4, i, nvimg[i]);   // battery RAM restore, after the ROM
		@(posedge clk); ioctl_download <= 1'b0;
		repeat (20) @(posedge clk);
		reset <= 1'b0;
		$display("download complete, reset released (rom_ready=%0d)", rom_ready);
	end

	// Progress line every 100 ms of machine time (keeps long runs visibly alive on the host side).
	initial begin
		#1;
		if (nvsave_at != 0) begin
			wait (acks >= nvsave_at);
			do_upload;
		end
	end

	initial forever begin
		#100000000000;
		$display("progress t=%0t ps, %0d interrupt acknowledges", $time, acks);
		$fflush;
	end

	integer stop_ms = 4000;
	time stop_t;
	initial begin
		if ($value$plusargs("MS=%d", stop_ms)) ;
		stop_t = stop_ms;
		stop_t = stop_t * 64'd1000000000;		// ps; 64-bit so multi-second limits do not overflow
		#(stop_t);							// machine time safety stop (default 4 s, +MS=<ms> to change)
		$display("TIMEOUT after %0d acknowledges", acks);
		$display("audio: %0d YM writes, %0d speech writes, %0d sound-command reads, %0d PCM samples, peaks ym=%0d speech=%0d mix=%0d",
			ym_writes, ald_writes, cmd_reads, wav_n, ym_peak, sp_peak, mix_peak);
		if (wav_f != 0) $fclose(wav_f);
		if (log_f != 0) $fclose(log_f);
		$finish;
	end
endmodule
