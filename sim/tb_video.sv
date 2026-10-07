// Video block vs a MAME frame dump (vectors from tools/prep_video_vectors.py).
// Video RAMs, graphics ROMs and colour PROMs are behavioural arrays with 1 clk read latency.
// The testbench runs three frames and writes the last complete frame as RRGGBB lines.
//
//   +DIR=<vector dir>   +OUT=<file>   +BG= +FG= +BANK= +TRICKY
`timescale 1ps/1ps
module tb_video;
	reg clk = 1'b0;
	reg reset_n = 1'b0;
	always #6250 clk = ~clk;				// 80 MHz
	reg [3:0] div = 4'd0;
	always @(posedge clk) div <= div + 4'd1;
	wire pix_cen = (div == 4'd0);			// 5 MHz pixel enable (16 clk per pixel)

	wire [8:0] hcnt, vcnt;
	wire hblank, vblank, vblank_start;
	tecfri_timing timing (.clk(clk), .reset_n(reset_n), .pix_cen(pix_cen), .hcnt(hcnt), .vcnt(vcnt),
		.hblank(hblank), .vblank(vblank), .vblank_start(vblank_start));

	reg [7:0] r_spr [0:1023];
	reg [7:0] r_bgv [0:1023];
	reg [7:0] r_bgc [0:1023];
	reg [7:0] r_fgv [0:1023];
	reg [7:0] r_fgc [0:1023];
	reg [7:0] g_bg  [0:65535];
	reg [7:0] g_fg  [0:65535];
	reg [7:0] g_spr [0:131071];
	reg [7:0] p_r   [0:1023];
	reg [7:0] p_g   [0:1023];
	reg [7:0] p_b   [0:1023];

	wire [9:0]  vid_bg_a, vid_fg_a, vid_spr_a, pal_a;
	wire [15:0] bg_rom_a, fg_rom_a;
	wire [16:0] spr_rom_a;
	reg  [7:0]  bgv_d, bgc_d, fgv_d, fgc_d, spr_d, bg_d, fg_d, sprg_d;
	reg  [3:0]  pr, pg, pb;
	always @(posedge clk) begin
		bgv_d <= r_bgv[vid_bg_a];  bgc_d <= r_bgc[vid_bg_a];
		fgv_d <= r_fgv[vid_fg_a];  fgc_d <= r_fgc[vid_fg_a];
		spr_d <= r_spr[vid_spr_a];
		bg_d  <= g_bg[bg_rom_a];   fg_d <= g_fg[fg_rom_a];   sprg_d <= g_spr[spr_rom_a];
		pr <= p_r[pal_a][3:0];     pg <= p_g[pal_a][3:0];    pb <= p_b[pal_a][3:0];
	end

	reg tricky = 1'b0;
	reg [7:0] scroll_bg = 8'd0, scroll_fg = 8'd0;
	reg [1:0] bank = 2'd0;
	wire [7:0] out_r, out_g, out_b;
	wire out_de;
	wire [8:0] out_x, out_y;
	tecfri_video video (
		.clk(clk), .reset_n(reset_n), .pix_cen(pix_cen), .hcnt(hcnt), .vcnt(vcnt), .tricky(tricky),
		.palette_bank(bank), .scroll_bg(scroll_bg), .scroll_fg_raw(scroll_fg),
		.vid_bg_a(vid_bg_a), .vid_fg_a(vid_fg_a), .vid_spr_a(vid_spr_a),
		.vid_bgv_d(bgv_d), .vid_bgc_d(bgc_d), .vid_fgv_d(fgv_d), .vid_fgc_d(fgc_d), .vid_spr_d(spr_d),
		.bg_rom_a(bg_rom_a), .bg_rom_d(bg_d), .fg_rom_a(fg_rom_a), .fg_rom_d(fg_d),
		.spr_rom_a(spr_rom_a), .spr_rom_d(sprg_d),
		.pal_a(pal_a), .pal_r(pr), .pal_g(pg), .pal_b(pb),
		.out_r(out_r), .out_g(out_g), .out_b(out_b), .out_de(out_de), .out_x(out_x), .out_y(out_y));

	reg [23:0] frame [0:240*224-1];
	integer fcount = 0, i, fo;
	reg [1023:0] dir, outname, path;
	integer bgv_i, fgv_i, bank_i;

	always @(posedge clk) if (pix_cen && out_de) frame[out_y * 240 + out_x] <= {out_r, out_g, out_b};

	// Sprite engine budget check: the engine must be idle again when the next line starts.
	integer overruns = 0, busy_peak = 0, busy = 0;
	always @(posedge clk) begin
		if (video.line_start) begin
			if (video.eng != 4'd0 && fcount >= 1) overruns <= overruns + 1;
			busy <= 0;
		end else if (video.eng != 4'd0) begin
			busy <= busy + 1;
			if (busy + 1 > busy_peak) busy_peak <= busy + 1;
		end
	end

	reg vb_q = 1'b0;
	always @(posedge clk) begin
		vb_q <= vblank;
		if (vblank && !vb_q) fcount <= fcount + 1;
	end

	initial begin
		if (!$value$plusargs("DIR=%s", dir)) $fatal(1, "need +DIR=");
		if (!$value$plusargs("OUT=%s", outname)) outname = "frame.hex";
		if ($value$plusargs("BG=%d", bgv_i)) scroll_bg = bgv_i[7:0];
		if ($value$plusargs("FG=%d", fgv_i)) scroll_fg = fgv_i[7:0];
		if ($value$plusargs("BANK=%d", bank_i)) bank = bank_i[1:0];
		if ($test$plusargs("TRICKY")) tricky = 1'b1;
		$sformat(path, "%0s/spr.hex", dir);     $readmemh(path, r_spr);
		$sformat(path, "%0s/bgv.hex", dir);     $readmemh(path, r_bgv);
		$sformat(path, "%0s/bgc.hex", dir);     $readmemh(path, r_bgc);
		$sformat(path, "%0s/fgv.hex", dir);     $readmemh(path, r_fgv);
		$sformat(path, "%0s/fgc.hex", dir);     $readmemh(path, r_fgc);
		$sformat(path, "%0s/bg.hex", dir);      $readmemh(path, g_bg);
		$sformat(path, "%0s/fg.hex", dir);      $readmemh(path, g_fg);
		$sformat(path, "%0s/spr_gfx.hex", dir); $readmemh(path, g_spr);
		$sformat(path, "%0s/prom_r.hex", dir);  $readmemh(path, p_r);
		$sformat(path, "%0s/prom_g.hex", dir);  $readmemh(path, p_g);
		$sformat(path, "%0s/prom_b.hex", dir);  $readmemh(path, p_b);
		#100000 reset_n = 1'b1;
		wait (fcount == 3);
		wait (!vblank);						// capture buffer holds the complete third frame
		wait (vblank);
		fo = $fopen(outname, "w");
		for (i = 0; i < 240 * 224; i = i + 1) $fwrite(fo, "%06x\n", frame[i]);
		$fclose(fo);
		$display("frame written; sprite engine overruns=%0d, peak busy clk/line=%0d (budget %0d)", overruns, busy_peak, 316 * 16);
		$finish;
	end
endmodule
