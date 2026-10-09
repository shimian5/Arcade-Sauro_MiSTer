//============================================================================
//
//  Sauro arcade core for MiSTer (Tecfri Sauro-family hardware): Sauro, Sea Wolf (Tecfri), Tricky Doc
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

wire signed [15:0] core_audio;
assign AUDIO_S = 1;     // signed samples
assign AUDIO_L = core_audio;
assign AUDIO_R = core_audio;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v"
localparam CONF_STR = {
	"Sauro;;",
	"-;",
	"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O[3:1],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"DIP;",
	"-;",
	"O[4],Pause when OSD is open,On,Off;",
	"O[5],Dim video after 10s,On,Off;",
	"-;",
	"O[6],Speech (Sauro),On,Off;",
	"O[7],Sound test tone,Off,On;",
	"O[11:8],Debug tone,Off,ROM loaded,CPU running,YM written,YM IRQ,Cmd read,Cmd sent,YM audible,Main loop,INT vector,NMI vector,Wild fetch,YM timer2 start;",
	"-;",
	// CRT Adjust is analog/CRT only (core-side, Victory structure): it moves the sync on the
	// VGA outputs, so the HDMI scaler follows it while On. Off = unchanged output.
	"D1O[101],CRT Adjust,Off,On;",
	"H0O[85:80],CRT H-Position,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,+16,+17,+18,+19,+20,+21,+22,+23,+24,+25,+26,+27,+28,+29,+30,+31,-32,-31,-30,-29,-28,-27,-26,-25,-24,-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H0O[78:74],CRT V-Shift,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"-;",
	"R[0],Reset and close OSD;",
	// Button names map to joystick bits 4 and up; keep in step with the MRA button defaults.
	"J1,Button 1,Button 2,Start 1P,Start 2P,Coin,Pause;",
	"jn,A,B,Start,Select,R,L;",
	"v,0;",
	"V,v",`BUILD_DATE
};

wire        forced_scandoubler;
wire  [1:0] buttons;
wire [127:0] status;

// CRT position menu gating (hps_io status_menumask, concatenation is {bit 1, bit 0}): bit 0 hides H-Position/V-Shift (H0)
// unless CRT Adjust is On; bit 1 disables CRT Adjust (D1) while a scandoubler mode is active.
wire       crt_scandoubler = forced_scandoubler || (status[3:1] != 0);
wire [15:0] status_menumask = {14'd0, crt_scandoubler, (!status[101] || crt_scandoubler)};
wire [21:0] gamma_bus;
wire [31:0] joystick_0, joystick_1;
wire        ioctl_download, ioctl_wr, ioctl_upload, ioctl_rd;
wire        nv_save_request, nv_transfer;
wire  [7:0] nv_data;
wire [15:0] ioctl_index;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(gamma_bus),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask(status_menumask),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	// battery RAM save/restore: standard upload request, image index 4 (see rtl/sauro_nvram.sv)
	.ioctl_upload(ioctl_upload),
	.ioctl_rd(ioctl_rd),
	.ioctl_din(nv_data),
	.ioctl_upload_req(nv_save_request),
	.ioctl_upload_index(8'd4)
);

///////////////////////   CLOCKS   ///////////////////////////////

// 80 MHz system clock: one enable per 16 clocks gives the 5 MHz CPU and pixel clock; 4 MHz
// (1/20) and 2.5 MHz (1/32) enables for the audio side are integer divisions as well.
// The instance must stay named "pll": sys/sys_top.sdc matches *|pll|pll_inst|... clocks.
wire clk_sys, pll_locked;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.locked(pll_locked)
);

wire reset = RESET | status[0] | buttons[1] | !pll_locked;

///////////////////////   INPUTS / DIP   ///////////////////////////

// DIP switches arrive from the MRA (ioctl index 254). Defaults are MAME's.
reg [7:0] sw [0:7];
initial begin
	sw[0] = 8'h66;
	sw[1] = 8'h2F;
end
always @(posedge clk_sys)
	if (ioctl_wr && ioctl_index == 16'd254 && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

// MiSTer joystick bits: 0 right, 1 left, 2 down, 3 up, then the J1 buttons from bit 4:
// 4 Button 1, 5 Button 2, 6 Start 1P, 7 Start 2P, 8 Coin, 9 Pause.
// Tecfri input bytes are active high. P1: B1 B2 COIN1 COIN2 LEFT RIGHT UP DOWN (bit 0..7).
// P2: B1 B2 START1 START2 LEFT RIGHT UP DOWN (cocktail second-player controls).
wire coin1  = joystick_0[8];
wire coin2  = joystick_1[8];
wire start1 = joystick_0[6] | joystick_1[6];
wire start2 = joystick_0[7] | joystick_1[7];
wire [7:0] p1 = { joystick_0[2], joystick_0[3], joystick_0[0], joystick_0[1], coin2, coin1, joystick_0[5], joystick_0[4] };
wire [7:0] p2 = { joystick_1[2], joystick_1[3], joystick_1[0], joystick_1[1], start2, start1, joystick_1[5], joystick_1[4] };
wire pause_button = joystick_0[9] | joystick_1[9];

///////////////////////   MACHINE   ////////////////////////////////

wire        ce_pix;
wire  [7:0] core_r, core_g, core_b;
wire        core_hblank, core_vblank, core_hsync, core_vsync;
wire        pause_cpu;

sauro_core core
(
	.clk(clk_sys),
	.reset(reset),
	.pause(pause_cpu),
	.speech_mute(status[6]),
	.tone_en(status[7]),
	.dbg_sel(status[11:8]),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_rd(ioctl_rd),
	.ioctl_wr(ioctl_wr),
	.ioctl_index(ioctl_index),
	.ioctl_addr(ioctl_addr),
	.ioctl_data(ioctl_dout),

	.dsw1(sw[0]),
	.dsw2(sw[1]),
	.p1(p1),
	.p2(p2),

	.ce_pix(ce_pix),
	.vid_r(core_r),
	.vid_g(core_g),
	.vid_b(core_b),
	.hblank(core_hblank),
	.vblank(core_vblank),
	.hsync(core_hsync),
	.vsync(core_vsync),
	.pix_x(),
	.pix_y(),
	.rom_ready(),
	.audio(core_audio),
	.nv_data(nv_data),
	.nv_save_request(nv_save_request),
	.nv_transfer(nv_transfer),

	.dbg_ym(), .dbg_speech(), .dbg_ym_wr(), .dbg_ym_a0(), .dbg_ym_d(),
	.dbg_ald_wr(), .dbg_ald_d(), .dbg_cmd_rd(),
	.dbg_int_ack(),
	.dbg_bus_wr(),
	.dbg_bus_io(),
	.dbg_bus_a(),
	.dbg_bus_d()
);

// Pause: freezes the CPUs while video keeps running, dims after 10 s (optional), and can follow
// the OSD. The framework module is unmodified; see rtl/pause.sv.
wire [7:0] pause_r, pause_g, pause_b;
pause #(.CLKSPD(80)) pause_control
(
	.clk_sys(clk_sys),
	.reset(reset),
	.user_button(pause_button),
	.pause_request(1'b0),
	.options({!status[5], !status[4]}),
	.OSD_STATUS(OSD_STATUS),
	.r(core_r), .g(core_g), .b(core_b),
	.pause_cpu(pause_cpu),
	.r_out(pause_r), .g_out(pause_g), .b_out(pause_b)
);

///////////////////////   VIDEO   //////////////////////////////////

// arcade_video drives internal mixer wires; the CRT position stage below drives the VGA outputs.
wire        mixer_ce, mixer_hs, mixer_vs, mixer_de;
wire  [7:0] mixer_r, mixer_g, mixer_b;

arcade_video #(.WIDTH(256), .DW(24)) arcade_video
(
	.clk_video(clk_sys),
	.ce_pix(ce_pix),
	.RGB_in({pause_r, pause_g, pause_b}),
	.HBlank(core_hblank),
	.VBlank(core_vblank),
	.HSync(core_hsync),
	.VSync(core_vsync),

	.CLK_VIDEO(CLK_VIDEO),
	.CE_PIXEL(mixer_ce),
	.VGA_R(mixer_r),
	.VGA_G(mixer_g),
	.VGA_B(mixer_b),
	.VGA_HS(mixer_hs),
	.VGA_VS(mixer_vs),
	.VGA_DE(mixer_de),
	.VGA_SL(VGA_SL),

	.fx(status[3:1]),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus)
);

// CRT position controls are slow OSD settings: synchronize them into the CLK_VIDEO domain.
// Packed: [12] scandoubler (CRT path off), [11] CRT Adjust, [10:5] H-Position, [4:0] V-Shift.
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [12:0] crt_option_meta=0, crt_option_video=0;
// Core vblank crosses from clk_sys into CLK_VIDEO (2-flop synchronizer).
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg        core_vblank_meta=0, core_vblank_video=0;
always @(posedge CLK_VIDEO) begin
	crt_option_meta<={crt_scandoubler,status[101],status[85:80],status[78:74]};
	crt_option_video<=crt_option_meta;
	core_vblank_meta<=core_vblank;
	core_vblank_video<=core_vblank_meta;
end

// Core-side CRT position (Victory structure). Position-only: RGB, CE and blanking pass
// unchanged; HSync/VSync are delayed only when CRT Adjust is On and scandoubling is off.
// With the adjust Off, VGA_HS/VGA_VS are the arcade_video sync, bit for bit.
// vb_in is the true core vblank (not the combined DE blank), per the CRT-Adjust notes.
wire [23:0] crt_rgb;
sauro_crt_position #(.HTOTAL(316), .VTOTAL(284), .HSYNC_COL(252)) crt_position
(
	.clk(CLK_VIDEO), .ce_pix(mixer_ce),
	.enabled(crt_option_video[11]), .scandoubler(crt_option_video[12]),
	.hposition(crt_option_video[10:5]), .vshift(crt_option_video[4:0]),
	.rgb_in({mixer_r,mixer_g,mixer_b}),
	.hs_in(mixer_hs), .vs_in(mixer_vs), .hb_in(!mixer_de), .vb_in(core_vblank_video),
	.rgb_out(crt_rgb), .ce_out(CE_PIXEL), .hs_out(VGA_HS), .vs_out(VGA_VS),
	.hb_out(), .vb_out()
);
// DE is taken from arcade_video (not moved by the CRT position stage).
assign {VGA_R,VGA_G,VGA_B} = crt_rgb;
assign VGA_DE = mixer_de;

reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1;
assign LED_USER = ioctl_download | (act_cnt[26] ? act_cnt[25:18] > act_cnt[7:0] : act_cnt[25:18] <= act_cnt[7:0]);

endmodule
