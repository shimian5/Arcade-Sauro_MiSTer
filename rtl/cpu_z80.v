// Z80 CPU wrapper around TV80 (plain Verilog), used for both synthesis and
// simulation.
//
// tv80s.v ties its internal `cen` permanently to 1, so it has no usable
// clock-enable and would run the CPU at the full core clock. Instead tv80_core
// is instantiated directly and its `cen` is driven from this module's `cen`
// input (one pulse per Z80 T-state); tv80_core gates its state updates on `cen` internally
// (`ClkEn = cen && ~BusAck`). The bus-signal decode below is copied from
// tv80s.v (mreq_n/rd_n/wr_n/iorq_n from mcycle/tstate/intcycle_n/iorq/write/
// no_read). Decode on the same enabled CPU edge as TV80: its T2 data
// update and WR assertion then settle together, and WR remains active for
// a complete CPU period. Decoding every SYS edge closes WR one SYS after
// data becomes valid, so a separately clock-enabled peripheral can sample
// stale data. During T3, keep sampling read data while the bus strobe is held;
// this allows synchronous RAM and peripheral read muxes to settle before the
// next enabled CPU edge consumes the byte.
module cpu_z80
(
	input  wire        clk,       // system clock
	input  wire        cen,       // one strobe per Z80 T-state
	input  wire        reset_n,
	input  wire        wait_n,
	input  wire        int_n,
	input  wire        nmi_n,
	input  wire        busrq_n,
	output wire        m1_n,
	output wire        mreq_n,
	output wire        iorq_n,
	output wire        rd_n,
	output wire        wr_n,
	output wire        rfsh_n,
	output wire        halt_n,
	output wire        busak_n,
	output wire [15:0] a,
	input  wire [7:0]  di,
	output wire [7:0]  dout
);

	// Bus decode from tv80s.v, with the real `cen` wired in.
	reg        mreq_n_r, iorq_n_r, rd_n_r, wr_n_r;
	wire       intcycle_n_w, no_read_w, write_w, iorq_w;
	reg [7:0]  di_reg;
	wire [6:0] mcycle_w, tstate_w;

	assign mreq_n = mreq_n_r;
	assign iorq_n = iorq_n_r;
	assign rd_n   = rd_n_r;
	assign wr_n   = wr_n_r;

	tv80_core #(.Mode(0), .IOWait(1)) i_tv80_core
	(
		.cen        (cen),
		.m1_n       (m1_n),
		.iorq       (iorq_w),
		.no_read    (no_read_w),
		.write      (write_w),
		.rfsh_n     (rfsh_n),
		.halt_n     (halt_n),
		.wait_n     (wait_n),
		.int_n      (int_n),
		.nmi_n      (nmi_n),
		.reset_n    (reset_n),
		.busrq_n    (busrq_n),
		.busak_n    (busak_n),
		.clk        (clk),
		.IntE       (),
		.stop       (),
		.A          (a),
		.dinst      (di),
		.di         (di_reg),
		.dout       (dout),
		.mc         (mcycle_w),
		.ts         (tstate_w),
		.intcycle_n (intcycle_n_w)
	);

	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			rd_n_r   <= 1'b1;
			wr_n_r   <= 1'b1;
			iorq_n_r <= 1'b1;
			mreq_n_r <= 1'b1;
			di_reg   <= 8'h00;
		end else begin
			if (cen) begin
				rd_n_r   <= 1'b1;
				wr_n_r   <= 1'b1;
				iorq_n_r <= 1'b1;
				mreq_n_r <= 1'b1;
				if (mcycle_w[0]) begin
					if (tstate_w[1] || (tstate_w[2] && wait_n == 1'b0)) begin
						rd_n_r   <= ~intcycle_n_w;
						mreq_n_r <= ~intcycle_n_w;
						iorq_n_r <= intcycle_n_w;
					end
					// Match tv80s: external refresh requests memory during T4.
					`ifdef TV80_REFRESH
					if (tstate_w[3]) mreq_n_r <= 1'b0;
					`endif
				end else begin
					if ((tstate_w[1] || (tstate_w[2] && wait_n == 1'b0)) && no_read_w == 1'b0 && write_w == 1'b0) begin
						rd_n_r   <= 1'b0;
						iorq_n_r <= ~iorq_w;
						mreq_n_r <= iorq_w;
					end
					if ((tstate_w[1] || (tstate_w[2] && wait_n == 1'b0)) && write_w == 1'b1) begin
						wr_n_r   <= 1'b0;
						iorq_n_r <= ~iorq_w;
						mreq_n_r <= iorq_w;
					end
				end
			end
			// RD stays active throughout T3, including the final enabled edge.
			// The first SYS edge can precede a registered peripheral response;
			// later samples see the settled response with the same address.
			if (tstate_w[2] && wait_n == 1'b1 && !write_w && !no_read_w)
				di_reg <= di;
		end
	end

endmodule
