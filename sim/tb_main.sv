// Original-ROM execution of the main-CPU subsystem. Logs CPU writes in the same
// "<space> w <addr>=<data>" form as sim/mame/trace_io.lua so tools/compare_trace.py
// can compare the sequence against a MAME trace.
//
//   +ROM=<file.hex>   64 KB program image ($readmemh, one byte per line)
//   +TRICKY=1         Tricky Doc map          +LOG=<file>   output log
//   +MS=<n>           machine milliseconds to run (default 1750)
`timescale 1ns/1ps
module tb_main;
	reg clk = 1'b0;
	reg reset_n = 1'b0;
	reg [1:0] div = 2'd0;
	always #25 clk = ~clk;				// 20 MHz
	always @(posedge clk) div <= div + 2'd1;
	wire cen = (div == 2'd0);			// 5 MHz CPU/pixel enable

	reg [7:0] rom [0:65535];
	wire [15:0] rom_addr;
	reg  [7:0]  rom_data;
	always @(posedge clk) rom_data <= rom[rom_addr];

	wire hblank, vblank, vblank_start;
	wire [8:0] hcnt, vcnt;
	sauro_timing timing (.clk(clk), .reset_n(reset_n), .pix_cen(cen), .hcnt(hcnt), .vcnt(vcnt),
		.hblank(hblank), .vblank(vblank), .vblank_start(vblank_start));

	reg tricky = 1'b0;
	wire bus_wr, bus_io;
	wire [15:0] bus_a;
	wire [7:0]  bus_d;
	sauro_main dut (
		.clk(clk), .reset_n(reset_n), .cen_cpu(cen), .tricky(tricky), .vblank_start(vblank_start),
		.dsw1(8'h66), .dsw2(8'h2f), .p1(8'h00), .p2(8'h00),	// MAME defaults, see trace_io.lua reads
		.rom_addr(rom_addr), .rom_data(rom_data),
		.vid_bg_a(10'd0), .vid_fg_a(10'd0), .vid_spr_a(10'd0),
		.vid_bgv_d(), .vid_bgc_d(), .vid_fgv_d(), .vid_fgc_d(), .vid_spr_d(),
		.flip(), .palette_bank(), .scroll_bg(), .scroll_fg(), .coin_counter(),
		.snd_cmd_wr(), .snd_cmd(), .ym_wr(), .ym_a0(), .ym_d(), .wd_kick(), .int_ack(),
		.bus_wr(bus_wr), .bus_io(bus_io), .bus_a(bus_a), .bus_d(bus_d));

	integer log_f, ms, i, first_c9 = 0;
	reg [1023:0] rom_name, log_name;
	real t_first_irq = 0.0;

	// MAME trace_io.lua logs I/O writes >= 80h (Sauro) or program writes F820-F83F (Tricky Doc).
	always @(posedge clk) if (bus_wr) begin
		if (!tricky && bus_io && bus_a[7:0] >= 8'h80)
			$fwrite(log_f, "io w %04x=%02x\n", {8'h00, bus_a[7:0]}, bus_d);
		if (tricky && !bus_io && bus_a >= 16'hF820 && bus_a <= 16'hF83F)
			$fwrite(log_f, "program w %04x=%02x\n", bus_a, bus_d);
		if (!tricky && bus_io && bus_a[7:0] == 8'hC9 && !first_c9) begin
			first_c9 = 1; t_first_irq = $realtime / 1.0e9;
		end
	end

	initial begin
		if (!$value$plusargs("ROM=%s", rom_name)) $fatal(1, "need +ROM=");
		if (!$value$plusargs("LOG=%s", log_name)) log_name = "tb_main.log";
		if (!$value$plusargs("MS=%d", ms)) ms = 1750;
		if ($test$plusargs("TRICKY")) tricky = 1'b1;
		for (i = 0; i < 65536; i = i + 1) rom[i] = 8'hFF;
		$readmemh(rom_name, rom);
		log_f = $fopen(log_name, "w");
		#200 reset_n = 1'b1;
		#(ms * 1000000);
		$display("ran %0d ms; first ISR acknowledge at %f s", ms, t_first_irq);
		$fclose(log_f);
		$finish;
	end
endmodule
