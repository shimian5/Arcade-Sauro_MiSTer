// SPDX-License-Identifier: GPL-3.0-or-later
//
// Tecfri CRT position adjust (H-Position, V-Shift), core-side, analog/CRT stage only.
//
// Provenance: adapted from Arcade-Victory_MiSTer rtl/video/victory_crt_position.sv
// (HEAD 987bd51db0b07e95377ee1a68d1acbfc0ec934aa, Oct 5 2026 copy). Changes from the
// Victory original: raster parameters (HTOTAL/VTOTAL/HSYNC_COL) replace the hard-coded
// 336x280 Victory raster; the 15 kHz mode switch is removed (Tecfri has one 316x284
// raster); the unused H-Size line-buffer engine (crt_adjust_sys.sv) is not instantiated.
// The VSync/HSync learning logic and the whole-line/whole-pixel shift method are unchanged.
//
// Behaviour: RGB, CE and blanking pass through unchanged. Only HSync and VSync are
// delayed, and only while enabled (OSD CRT Adjust = On, scandoubler off). The delay is
// learned from the observed normalized HSync/VSync edges, so settings change only at a
// VSync edge and never inside active pixels. Because this stage sits on the same VGA
// outputs the HDMI scaler taps, HDMI follows the moved sync when the adjust is On
// (accepted by the project owner); with the adjust Off the sync pass-through is exact.
//
// Clock: clk is the arcade_video CLK_VIDEO domain; ce_pix is the mixer output CE_PIXEL.
// vb_in must be the true core vertical blank (not the combined DE blank).
module tecfri_crt_position #(
	// Raster of the arcade_video output stream, in pixel clock enables per line/frame.
	parameter HTOTAL   = 316,
	parameter VTOTAL   = 284,
	// Column at which the observed HSync rises; the column counter is re-synced to it.
	parameter HSYNC_COL = 252
) (
	input  wire       clk, ce_pix, enabled, scandoubler,
	input  wire signed [5:0] hposition,
	input  wire signed [4:0] vshift,
	input  wire [23:0] rgb_in,
	input  wire       hs_in, vs_in, hb_in, vb_in,
	output wire [23:0] rgb_out,
	output wire       ce_out, hs_out, vs_out, hb_out, vb_out
);
reg enabled_q=0, hs_previous=0, vs_previous=0;
reg signed [5:0] hposition_q=0;
reg signed [4:0] vshift_q=0;
reg [8:0] next_column=0, history_lines=0;
reg [8:0] vertical_phase=0;
reg [HTOTAL-1:0] hs_history=0;
reg [VTOTAL-1:0] vs_history=0;
reg shifted_hs=0, shifted_vs=0;
wire hs_rise=hs_in && !hs_previous;
wire vs_rise=vs_in && !vs_previous;
wire [8:0] column=hs_rise ? 9'(HSYNC_COL) : next_column;
wire [8:0] vertical_sample=vertical_phase;
// Delay in pixels: positive hposition delays HSync (moves picture right); negative values
// wrap through the previous line (HTOTAL + N tap), as in Victory.
wire [8:0] hdelay=hposition_q[5] ? 9'(HTOTAL+int'(hposition_q)) : {3'd0,hposition_q};
// Delay in lines for VSync, same wrap rule with VTOTAL.
wire [8:0] vdelay=vshift_q[4] ? 9'(VTOTAL+int'(vshift_q)) : {4'd0,vshift_q};
always @(posedge clk) if(ce_pix) begin
	hs_previous<=hs_in; vs_previous<=vs_in;
	next_column<=column==(HTOTAL-1) ? 9'd0 : column+9'd1;
	hs_history<={hs_history[HTOTAL-2:0],hs_in};
	shifted_hs<=hdelay==0 ? hs_in : hs_history[hdelay-9'd1];
	if(column==vertical_sample) begin
		vs_history<={vs_history[VTOTAL-2:0],vs_in};
		shifted_vs<=vdelay==0 ? vs_in : vs_history[vdelay-9'd1];
		if(history_lines<VTOTAL) history_lines<=history_lines+9'd1;
	end
	// The actual VSync edge lies in blank; settings cannot change an active pixel.
	if(vs_rise) begin
		enabled_q<=enabled;
		hposition_q<=hposition; vshift_q<=vshift;
		if(vertical_phase!=column) begin
			// Discard history taken at a different line phase. Sampling hereafter at the
			// observed edge gives exact whole-line shifts.
			vertical_phase<=column; history_lines<=0;
			vs_history<=0; shifted_vs<=0;
		end
	end
end
wire active=enabled_q && !scandoubler && history_lines==VTOTAL;
assign rgb_out=rgb_in;
assign ce_out=ce_pix;
assign {hb_out,vb_out}={hb_in,vb_in};
assign hs_out=active && hposition_q!=0 ? shifted_hs : hs_in;
assign vs_out=active && vshift_q!=0 ? shifted_vs : vs_in;
endmodule
