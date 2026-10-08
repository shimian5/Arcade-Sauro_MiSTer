// Tecfri sound: YM3812 (jtopl2) for all boards; Sauro family adds a Z80 sound CPU, a command latch and the
// SP0256 voice. MAME-derived and PROVISIONAL (no schematic); see docs/MAME_FINDINGS.md F3.
//
// Sauro family (audio CPU, 4 MHz = 20 MHz / 5):
//   0000-7FFF ROM   8000-87FF RAM   A000 W SP0256 address load   C000-C001 W YM3812 (A0 = A0)
//   E000 R sound command (reading clears it)   E000-E006, E00E-E00F writes ignored
//   INT = YM3812 IRQ (level)   NMI = SP0256 LRQ
// MAME fakes the audio CPU interrupt with a 480 Hz timer; the audio ROM's interrupt routine acknowledges a
// YM3812 timer flag (register 04 = 80h) on every interrupt, so this core wires the chip's IRQ to the CPU
// instead (about 496 Hz with the programmed timer 2). The wiring is an inference, not a measurement.
// Tricky Doc has no sound CPU: the main CPU writes the YM3812 at F820/F821, and the chip runs from 2.5 MHz
// (20 MHz / 8) where the Sauro family uses 4 MHz.
module tecfri_audio (
	input  logic               clk,            // 80 MHz
	input  logic               reset_n,        // machine reset (active low)
	input  logic               pause,          // freezes CPU and sound chips, output muted
	input  logic               tricky,
	input  logic               speech_mute,    // diagnostic: drop the SP0256 voice from the mix
	input  logic               tone_en,        // diagnostic: replace the mix with a 440 Hz square wave
	input  logic [3:0]         dbg_sel,        // diagnostic: tone plays only once the selected event has happened since reset

	// ROM download (audio CPU program)
	input  logic               rom_we,
	input  logic [14:0]        rom_wa,
	input  logic [7:0]         rom_wd,

	// from the main CPU
	input  logic               snd_cmd_wr,
	input  logic [7:0]         snd_cmd,
	input  logic               main_ym_wr,
	input  logic               main_ym_a0,
	input  logic [7:0]         main_ym_d,

	output logic signed [15:0] ym_out,
	output logic signed [15:0] speech_out,
	output logic signed [15:0] mix_out,

	// observation for tests
	output logic               dbg_ym_wr,
	output logic               dbg_ym_a0,
	output logic [7:0]         dbg_ym_d,
	output logic               dbg_ald_wr,
	output logic [7:0]         dbg_ald_d,
	output logic               dbg_cmd_rd
);

	// ------------------------------------------------------------ clock enables (from 80 MHz)
	logic [4:0] ph20 = 5'd0;                    // 4 MHz
	logic [4:0] ph32 = 5'd0;                    // 2.5 MHz
	always_ff @(posedge clk) begin
		ph20 <= (ph20 == 5'd19) ? 5'd0 : ph20 + 5'd1;
		ph32 <= ph32 + 5'd1;
	end
	wire cen4   = (ph20 == 5'd0) && !pause;
	wire cen2_5 = (ph32 == 5'd0) && !pause;

	// ------------------------------------------------------------ audio CPU
	logic        m1_n, mreq_n, iorq_n, rd_n, wr_n, halt_n;
	logic [15:0] a;
	logic [7:0]  cpu_do, cpu_di;
	logic        int_n, nmi_n;

	cpu_z80 cpu (
		.clk(clk), .cen(cen4), .reset_n(reset_n && !tricky), .wait_n(1'b1),
		.int_n(int_n), .nmi_n(nmi_n), .busrq_n(1'b1),
		.m1_n(m1_n), .mreq_n(mreq_n), .iorq_n(iorq_n), .rd_n(rd_n), .wr_n(wr_n),
		.rfsh_n(), .halt_n(halt_n), .busak_n(),
		.a(a), .di(cpu_di), .dout(cpu_do)
	);

	logic wr_n_q;
	always_ff @(posedge clk) wr_n_q <= wr_n;
	wire wr_pulse = !wr_n && wr_n_q;
	wire mem_wr   = wr_pulse && !mreq_n;
	wire mem_rd   = !rd_n && !mreq_n;

	// program ROM and RAM
	logic [7:0] rom_q;
	tecfri_rom #(15) arom (.clk(clk), .we(rom_we), .wa(rom_wa), .wd(rom_wd), .ra(a[14:0]), .q(rom_q));

	logic [7:0] ram [0:2047];
	logic [7:0] ram_q;
	wire sel_rom = !a[15];
	wire sel_ram = (a[15:11] == 5'b10000);              // 8000-87FF
	wire sel_cmd = (a == 16'hE000);
	always_ff @(posedge clk) begin
		if (mem_wr && sel_ram) ram[a[10:0]] <= cpu_do;
		ram_q <= ram[a[10:0]];
	end

	// sound command latch: written by the main CPU, cleared when the audio CPU finishes reading it
	logic [7:0] cmd;
	logic       cmd_rd_q;
	wire        cmd_rd = mem_rd && sel_cmd;
	always_ff @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			cmd      <= 8'h00;
			cmd_rd_q <= 1'b0;
		end else begin
			cmd_rd_q <= cmd_rd;
			if (snd_cmd_wr)               cmd <= snd_cmd;
			else if (cmd_rd_q && !cmd_rd) cmd <= 8'h00;
		end
	end
	assign dbg_cmd_rd = cmd_rd && !cmd_rd_q;

	always_comb begin
		cpu_di = 8'hFF;
		if (!mreq_n) begin
			if      (sel_rom) cpu_di = rom_q;
			else if (sel_ram) cpu_di = ram_q;
			else if (sel_cmd) cpu_di = cmd;
		end
	end

	// ------------------------------------------------------------ YM3812
	wire acpu_ym_wr = mem_wr && (a[15:1] == 15'h6000);   // C000-C001
	wire ym_wr      = tricky ? main_ym_wr : acpu_ym_wr;
	wire ym_a0      = tricky ? main_ym_a0 : a[0];
	wire [7:0] ym_d = tricky ? main_ym_d  : cpu_do;
	assign dbg_ym_wr = ym_wr;
	assign dbg_ym_a0 = ym_a0;
	assign dbg_ym_d  = ym_d;

	// jtopl wants rst held for at least 6 clk&cen cycles: stretch the machine reset by 16 enables
	logic [4:0] rst_cnt = 5'd0;
	wire ym_cen = tricky ? cen2_5 : cen4;
	always_ff @(posedge clk) begin
		if (!reset_n) rst_cnt <= 5'd0;
		else if (ym_cen && rst_cnt != 5'd16) rst_cnt <= rst_cnt + 5'd1;
	end
	wire ym_rst = (rst_cnt != 5'd16);

	logic ym_irq_n;
	logic signed [15:0] ym_snd;
	logic ym_sample;
	jtopl2 ym (
		.rst(ym_rst), .clk(clk), .cen(ym_cen),
		.din(ym_d), .addr(ym_a0), .cs_n(!ym_wr), .wr_n(!ym_wr),
		.dout(), .irq_n(ym_irq_n), .snd(ym_snd), .sample(ym_sample)
	);
	assign int_n = ym_irq_n;
	assign ym_out = ym_snd;

	// ------------------------------------------------------------ SP0256 voice
	wire ald_wr = mem_wr && (a == 16'hA000);
	assign dbg_ald_wr = ald_wr;
	assign dbg_ald_d  = cpu_do;
	logic lrq_n;
	logic signed [15:0] sp_sample;
	tecfri_speech speech (
		.clk(clk), .reset_n(reset_n && !tricky), .hold(pause),
		.ald_wr(ald_wr), .ald_data(cpu_do), .lrq_n(lrq_n), .sample(sp_sample)
	);
	assign nmi_n      = lrq_n;
	assign speech_out = sp_sample;

	// ------------------------------------------------------------ diagnostic event flags (sticky, cleared by machine reset)
	// Selected by dbg_sel; the mix is replaced by the test tone while the chosen flag is set, so the OSD user can hear
	// which step of the Sauro sound chain happened: 1 ROM downloaded, 2 sound CPU ran code past 0100, 3 sound CPU wrote the YM3812,
	// 4 YM3812 IRQ went low, 5 sound CPU read the command latch, 6 main CPU sent a sound command, 7 YM3812 output became audible,
	// 8 main loop 0278 reached, 9 INT/RST38 vector entered, 10 NMI vector entered, 11 opcode fetched from 8000+ (wild), 12 YM timer 2 started.
	logic [15:0] rom_cnt = 16'd0;
	always_ff @(posedge clk) if (rom_we && rom_cnt != 16'hFFFF) rom_cnt <= rom_cnt + 16'd1;
	logic f_alive, f_ymw, f_irq, f_cmdrd, f_cmdsent, f_audible, f_main, f_isr, f_nmi, f_wild, f_t2;
	logic [7:0] ym_sel_reg;
	wire signed [15:0] ym_abs = ym_snd[15] ? -ym_snd : ym_snd;
	always_ff @(posedge clk) begin
		if (!reset_n) begin
			f_alive <= 1'b0; f_ymw <= 1'b0; f_irq <= 1'b0; f_cmdrd <= 1'b0; f_cmdsent <= 1'b0; f_audible <= 1'b0;
			f_main <= 1'b0; f_isr <= 1'b0; f_nmi <= 1'b0; f_wild <= 1'b0; f_t2 <= 1'b0; ym_sel_reg <= 8'h00;
		end else begin
			if (!m1_n && !mreq_n && a >= 16'h0100 && a < 16'h8000) f_alive <= 1'b1;
			if (ym_wr)           f_ymw <= 1'b1;
			if (!ym_irq_n)       f_irq <= 1'b1;
			if (cmd_rd)          f_cmdrd <= 1'b1;
			if (snd_cmd_wr)      f_cmdsent <= 1'b1;
			if (ym_abs >= 16'sd32) f_audible <= 1'b1;
			if (!m1_n && !mreq_n && a == 16'h0278) f_main <= 1'b1;                 // reached the sound firmware's main loop
			if (!m1_n && !mreq_n && a == 16'h0038) f_isr  <= 1'b1;                 // entered the INT / RST 38 vector
			if (!m1_n && !mreq_n && a == 16'h0066) f_nmi  <= 1'b1;                 // entered the NMI vector
			if (!m1_n && !mreq_n && a >= 16'h8000) f_wild <= 1'b1;                 // fetched an opcode from RAM or unmapped space
			if (ym_wr && !ym_a0) ym_sel_reg <= ym_d;
			if (ym_wr && ym_a0 && ym_sel_reg == 8'h04 && ym_d[1] && !ym_d[7]) f_t2 <= 1'b1;   // timer 2 start written
		end
	end
	logic dbg_flag;
	always_comb begin
		case (dbg_sel)
			4'd1:    dbg_flag = (rom_cnt >= 16'd32768);
			4'd2:    dbg_flag = f_alive;
			4'd3:    dbg_flag = f_ymw;
			4'd4:    dbg_flag = f_irq;
			4'd5:    dbg_flag = f_cmdrd;
			4'd6:    dbg_flag = f_cmdsent;
			4'd7:    dbg_flag = f_audible;
			4'd8:    dbg_flag = f_main;
			4'd9:    dbg_flag = f_isr;
			4'd10:   dbg_flag = f_nmi;
			4'd11:   dbg_flag = f_wild;
			4'd12:   dbg_flag = f_t2;
			default: dbg_flag = 1'b0;
		endcase
	end

	// ------------------------------------------------------------ mix
	// MAME routes both chips to one mono speaker at gain 1.0. Levels are calibrated against MAME captures
	// of the same machine time (docs/AUDIO.md): the YM3812 from jtopl measured 0.90 of MAME's RMS, so it is
	// scaled by 1 + 1/8; the Speech256 sample peaks near 640 where MAME's SP0256 reaches 6300-8100, so it is
	// scaled by 11. MAME is the only reference available; the real board's DAC and amplifier are unknown.
	wire signed [17:0] ym18  = $signed({{2{ym_snd[15]}}, ym_snd});
	wire signed [17:0] sp18  = speech_mute ? 18'sd0 : $signed({{2{sp_sample[15]}}, sp_sample});
	wire signed [17:0] sum   = ym18 + (ym18 >>> 3) + (sp18 <<< 3) + (sp18 <<< 1) + sp18;
	// 440 Hz test tone: 80 MHz / 880 = 90,909 clocks per half period (diagnostic only)
	logic [16:0] tone_cnt = 17'd0;
	logic        tone_hi  = 1'b0;
	always_ff @(posedge clk) begin
		if (tone_cnt == 17'd90908) begin tone_cnt <= 17'd0; tone_hi <= !tone_hi; end
		else tone_cnt <= tone_cnt + 17'd1;
	end

	always_ff @(posedge clk) begin
		if (tone_en || dbg_flag) mix_out <= tone_hi ? 16'sd8000 : -16'sd8000;
		else if (pause) mix_out <= 16'sd0;
		else if (sum > 18'sd32767)  mix_out <= 16'sd32767;
		else if (sum < -18'sd32768) mix_out <= -16'sd32768;
		else mix_out <= sum[15:0];
	end

endmodule
