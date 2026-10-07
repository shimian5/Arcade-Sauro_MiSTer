// End-to-end: ROM download through the ioctl interface, reset, original-ROM execution, video.
// Frames are dumped at the Nth interrupt acknowledge, which matches sim/mame/dump_frame.lua
// (it snapshots at interrupt entry), so the files compare directly with MAME's dumps.
//
//   +IMAGE=<hex>  assembled image (tools/make_core_vectors.py)   +TRICKY
//   +F0..+F7=<n>  acknowledge counts at which the last complete frame is written
//   +OUT=<prefix> output prefix (files <prefix>_<n>.hex)
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

	wire        ce_pix, hblank, vblank, hsync, vsync, rom_ready, dbg_int_ack, dbg_bus_wr, dbg_bus_io;
	wire [7:0]  vid_r, vid_g, vid_b, dbg_bus_d;
	wire [8:0]  pix_x, pix_y;
	wire [15:0] dbg_bus_a;

	tecfri_core core (
		.clk(clk), .reset(reset), .pause(pause),
		.ioctl_download(ioctl_download), .ioctl_wr(ioctl_wr), .ioctl_index(ioctl_index),
		.ioctl_addr(ioctl_addr), .ioctl_data(ioctl_data),
		.dsw1(8'h66), .dsw2(8'h2f), .p1(8'h00), .p2(8'h00),
		.ce_pix(ce_pix), .vid_r(vid_r), .vid_g(vid_g), .vid_b(vid_b),
		.hblank(hblank), .vblank(vblank), .hsync(hsync), .vsync(vsync),
		.pix_x(pix_x), .pix_y(pix_y), .rom_ready(rom_ready),
		.dbg_int_ack(dbg_int_ack), .dbg_bus_wr(dbg_bus_wr), .dbg_bus_io(dbg_bus_io),
		.dbg_bus_a(dbg_bus_a), .dbg_bus_d(dbg_bus_d));

	reg [7:0]  image [0:'h593FF];
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
			for (k = 0; k < 2048; k = k + 1) $fwrite(fo, "%02x\n", core.main.wram[k]);
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
			$finish;
		end
	end

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
		@(posedge clk); ioctl_download <= 1'b0;
		repeat (20) @(posedge clk);
		reset <= 1'b0;
		$display("download complete, reset released (rom_ready=%0d)", rom_ready);
	end

	initial begin
		#4000000000000;						// 4 s of machine time as a safety stop
		$display("TIMEOUT after %0d acknowledges", acks);
		$finish;
	end
endmodule
