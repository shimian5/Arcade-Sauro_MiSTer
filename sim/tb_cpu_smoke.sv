// Toolchain and CPU-wrapper smoke test: a short Z80 program exercises opcode
// fetch, memory write/read-back and an I/O write through cpu_z80 (TV80 core
// with clock enable). This validates the harness only; it is not evidence of
// Tecfri board behavior.
`timescale 1ns/1ps
module tb_cpu_smoke;
	reg         clk = 1'b0;
	reg         reset_n = 1'b0;
	reg  [1:0]  div = 2'd0;
	wire        cen = (div == 2'd0);	// 1 strobe per 4 clk, a 5 MHz-style T-state enable
	wire [15:0] a;
	wire [7:0]  dout;
	reg  [7:0]  di;
	wire        mreq_n, iorq_n, rd_n, wr_n, halt_n, m1_n;
	reg  [7:0]  rom [0:15];
	reg  [7:0]  ram [0:15];
	reg  [7:0]  io_data = 8'h00;
	reg         io_seen = 1'b0;

	always #5 clk = ~clk;
	always @(posedge clk) div <= div + 2'd1;

	cpu_z80 cpu
	(
		.clk(clk), .cen(cen), .reset_n(reset_n), .wait_n(1'b1), .int_n(1'b1),
		.nmi_n(1'b1), .busrq_n(1'b1), .m1_n(m1_n), .mreq_n(mreq_n), .iorq_n(iorq_n),
		.rd_n(rd_n), .wr_n(wr_n), .rfsh_n(), .halt_n(halt_n), .busak_n(),
		.a(a), .di(di), .dout(dout)
	);

	always @* begin
		di = 8'hFF;
		if (!mreq_n && !rd_n) di = (a < 16'h0010) ? rom[a[3:0]] : (a[15:4] == 12'hE00) ? ram[a[3:0]] : 8'hFF;
	end
	always @(posedge clk) begin
		if (!mreq_n && !wr_n && a[15:4] == 12'hE00) ram[a[3:0]] <= dout;
		if (!iorq_n && !wr_n && a[7:0] == 8'h80) begin io_data <= dout; io_seen <= 1'b1; end
	end

	initial begin
		rom[0]=8'h3E; rom[1]=8'h5A;				// LD A,5Ah
		rom[2]=8'h32; rom[3]=8'h00; rom[4]=8'hE0;		// LD (E000h),A
		rom[5]=8'h3E; rom[6]=8'h00;				// LD A,0
		rom[7]=8'h3A; rom[8]=8'h00; rom[9]=8'hE0;		// LD A,(E000h)
		rom[10]=8'hD3; rom[11]=8'h80;				// OUT (80h),A
		rom[12]=8'h76;						// HALT
		#100 reset_n = 1'b1;
		#20000;
		if (io_seen && io_data == 8'h5A && ram[0] == 8'h5A && !halt_n) $display("PASS");
		else begin $display("FAIL io_seen=%0d io=%02x ram0=%02x halt_n=%0d", io_seen, io_data, ram[0], halt_n); $fatal(1); end
		$finish;
	end
endmodule
