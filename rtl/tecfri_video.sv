// Tecfri video generator (Sauro / Sea Wolf and Tricky Doc), MAME-derived.
//
// Behavior is defined by MAME's sauro.cpp rules, validated for attract-mode frames by
// tools/video_ref.py (docs/MAME_FINDINGS.md F7). The real PCB's sprite engine and its
// timing are NOT known; the structure below (per-pixel tile fetch, per-line sprite
// scan into a double-buffered line buffer) is this core's own design, not a model of the
// original hardware.
//
// Requirements: clk must be at least 8x pix_cen. Tile and palette lookups are
// combinational/registered chains of about 5 clk that settle inside one pixel period; the
// sprite scan needs roughly 255 x 9 clk per line plus about 28 clk per sprite on the line.
// Sprites beyond what fits in one line time are dropped (no MAME equivalent); this limit
// has not been measured against real game content.
//
// Pixel pipeline: coordinates latched at pix_cen, RGB registered at the next pix_cen
// (one pixel of latency; out_x/out_y/out_de describe the registered pixel).
//
// Not implemented: flip screen (cocktail). The flip input is ignored.
//
// Memory interfaces are synchronous with one clk of read latency; gfx ROM and PROM storage
// is supplied by the caller.
module tecfri_video #(
	parameter int H_ACTIVE = 240,
	parameter int V_ACTIVE = 224,
	parameter int V_TOTAL  = 284
)(
	input  logic        clk,
	input  logic        reset_n,
	input  logic        pix_cen,
	input  logic [8:0]  hcnt,
	input  logic [8:0]  vcnt,
	input  logic        tricky,
	input  logic [1:0]  palette_bank,   // Sauro latch Q5/Q6 (adds 0x10/0x20 to the colour)
	input  logic [7:0]  scroll_bg,
	input  logic [7:0]  scroll_fg_raw,  // raw port value; the bit permutation is applied here

	// Video RAM read ports (to tecfri_main)
	output logic [9:0]  vid_bg_a,
	output logic [9:0]  vid_fg_a,
	output logic [9:0]  vid_spr_a,
	input  logic [7:0]  vid_bgv_d,
	input  logic [7:0]  vid_bgc_d,
	input  logic [7:0]  vid_fgv_d,
	input  logic [7:0]  vid_fgc_d,
	input  logic [7:0]  vid_spr_d,

	// Graphics ROMs (1 clk latency)
	output logic [15:0] bg_rom_a,
	input  logic [7:0]  bg_rom_d,
	output logic [15:0] fg_rom_a,
	input  logic [7:0]  fg_rom_d,
	output logic [16:0] spr_rom_a,
	input  logic [7:0]  spr_rom_d,

	// Colour PROMs: 10-bit pen, three 4-bit outputs (1 clk latency)
	output logic [9:0]  pal_a,
	input  logic [3:0]  pal_r,
	input  logic [3:0]  pal_g,
	input  logic [3:0]  pal_b,

	output logic [7:0]  out_r,
	output logic [7:0]  out_g,
	output logic [7:0]  out_b,
	output logic        out_de,
	output logic [8:0]  out_x,
	output logic [8:0]  out_y
);

	// ------------------------------------------------------------ pixel coordinates
	logic [8:0] cx, cy;
	always_ff @(posedge clk) if (pix_cen) begin
		cx <= hcnt;
		cy <= vcnt;
	end

	wire [7:0] bx = cx[7:0] + 8'd8;     // MAME bitmap coordinates: visible area starts at (8,16)
	wire [7:0] by = cy[7:0] + 8'd16;

	// fg scroll: low three bits are permuted by the board (MAME scroll2_map)
	logic [2:0] fg_perm;
	always_comb begin
		case (scroll_fg_raw[2:0])
			3'd0:    fg_perm = 3'd2;
			3'd1:    fg_perm = 3'd1;
			3'd2:    fg_perm = 3'd4;
			3'd3:    fg_perm = 3'd3;
			3'd4:    fg_perm = 3'd6;
			3'd5:    fg_perm = 3'd5;
			3'd6:    fg_perm = 3'd0;
			default: fg_perm = 3'd7;
		endcase
	end
	wire [7:0] fg_scroll = {scroll_fg_raw[7:3], fg_perm};

	// ------------------------------------------------------------ tile layers
	// Column-major 32x32 map: index = column * 32 + row. Attribute: [7:4] colour, [3] flip x,
	// [2:0] code bits 10:8.
	wire [7:0] bg_sx = bx + scroll_bg;
	wire [7:0] fg_sx = bx + fg_scroll;
	assign vid_bg_a = {bg_sx[7:3], by[7:3]};
	assign vid_fg_a = {fg_sx[7:3], by[7:3]};

	wire [2:0] bg_tx = vid_bgc_d[3] ? ~bg_sx[2:0] : bg_sx[2:0];
	wire [2:0] fg_tx = vid_fgc_d[3] ? ~fg_sx[2:0] : fg_sx[2:0];
	assign bg_rom_a = {vid_bgc_d[2:0], vid_bgv_d, by[2:0], bg_tx[2:1]};
	assign fg_rom_a = {vid_fgc_d[2:0], vid_fgv_d, by[2:0], fg_tx[2:1]};

	// Pixel nibble: high nibble first. The ROM data is valid one clk after the address,
	// which itself depends on the RAM data, so tx is re-derived from the same registered
	// attribute bits that formed the address.
	logic [2:0] bg_tx_q, fg_tx_q;
	logic [3:0] bg_col_q, fg_col_q;
	always_ff @(posedge clk) begin
		bg_tx_q  <= bg_tx;
		fg_tx_q  <= fg_tx;
		bg_col_q <= vid_bgc_d[7:4];
		fg_col_q <= vid_fgc_d[7:4];
	end
	wire [3:0] bg_pix = bg_tx_q[0] ? bg_rom_d[3:0] : bg_rom_d[7:4];
	wire [3:0] fg_pix = fg_tx_q[0] ? fg_rom_d[3:0] : fg_rom_d[7:4];

	wire [5:0] bank6   = tricky ? 6'd0 : {palette_bank[1:0], 4'd0};
	wire [5:0] bg_col6 = {2'b00, bg_col_q} | bank6;
	wire [5:0] fg_col6 = {2'b00, fg_col_q} | bank6;

	// ------------------------------------------------------------ sprite line buffers
	logic [9:0] lb0 [0:255];
	logic [9:0] lb1 [0:255];
	logic       buf_sel;                // buffer the engine writes; the other one is displayed
	logic       lb_we;
	logic [7:0] lb_wa;
	logic [9:0] lb_wd;
	logic [9:0] lb_q0, lb_q1;

	always_ff @(posedge clk) begin
		if (lb_we && buf_sel == 1'b0) lb0[lb_wa] <= lb_wd;
		lb_q0 <= lb0[bx];
		if (lb_we && buf_sel == 1'b1) lb1[lb_wa] <= lb_wd;
		lb_q1 <= lb1[bx];
	end
	wire [9:0] spr_pen = buf_sel ? lb_q0 : lb_q1;   // displayed = not the one being written

	// ------------------------------------------------------------ sprite engine
	logic [8:0] hcnt_q;
	always_ff @(posedge clk) hcnt_q <= hcnt;
	wire line_start = (hcnt == 9'd0) && (hcnt_q != 9'd0);

	typedef enum logic [3:0] {
		E_IDLE, E_CLEAR, E_F0, E_F1, E_F2, E_F3, E_F4, E_EVAL, E_RA, E_RB, E_RC
	} eng_t;
	eng_t       eng;
	logic [8:0] clr;
	logic [7:0] si;                     // sprite index 0..254
	logic [7:0] b0, b1, b2, b3;
	logic [8:0] ny;                     // bitmap line the engine is building
	logic       ny_valid;
	logic [9:0] s_code;
	logic [5:0] s_color;
	logic signed [10:0] s_sx;
	logic       s_flipx;
	logic [3:0] s_row;
	logic [2:0] k;

	wire [9:0] offs = {si, 2'b00} + 10'd3;
	always_comb begin
		case (eng)
			E_F0:    vid_spr_a = offs;
			E_F1:    vid_spr_a = offs + 10'd1;
			E_F2:    vid_spr_a = offs + 10'd2;
			E_F3:    vid_spr_a = offs + 10'd3;
			default: vid_spr_a = offs;
		endcase
	end

	// Sprite entry decode (b0 = y, b1 = code low, b2 = x, b3 = attribute).
	logic signed [10:0] d_sy, d_sx;
	logic [9:0]  d_code;
	logic [5:0]  d_color;
	logic        d_ext, d_flipx, d_flipy, d_skip;
	logic signed [10:0] d_row;
	always_comb begin
		d_skip = 1'b0;
		d_sy   = 11'sd236 - $signed({3'b000, b0});
		if (tricky) begin
			d_code  = {1'b0, b3[0], b1};
			d_sx    = $signed({3'b000, b2}) - 11'sd2;
			d_color = {2'b00, b3[7:4]};
			d_ext   = b3[1];
			d_flipx = b3[2];
			d_flipy = b3[3];             // MAME 0.288; 0.257 used y += 6 here (unresolved)
		end else begin
			d_code  = {b3[1:0], b1};
			d_sx    = $signed({3'b000, b2});
			d_color = {palette_bank, b3[7:4]};
			d_ext   = b3[3];
			d_flipx = b3[2];
			d_flipy = 1'b0;
			if (b0 == 8'hF8) d_skip = 1'b1;
		end
		if (d_ext) begin
			if (d_sx > 11'sd192 && d_sx < 11'sd256) d_sx = d_sx - 11'sd256;   // int8 sign extension
		end else begin
			if (d_sx < 11'sd64) d_skip = 1'b1;
		end
		d_row = $signed({2'b00, ny}) - d_sy;
	end
	wire d_hit = !d_skip && ny_valid && (d_row >= 11'sd0) && (d_row < 11'sd16);
	wire [3:0] d_r = d_flipy ? (4'd15 - d_row[3:0]) : d_row[3:0];

	// Sprite ROM address: row r lives in quarter (3 - r%4), code*32 + (r/4)*8 + byte.
	wire [1:0] quarter = 2'd3 - s_row[1:0];
	assign spr_rom_a = tricky ? {1'b0, quarter, s_code[8:0], s_row[3:2], k}
	                          : {quarter, s_code, s_row[3:2], k};

	// Byte k holds pixels 2k (low nibble) and 2k+1 (high nibble) of the unflipped sprite.
	logic        wr_hi;
	wire  [3:0]  nib      = wr_hi ? spr_rom_d[7:4] : spr_rom_d[3:0];
	wire  [4:0]  xs       = {1'b0, k, wr_hi};
	wire signed [10:0] px = s_flipx ? s_sx + 11'sd15 - $signed({6'b0, xs}) : s_sx + $signed({6'b0, xs});

	always_ff @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			eng      <= E_IDLE;
			buf_sel  <= 1'b0;
			lb_we    <= 1'b0;
			ny_valid <= 1'b0;
		end else begin
			lb_we <= 1'b0;
			if (line_start) begin
				buf_sel  <= ~buf_sel;
				ny       <= ((vcnt == V_TOTAL - 1) ? 9'd0 : vcnt + 9'd1) + 9'd16;
				ny_valid <= ((vcnt == V_TOTAL - 1) ? 9'd0 : vcnt + 9'd1) < V_ACTIVE;
				clr      <= 9'd0;
				si       <= 8'd0;
				eng      <= E_CLEAR;
			end else begin
				case (eng)
					E_CLEAR: begin
						lb_we <= 1'b1;
						lb_wa <= clr[7:0];
						lb_wd <= 10'd0;
						clr   <= clr + 9'd1;
						if (clr == 9'd255) eng <= ny_valid ? E_F0 : E_IDLE;
					end
					E_F0: eng <= E_F1;
					E_F1: begin b0 <= vid_spr_d; eng <= E_F2; end
					E_F2: begin b1 <= vid_spr_d; eng <= E_F3; end
					E_F3: begin b2 <= vid_spr_d; eng <= E_F4; end
					E_F4: begin b3 <= vid_spr_d; eng <= E_EVAL; end
					E_EVAL: begin
						if (d_hit) begin
							s_code  <= d_code;
							s_color <= d_color;
							s_sx    <= d_sx;
							s_flipx <= d_flipx;
							s_row   <= d_r;
							k       <= 3'd0;
							wr_hi   <= 1'b0;
							eng     <= E_RA;
						end else if (si == 8'd254) begin
							eng <= E_IDLE;
						end else begin
							si  <= si + 8'd1;
							eng <= E_F0;
						end
					end
					E_RA: eng <= E_RB;      // ROM address presented; data valid next clk
					E_RB: begin             // low nibble (pixel 2k)
						if (nib != 4'd0 && px >= 11'sd0 && px < 11'sd256) begin
							lb_we <= 1'b1;
							lb_wa <= px[7:0];
							lb_wd <= {s_color, nib};
						end
						wr_hi <= 1'b1;
						eng   <= E_RC;
					end
					E_RC: begin             // high nibble (pixel 2k+1)
						if (nib != 4'd0 && px >= 11'sd0 && px < 11'sd256) begin
							lb_we <= 1'b1;
							lb_wa <= px[7:0];
							lb_wd <= {s_color, nib};
						end
						wr_hi <= 1'b0;
						if (k == 3'd7) begin
							if (si == 8'd254) eng <= E_IDLE;
							else begin si <= si + 8'd1; eng <= E_F0; end
						end else begin
							k   <= k + 3'd1;
							eng <= E_RA;
						end
					end
					default: ;
				endcase
			end
		end
	end

	// ------------------------------------------------------------ compose, palette, DAC
	wire [9:0] pen = (spr_pen != 10'd0) ? spr_pen
	               : (!tricky && fg_pix != 4'd0) ? {fg_col6, fg_pix}
	               : {bg_col6, bg_pix};
	assign pal_a = pen;

	// MAME 0.288 resistor-weighted levels; the real board's network is not known.
	function automatic [7:0] dac(input [3:0] n);
		dac = (n[0] ? 8'd14 : 8'd0) + (n[1] ? 8'd31 : 8'd0) + (n[2] ? 8'd67 : 8'd0) + (n[3] ? 8'd143 : 8'd0);
	endfunction

	always_ff @(posedge clk) if (pix_cen) begin
		out_r  <= dac(pal_r);
		out_g  <= dac(pal_g);
		out_b  <= dac(pal_b);
		out_x  <= cx;
		out_y  <= cy;
		out_de <= (cx < H_ACTIVE) && (cy < V_ACTIVE);
	end

endmodule
