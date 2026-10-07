// Tecfri main-CPU subsystem (Sauro / Sea Wolf and Tricky Doc), MAME-derived.
//
// Source of truth: MAME 0.257 sauro.cpp (docs/reference/mame) and traces in
// docs/MAME_FINDINGS.md. No schematic exists, so all decode is PROVISIONAL and
// follows MAME's exact address matches (no mirrors beyond those MAME declares).
//
//   tricky = 0 : Sauro/Sea Wolf, I/O-port map, fg layer present
//   tricky = 1 : Tricky Doc, memory-mapped I/O at F800-F83F, YM3812 on this CPU
//
// Memory is single-clock synchronous; cpu_z80 samples read data across T3 so a
// one-clock read latency needs no WAIT. ROM is an external synchronous port.
module tecfri_main
(
	input  logic        clk,
	input  logic        reset_n,
	input  logic        cen_cpu,        // one strobe per Z80 T-state (5 MHz)
	input  logic        tricky,
	input  logic        vblank_start,

	input  logic [7:0]  dsw1,
	input  logic [7:0]  dsw2,
	input  logic [7:0]  p1,
	input  logic [7:0]  p2,

	output logic [15:0] rom_addr,
	input  logic [7:0]  rom_data,       // valid one clk after rom_addr

	// Outputs to video / sound (video RAM read ports are added with the video block)
	output logic        flip,
	output logic [1:0]  palette_bank,
	output logic [7:0]  scroll_bg,
	output logic [7:0]  scroll_fg,
	output logic [1:0]  coin_counter,
	output logic        snd_cmd_wr,     // Sauro: main -> audio CPU command (bit 7 already set)
	output logic [7:0]  snd_cmd,
	output logic        ym_wr,          // Tricky Doc: YM3812 write
	output logic        ym_a0,
	output logic [7:0]  ym_d,
	output logic        wd_kick,

	// Bus observation for tests
	output logic        bus_wr,         // one-clk pulse per CPU write cycle
	output logic        bus_io,
	output logic [15:0] bus_a,
	output logic [7:0]  bus_d
);

	// ---------------------------------------------------------------- CPU
	logic        m1_n, mreq_n, iorq_n, rd_n, wr_n, halt_n;
	logic [15:0] a;
	logic [7:0]  cpu_do, cpu_di;
	logic        int_n;

	cpu_z80 cpu
	(
		.clk(clk), .cen(cen_cpu), .reset_n(reset_n), .wait_n(1'b1),
		.int_n(int_n), .nmi_n(1'b1), .busrq_n(1'b1),
		.m1_n(m1_n), .mreq_n(mreq_n), .iorq_n(iorq_n), .rd_n(rd_n), .wr_n(wr_n),
		.rfsh_n(), .halt_n(halt_n), .busak_n(),
		.a(a), .di(cpu_di), .dout(cpu_do)
	);

	logic wr_n_q;
	always_ff @(posedge clk) wr_n_q <= wr_n;
	wire wr_pulse = !wr_n && wr_n_q;

	// IORQ together with M1 is an interrupt acknowledge, not an I/O cycle.
	wire mem_cyc = !mreq_n;
	wire io_cyc  = !iorq_n && m1_n;
	wire mem_wr  = wr_pulse && mem_cyc;
	wire io_wr   = wr_pulse && io_cyc;
	wire mem_rd  = !rd_n && mem_cyc;

	assign bus_wr = wr_pulse;
	assign bus_io = io_cyc;
	assign bus_a  = a;
	assign bus_d  = cpu_do;

	// ------------------------------------------------------ memory decode
	wire sel_rom   = (a[15:13] != 3'b111);                                    // 0000-DFFF
	wire sel_wram  = (a[15:11] == 5'b11100);                                   // E000-E7FF
	wire sel_spr   = tricky ? (a[15:11] == 5'b11101)                           // E800-EFFF, EC00 mirrors E800
	                        : (a[15:10] == 6'b111010);                         // E800-EBFF
	wire sel_bgv   = (a[15:10] == 6'b111100);                                  // F000-F3FF
	wire sel_bgc   = (a[15:10] == 6'b111101);                                  // F400-F7FF
	wire sel_fgv   = !tricky && (a[15:10] == 6'b111110);                       // F800-FBFF
	wire sel_fgc   = !tricky && (a[15:10] == 6'b111111);                       // FC00-FFFF

	assign rom_addr = a;

	logic [7:0] wram [0:2047];
	logic [7:0] spr  [0:1023];
	logic [7:0] bgv  [0:1023];
	logic [7:0] bgc  [0:1023];
	logic [7:0] fgv  [0:1023];
	logic [7:0] fgc  [0:1023];
	logic [7:0] q_wram, q_spr, q_bgv, q_bgc, q_fgv, q_fgc;

	always_ff @(posedge clk) begin
		if (mem_wr && sel_wram) wram[a[10:0]] <= cpu_do;
		q_wram <= wram[a[10:0]];
		if (mem_wr && sel_spr)  spr[a[9:0]] <= cpu_do;
		q_spr  <= spr[a[9:0]];
		if (mem_wr && sel_bgv)  bgv[a[9:0]] <= cpu_do;
		q_bgv  <= bgv[a[9:0]];
		if (mem_wr && sel_bgc)  bgc[a[9:0]] <= cpu_do;
		q_bgc  <= bgc[a[9:0]];
		if (mem_wr && sel_fgv)  fgv[a[9:0]] <= cpu_do;
		q_fgv  <= fgv[a[9:0]];
		if (mem_wr && sel_fgc)  fgc[a[9:0]] <= cpu_do;
		q_fgc  <= fgc[a[9:0]];
	end

	// ------------------------------------------------------ latch / IRQ
	// 74LS259 addressable latch. Sauro: OUT C0-CF, data = A0, address = A3:A1.
	// Tricky Doc: write F838-F83F, data = D0, address = A2:A0. Cleared by reset.
	logic [7:0] latch_q;
	wire        latch_wr    = tricky ? (mem_wr && a[15:3] == 13'h1F07)
	                                 : (io_wr  && a[7:4] == 4'hC);
	wire [2:0]  latch_addr  = tricky ? a[2:0] : a[3:1];
	wire        latch_data  = tricky ? cpu_do[0] : a[0];

	always_ff @(posedge clk or negedge reset_n) begin
		if (!reset_n)        latch_q <= 8'h00;
		else if (latch_wr)   latch_q[latch_addr] <= latch_data;
	end

	// Q4 masks the vblank interrupt. As modelled in MAME, a write that leaves it
	// low (enabled) also clears a pending interrupt; reset clears the latch.
	logic irq_pending;
	wire  q4_enabled_write = latch_wr && latch_addr == 3'd4 && !latch_data;
	always_ff @(posedge clk or negedge reset_n) begin
		if (!reset_n)                          irq_pending <= 1'b0;
		else if (q4_enabled_write)             irq_pending <= 1'b0;
		else if (vblank_start && !latch_q[4])  irq_pending <= 1'b1;
	end
	assign int_n = !irq_pending;

	assign flip         = tricky ? latch_q[1] : latch_q[0];
	assign coin_counter = tricky ? latch_q[3:2] : latch_q[2:1];
	assign palette_bank = tricky ? 2'b00 : latch_q[6:5];

	// ------------------------------------------------------ I/O registers
	wire [7:0] io_a = a[7:0];

	logic [7:0] io_rdata;
	always_comb begin
		io_rdata = 8'hFF;
		if (!tricky) begin
			case (io_a)
				8'h00: io_rdata = dsw1;
				8'h20: io_rdata = dsw2;
				8'h40: io_rdata = p1;
				8'h60: io_rdata = p2;
				default: ;
			endcase
		end
	end

	logic [7:0] mmio_rdata;
	always_comb begin
		mmio_rdata = 8'hFF;
		case (a)
			16'hF800: mmio_rdata = dsw1;
			16'hF808: mmio_rdata = dsw2;
			16'hF810: mmio_rdata = p1;
			16'hF818: mmio_rdata = p2;
			default: ;
		endcase
	end

	always_ff @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			scroll_bg  <= 8'h00;
			scroll_fg  <= 8'h00;
			snd_cmd_wr <= 1'b0;
			snd_cmd    <= 8'h00;
		end else begin
			snd_cmd_wr <= 1'b0;
			if (!tricky && io_wr) begin
				case (io_a)
					8'h80: begin snd_cmd <= cpu_do | 8'h80; snd_cmd_wr <= 1'b1; end
					8'hA0: scroll_bg <= cpu_do;
					8'hA1: scroll_fg <= cpu_do;   // raw; the bit permutation is applied in video
					default: ;
				endcase
			end
			if (tricky && mem_wr && a == 16'hF830) scroll_bg <= cpu_do;
		end
	end

	assign ym_wr   = tricky && mem_wr && (a == 16'hF820 || a == 16'hF821);
	assign ym_a0   = a[0];
	assign ym_d    = cpu_do;
	assign wd_kick = tricky ? (mem_rd && a == 16'hF828) : (io_wr && io_a == 8'hE0);

	// ------------------------------------------------------ read mux
	always_comb begin
		cpu_di = 8'hFF;
		if (io_cyc) begin
			cpu_di = io_rdata;
		end else if (mem_cyc) begin
			if      (sel_rom)  cpu_di = rom_data;
			else if (sel_wram) cpu_di = q_wram;
			else if (sel_spr)  cpu_di = q_spr;
			else if (sel_bgv)  cpu_di = q_bgv;
			else if (sel_bgc)  cpu_di = q_bgc;
			else if (sel_fgv)  cpu_di = q_fgv;
			else if (sel_fgc)  cpu_di = q_fgc;
			else if (tricky)   cpu_di = mmio_rdata;
		end
	end

endmodule
