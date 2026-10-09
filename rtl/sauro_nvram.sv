// Tecfri battery RAM (E000-E7FF, 2 KB) with MiSTer's NVRAM save/restore stream.
//
// Design follows the interface used by the Victory core (same author's earlier work): the standard hps_io
// download/upload with ioctl_index 4, declared in the MRA as <nvram index="4" size="2048"/>. No framework changes.
//
// - Cold start (no save): all ones, MAME's NVRAM default (M10K initial contents).
// - Restore: index-4 download writes the image (bounds checked, accepted while the machine is paused or reset).
//   The machine is held in reset for any download, so the game restarts with the restored RAM.
// - Save: index-4 upload reads the image through a synchronous host port; hps_io primes address 0 with ioctl_rd
//   and advances as it captures each byte, so completion counts addresses 1..2048 and ignores the prefetch.
// - Autosave is held off until `arm`: the core raises it at the game's first interrupt, so a save is never requested
//   during the ROM self-test (an image saved then would be half-initialised).
// - Game writes mark the image dirty; autosave requests an upload one second after the last write, or within 30 s
//   of the first if writes continue. Only a complete, ordered 2048-byte transfer clears pending changes; an
//   interrupted one leaves them pending. User reset does not clear memory or pending changes.
// - Both CPU and host ports are registered one-clock reads; Quartus infers two coherent copies of the array.
module sauro_nvram #(
	parameter int QUIET_CYCLES = 80_000_000,        // 1 s at 80 MHz
	parameter int MAX_CYCLES   = 2_400_000_000      // 30 s
)(
	input  logic        clk,
	// CPU port (work RAM)
	input  logic [10:0] cpu_addr,
	input  logic [7:0]  cpu_data,
	input  logic        cpu_wr,
	output logic [7:0]  cpu_q,
	// MiSTer host port
	input  logic        download,
	input  logic        upload,
	input  logic        wr,
	input  logic        rd,
	input  logic        arm,                       // autosave allowed (the game has started running)
	input  logic [15:0] index,
	input  logic [26:0] addr,
	input  logic [7:0]  data,
	output logic [7:0]  q,
	output logic        active,                    // a transfer is in progress: pause the machine
	output logic        save_request
);

	logic [7:0] mem [0:2047];
	initial for (int i = 0; i < 2048; i++) mem[i] = 8'hFF;

	wire restoring = download && index == 16'd4;
	wire saving    = upload   && index == 16'd4;
	assign active  = restoring || saving;

	logic        restore_d = 1'b0, save_d = 1'b0;
	logic [11:0] restore_count = 12'd0, save_count = 12'd0;
	logic        restore_bad = 1'b0, save_bad = 1'b0;
	wire restore_done = restore_d && !restoring && restore_count == 12'd2048 && !restore_bad;
	wire save_done    = save_d    && !saving    && save_count    == 12'd2048 && !save_bad;

	logic        dirty = 1'b0;
	logic [31:0] quiet_time = 32'd0, dirty_time = 32'd0;
	initial save_request = 1'b0;

	always_ff @(posedge clk) begin
		cpu_q <= mem[cpu_addr];
		q     <= mem[addr[10:0]];
		// bounds are checked before the write so a long stream cannot wrap onto the image
		if (restoring && wr && addr < 27'd2048) mem[addr[10:0]] <= data;
		else if (cpu_wr && !active)             mem[cpu_addr]   <= cpu_data;

		restore_d <= restoring;
		save_d    <= saving;
		if (!restoring) begin
			restore_count <= 12'd0;
			restore_bad   <= 1'b0;
		end else if (wr) begin
			if (addr == {15'd0, restore_count} && restore_count < 12'd2048) restore_count <= restore_count + 12'd1;
			else restore_bad <= 1'b1;
		end
		if (!saving) begin
			save_count <= 12'd0;
			save_bad   <= 1'b0;
		end else if (rd) begin
			// addresses advance as hps_io captures the preceding byte; the first ioctl_rd only primes byte 0
			if (addr == {15'd0, save_count + 12'd1} && save_count < 12'd2048) save_count <= save_count + 12'd1;
			else if (addr != {15'd0, save_count})                             save_bad   <= 1'b1;
		end

		// A reset or an interrupted transfer must not clear pending changes; only a complete transfer does.
		if (!dirty || restore_done || save_done) begin
			dirty      <= 1'b0;
			quiet_time <= 32'd0;
			dirty_time <= 32'd0;
		end else begin
			if (quiet_time < QUIET_CYCLES) quiet_time <= quiet_time + 32'd1;
			if (dirty_time < MAX_CYCLES)   dirty_time <= dirty_time + 32'd1;
		end
		if (cpu_wr && !active) begin
			dirty      <= 1'b1;
			quiet_time <= 32'd0;
		end

		if (active || restore_done || save_done) save_request <= 1'b0;
		else if (arm && dirty && (quiet_time >= QUIET_CYCLES || dirty_time >= MAX_CYCLES)) save_request <= 1'b1;
	end

endmodule
