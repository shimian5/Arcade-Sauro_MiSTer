// sauro_nvram unit test: cold-start default, save (upload) through hps_io-style priming reads, restore (download),
// interrupted transfers, bounds checking, wrong index, CPU writes during a transfer, and autosave request timing.
`timescale 1ns/1ps
module tb_nvram;
	reg clk = 1'b0;
	always #5 clk = ~clk;
	reg [10:0] cpu_addr = 0; reg [7:0] cpu_data = 0; reg cpu_wr = 0; wire [7:0] cpu_q;
	reg download = 0, upload = 0, wr = 0, rd = 0, arm = 1; reg [15:0] index = 0; reg [26:0] addr = 0; reg [7:0] data = 0;
	wire [7:0] q; wire active, save_request;

	sauro_nvram #(.QUIET_CYCLES(2000), .MAX_CYCLES(20000)) dut (
		.clk(clk), .cpu_addr(cpu_addr), .cpu_data(cpu_data), .cpu_wr(cpu_wr), .cpu_q(cpu_q),
		.download(download), .upload(upload), .wr(wr), .rd(rd), .arm(arm), .index(index), .addr(addr), .data(data),
		.q(q), .active(active), .save_request(save_request));

	integer errors = 0, i;
	// test image byte k: not periodic in 256 so an address wrap cannot hide behind identical values
	function [7:0] img(input [7:0] seed, input integer k);
		img = (seed + k) ^ (k >> 8);
	endfunction
	reg [7:0] saved [0:2047];

	task check(input cond, input [255:0] what);
	begin if (!cond) begin errors = errors + 1; $display("FAIL: %0s", what); end end
	endtask

	task cpu_write(input [10:0] a, input [7:0] d);
	begin @(posedge clk); cpu_addr <= a; cpu_data <= d; cpu_wr <= 1'b1; @(posedge clk); cpu_wr <= 1'b0; end
	endtask

	function [7:0] cpu_read(input [10:0] a);
	begin cpu_addr = a; end
	endfunction

	task cpu_rd(input [10:0] a, output [7:0] d);
	begin @(posedge clk); cpu_addr <= a; @(posedge clk); @(posedge clk); d = cpu_q; end
	endtask

	// hps_io style upload: prime address 0, then per byte capture q and advance
	task do_upload(input [15:0] idx, input integer nbytes);
	begin
		@(posedge clk); index <= idx; upload <= 1'b1; addr <= 0; rd <= 1'b1;
		@(posedge clk); rd <= 1'b0;
		for (i = 0; i < nbytes; i = i + 1) begin
			@(posedge clk); @(posedge clk);
			saved[i] = q;
			addr <= i + 1; rd <= 1'b1;
			@(posedge clk); rd <= 1'b0;
		end
		@(posedge clk); upload <= 1'b0; @(posedge clk); @(posedge clk);
	end
	endtask

	// Upload with CPU write strobes. `early` strobes a write in the same clock the transfer starts (the CPU was frozen in the
	// middle of a write cycle). `late_at >= 0` strobes one after that many bytes were read (the CPU must be frozen by then).
	task do_upload_cpu(input integer nbytes, input early, input [10:0] e_a, input [7:0] e_d,
	                   input integer late_at, input [10:0] l_a, input [7:0] l_d);
	begin
		@(posedge clk); index <= 16'd4; upload <= 1'b1; addr <= 0;
		if (early) begin cpu_addr <= e_a; cpu_data <= e_d; cpu_wr <= 1'b1; end
		@(posedge clk); cpu_wr <= 1'b0; repeat (3) @(posedge clk);
		rd <= 1'b1; @(posedge clk); rd <= 1'b0;
		for (i = 0; i < nbytes; i = i + 1) begin
			@(posedge clk); @(posedge clk);
			saved[i] = q;
			if (i == late_at) begin cpu_addr <= l_a; cpu_data <= l_d; cpu_wr <= 1'b1; @(posedge clk); cpu_wr <= 1'b0; end
			addr <= i + 1; rd <= 1'b1;
			@(posedge clk); rd <= 1'b0;
		end
		@(posedge clk); upload <= 1'b0; @(posedge clk); @(posedge clk);
	end
	endtask

	task do_download(input [15:0] idx, input integer nbytes, input integer start, input [7:0] seed);
	begin
		@(posedge clk); index <= idx; download <= 1'b1;
		for (i = 0; i < nbytes; i = i + 1) begin
			@(posedge clk); addr <= start + i; data <= img(seed, i); wr <= 1'b1;
			@(posedge clk); wr <= 1'b0;
		end
		@(posedge clk); download <= 1'b0; @(posedge clk); @(posedge clk);
	end
	endtask

	reg [7:0] r;
	integer pass_req_seen;
	initial begin
		repeat (5) @(posedge clk);
		// 1. cold start: all ones
		do_upload(16'd4, 2048);
		begin : coldchk integer bad = 0; for (i = 0; i < 2048; i = i + 1) if (saved[i] !== 8'hFF) bad = bad + 1; check(bad == 0, "cold start is all ones"); end
		check(!save_request, "no save request when nothing was written");

		// 2. CPU writes mark dirty; autosave request after the quiet period, cleared by a complete upload
		cpu_write(11'h010, 8'h12); cpu_write(11'h7FF, 8'hAB); cpu_write(11'h400, 8'h55);
		check(!save_request, "no immediate save request");
		repeat (2500) @(posedge clk);
		check(save_request, "autosave requested after quiet time");
		do_upload(16'd4, 2048);
		check(saved[16] == 8'h12 && saved[2047] == 8'hAB && saved[1024] == 8'h55, "uploaded image holds CPU writes");
		check(!save_request, "request clears after a complete upload");

		// 3. interrupted upload leaves changes pending
		cpu_write(11'h020, 8'h77);
		repeat (2500) @(posedge clk);
		check(save_request, "request raised again");
		do_upload(16'd4, 1000);                       // aborted at 1000 bytes
		repeat (50) @(posedge clk);
		check(save_request, "interrupted upload keeps the request");
		do_upload(16'd4, 2048);
		check(saved[32] == 8'h77 && !save_request, "retry completes and clears");

		// 4. restore: ordered download of an image
		do_download(16'd4, 2048, 0, 8'h30);
		cpu_rd(11'h000, r); check(r == 8'h30, "restore byte 0");
		cpu_rd(11'h0FF, r); check(r == img(8'h30, 255), "restore byte 255");
		cpu_rd(11'h7FF, r); check(r == img(8'h30, 2047), "restore byte 2047");
		check(!save_request, "restore does not request a save");

		// 5. wrong index is ignored
		do_download(16'd0, 64, 0, 8'hEE);
		cpu_rd(11'h000, r); check(r == 8'h30, "download with another index is ignored");
		do_upload(16'd1, 16);
		check(!active, "not active after a foreign upload");

		// 6. bounds: a stream longer than 2048 must not wrap onto the image
		do_download(16'd4, 2060, 0, 8'h60);
		cpu_rd(11'h000, r); check(r == img(8'h60, 0), "long download: byte 0 intact (no wrap)");
		cpu_rd(11'h003, r); check(r == img(8'h60, 3), "long download: byte 3 intact (no wrap)");
		cpu_rd(11'h00B, r); check(r == img(8'h60, 11), "long download: byte 11 intact (no wrap)");

		// 7. interrupted restore: writes land but the transfer is not "complete" (no state corruption)
		do_download(16'd4, 100, 0, 8'h90);
		cpu_rd(11'h010, r); check(r == img(8'h90, 16), "partial restore wrote its bytes");

		// 8. CPU writes are ignored while a transfer is active
		@(posedge clk); index <= 16'd4; download <= 1'b1;
		cpu_write(11'h030, 8'hCC);
		@(posedge clk); download <= 1'b0; repeat (3) @(posedge clk);
		cpu_rd(11'h030, r); check(r != 8'hCC, "CPU write during a transfer is ignored");

		// 8b. autosave is held off until armed
		arm = 1'b0; cpu_write(11'h040, 8'h5A);
		repeat (3000) @(posedge clk);
		check(!save_request, "no autosave request while not armed");
		arm = 1'b1; repeat (50) @(posedge clk);
		check(save_request, "request appears once armed");
		do_upload(16'd4, 2048);

		// 9. continuous writes still produce a request within MAX_CYCLES
		for (i = 0; i < 40; i = i + 1) begin cpu_write(11'h100 + i, i); repeat (900) @(posedge clk); end
		check(save_request, "continuous writes still trigger a save");

		// 10. A write that straddles the start of a save (the CPU was frozen in the middle of it) is not lost; a write after the host
		// has started reading is ignored, so the saved image stays a snapshot
		cpu_write(11'h123, 8'h11); cpu_write(11'h200, 8'h22);
		do_upload_cpu(2048, 1'b1, 11'h123, 8'hA7, 100, 11'h200, 8'h5C);
		check(saved[11'h123] == 8'hA7, "write coincident with the start of a save is in the saved image");
		cpu_rd(11'h123, r); check(r == 8'hA7, "write coincident with the start of a save is kept in RAM");
		check(saved[11'h200] == 8'h22, "write after the host started reading is not in the saved image");
		cpu_rd(11'h200, r); check(r == 8'h22, "write after the host started reading is dropped");

		if (errors == 0) $display("PASS: sauro_nvram");
		else $display("FAIL: %0d errors", errors);
		$finish;
	end
endmodule
