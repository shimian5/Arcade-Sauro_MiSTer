// Tecfri machine core: everything except the MiSTer framework (PLL, hps_io, video output).
// Keeping this boundary lets Verilator drive the ROM download interface and execute the
// original ROMs from reset (sim/tb_core.sv).
//
// ROM download layout (ioctl index 0), assembled by the MRA files (tools/make_mra.py):
//   00000-0FFFF main CPU program        10000-17FFF audio CPU program (Sauro family)
//   18000-27FFF bg tiles                28000-37FFF fg tiles (Sauro family)
//   38000-57FFF sprites (Tricky Doc: 64 KB)
//   58000-583FF red PROM   58400-587FF green PROM   58800-58BFF blue PROM
//   58C00-593FF SP0256 internal ROM
// ioctl index 1 carries one byte: bit 0 = Tricky Doc board, 0 = Sauro family board.
//
// Clocks (clk = 80 MHz): one 5 MHz enable (1/16) drives the main CPU and the pixel clock.
// the audio side derives 4 MHz (1/20) and 2.5 MHz (1/32) enables from the same clock.
// MAME's CPU clock plan is used; the second crystal on the Sauro board (marked 8...) is not
// yet understood and is not modelled.
module tecfri_core #(
	// PROVISIONAL sync placement (unmeasured; see docs/PIXEL_TIMING.md)
	parameter int H_SYNC_START = 252,
	parameter int H_SYNC_END   = 276,
	parameter int V_SYNC_START = 236,
	parameter int V_SYNC_END   = 239
)(
	input  logic        clk,
	input  logic        reset,          // machine reset (user reset); video timing keeps running
	input  logic        pause,          // freezes the CPUs, video continues

	input  logic        ioctl_download,
	input  logic        ioctl_wr,
	input  logic [15:0] ioctl_index,
	input  logic [24:0] ioctl_addr,
	input  logic [7:0]  ioctl_data,

	input  logic [7:0]  dsw1,
	input  logic [7:0]  dsw2,
	input  logic [7:0]  p1,
	input  logic [7:0]  p2,

	output logic        ce_pix,
	output logic [7:0]  vid_r,
	output logic [7:0]  vid_g,
	output logic [7:0]  vid_b,
	output logic        hblank,
	output logic        vblank,
	output logic        hsync,
	output logic        vsync,
	output logic [8:0]  pix_x,
	output logic [8:0]  pix_y,
	output logic        rom_ready,   // a complete ROM download has been received
	output logic signed [15:0] audio,   // mono mix, signed; muted while paused

	// Observation for tests
	output logic signed [15:0] dbg_ym,
	output logic signed [15:0] dbg_speech,
	output logic        dbg_ym_wr,
	output logic        dbg_ym_a0,
	output logic [7:0]  dbg_ym_d,
	output logic        dbg_ald_wr,
	output logic [7:0]  dbg_ald_d,
	output logic        dbg_cmd_rd,
	output logic        dbg_int_ack,
	output logic        dbg_bus_wr,
	output logic        dbg_bus_io,
	output logic [15:0] dbg_bus_a,
	output logic [7:0]  dbg_bus_d
);

	// ------------------------------------------------------------ download and variant
	wire dl_rom = ioctl_download && ioctl_index == 16'd0;
	wire dl_we  = dl_rom && ioctl_wr;

	logic tricky = 1'b0;
	always_ff @(posedge clk)
		if (ioctl_download && ioctl_index == 16'd1 && ioctl_wr) tricky <= ioctl_data[0];

	// rom_ready rises when a complete index-0 download has finished.
	logic dl_seen = 1'b0;
	always_ff @(posedge clk) begin
		if (dl_we) dl_seen <= 1'b1;
		if (!ioctl_download && dl_seen) rom_ready <= 1'b1;
		if (dl_rom) rom_ready <= 1'b0;
	end

	wire machine_reset_n = !(reset || !rom_ready || ioctl_download);

	// Free-running video timing reset only at power-up, so sync continues through user resets.
	logic [3:0] por_cnt = 4'd0;
	always_ff @(posedge clk) if (por_cnt != 4'hF) por_cnt <= por_cnt + 4'd1;
	wire por_n = (por_cnt == 4'hF);

	// ------------------------------------------------------------ clock enables
	logic [3:0] phase = 4'd0;
	always_ff @(posedge clk) phase <= phase + 4'd1;
	wire pix_cen = (phase == 4'd0);
	wire cpu_cen = pix_cen && !pause;
	assign ce_pix = pix_cen;

	// ------------------------------------------------------------ ROM storage (M10K)
	wire [24:0] a = ioctl_addr;
	wire we_main = dl_we && a < 25'h10000;
	wire we_audio = dl_we && a >= 25'h10000 && a < 25'h18000;
	wire we_bg   = dl_we && a >= 25'h18000 && a < 25'h28000;
	wire we_fg   = dl_we && a >= 25'h28000 && a < 25'h38000;
	wire we_spr  = dl_we && a >= 25'h38000 && a < 25'h58000;
	wire we_pr   = dl_we && a >= 25'h58000 && a < 25'h58400;
	wire we_pg   = dl_we && a >= 25'h58400 && a < 25'h58800;
	wire we_pb   = dl_we && a >= 25'h58800 && a < 25'h58C00;

	logic [15:0] rom_addr;
	logic [7:0]  rom_data;
	tecfri_rom #(16) main_rom (.clk(clk), .we(we_main), .wa(a[15:0]), .wd(ioctl_data), .ra(rom_addr), .q(rom_data));

	logic [15:0] bg_a, fg_a;
	logic [16:0] spr_a;
	logic [7:0]  bg_q, fg_q, spr_q;
	wire  [15:0] bg_wa = a[15:0] - 16'h8000;                         // 18000 -> 0
	wire  [15:0] fg_wa = a[15:0] - 16'h8000;                         // 28000 -> 0
	tecfri_rom #(16) bg_rom  (.clk(clk), .we(we_bg), .wa(bg_wa), .wd(ioctl_data), .ra(bg_a),  .q(bg_q));
	tecfri_rom #(16) fg_rom  (.clk(clk), .we(we_fg),  .wa(fg_wa), .wd(ioctl_data), .ra(fg_a),  .q(fg_q));
	tecfri_rom #(17) spr_rom (.clk(clk), .we(we_spr), .wa(a[16:0] - 17'h18000), .wd(ioctl_data), .ra(spr_a), .q(spr_q));

	logic [9:0] pal_a;
	logic [7:0] pal_rq, pal_gq, pal_bq;
	tecfri_rom #(10) prom_r (.clk(clk), .we(we_pr), .wa(a[9:0]), .wd(ioctl_data), .ra(pal_a), .q(pal_rq));
	tecfri_rom #(10) prom_g (.clk(clk), .we(we_pg), .wa(a[9:0]), .wd(ioctl_data), .ra(pal_a), .q(pal_gq));
	tecfri_rom #(10) prom_b (.clk(clk), .we(we_pb), .wa(a[9:0]), .wd(ioctl_data), .ra(pal_a), .q(pal_bq));

	// ------------------------------------------------------------ timing, machine, video
	logic [8:0] hcnt, vcnt;
	logic       vblank_start, hb_unused, vb_unused;
	tecfri_timing timing (.clk(clk), .reset_n(por_n), .pix_cen(pix_cen), .hcnt(hcnt), .vcnt(vcnt),
		.hblank(hb_unused), .vblank(vb_unused), .vblank_start(vblank_start));

	logic [9:0] vid_bg_a, vid_fg_a, vid_spr_a;
	logic [7:0] vid_bgv_d, vid_bgc_d, vid_fgv_d, vid_fgc_d, vid_spr_d;
	logic       flip;
	logic [1:0] palette_bank, coin_counter;
	logic [7:0] scroll_bg, scroll_fg;
	logic       snd_cmd_wr, ym_wr, ym_a0, wd_kick;
	logic [7:0] snd_cmd, ym_d;

	tecfri_main main (
		.clk(clk), .reset_n(machine_reset_n), .cen_cpu(cpu_cen), .tricky(tricky), .vblank_start(vblank_start),
		.dsw1(dsw1), .dsw2(dsw2), .p1(p1), .p2(p2),
		.rom_addr(rom_addr), .rom_data(rom_data),
		.vid_bg_a(vid_bg_a), .vid_fg_a(vid_fg_a), .vid_spr_a(vid_spr_a),
		.vid_bgv_d(vid_bgv_d), .vid_bgc_d(vid_bgc_d), .vid_fgv_d(vid_fgv_d), .vid_fgc_d(vid_fgc_d), .vid_spr_d(vid_spr_d),
		.flip(flip), .palette_bank(palette_bank), .scroll_bg(scroll_bg), .scroll_fg(scroll_fg),
		.coin_counter(coin_counter), .snd_cmd_wr(snd_cmd_wr), .snd_cmd(snd_cmd),
		.ym_wr(ym_wr), .ym_a0(ym_a0), .ym_d(ym_d), .wd_kick(wd_kick), .int_ack(dbg_int_ack),
		.bus_wr(dbg_bus_wr), .bus_io(dbg_bus_io), .bus_a(dbg_bus_a), .bus_d(dbg_bus_d));

	logic       out_de;
	logic [8:0] out_x, out_y;
	tecfri_video video (
		.clk(clk), .reset_n(por_n), .pix_cen(pix_cen), .hcnt(hcnt), .vcnt(vcnt), .tricky(tricky),
		.palette_bank(palette_bank), .scroll_bg(scroll_bg), .scroll_fg_raw(scroll_fg),
		.vid_bg_a(vid_bg_a), .vid_fg_a(vid_fg_a), .vid_spr_a(vid_spr_a),
		.vid_bgv_d(vid_bgv_d), .vid_bgc_d(vid_bgc_d), .vid_fgv_d(vid_fgv_d), .vid_fgc_d(vid_fgc_d), .vid_spr_d(vid_spr_d),
		.bg_rom_a(bg_a), .bg_rom_d(bg_q), .fg_rom_a(fg_a), .fg_rom_d(fg_q),
		.spr_rom_a(spr_a), .spr_rom_d(spr_q),
		.pal_a(pal_a), .pal_r(pal_rq[3:0]), .pal_g(pal_gq[3:0]), .pal_b(pal_bq[3:0]),
		.out_r(vid_r), .out_g(vid_g), .out_b(vid_b), .out_de(out_de), .out_x(out_x), .out_y(out_y));

	// ------------------------------------------------------------ sound
	tecfri_audio audio_sys (
		.clk(clk), .reset_n(machine_reset_n), .pause(pause), .tricky(tricky),
		.rom_we(we_audio), .rom_wa(a[14:0]), .rom_wd(ioctl_data),
		.snd_cmd_wr(snd_cmd_wr), .snd_cmd(snd_cmd),
		.main_ym_wr(ym_wr), .main_ym_a0(ym_a0), .main_ym_d(ym_d),
		.ym_out(dbg_ym), .speech_out(dbg_speech), .mix_out(audio),
		.dbg_ym_wr(dbg_ym_wr), .dbg_ym_a0(dbg_ym_a0), .dbg_ym_d(dbg_ym_d),
		.dbg_ald_wr(dbg_ald_wr), .dbg_ald_d(dbg_ald_d), .dbg_cmd_rd(dbg_cmd_rd));

	// Blanking and sync are derived from the registered pixel coordinates, so they stay aligned
	// with the RGB output. Sync placement is provisional.
	assign pix_x  = out_x;
	assign pix_y  = out_y;
	assign hblank = (out_x >= 9'd240);
	assign vblank = (out_y >= 9'd224);
	assign hsync  = (out_x >= H_SYNC_START) && (out_x < H_SYNC_END);
	assign vsync  = (out_y >= V_SYNC_START) && (out_y < V_SYNC_END);

endmodule
