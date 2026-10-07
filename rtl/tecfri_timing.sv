// Tecfri raster counters.
//
// PROVISIONAL geometry: MAME gives only 240x224 visible at 55.72 Hz, and the
// PCB counters (discrete 74LS163/393) have not been traced. 320x280 at a 5 MHz
// pixel enable gives a 15.625 kHz line rate and 55.80 Hz, 0.14 % above the
// 55.72 Hz PCB figure. All values are parameters so they can be corrected
// without touching the machine logic.
module tecfri_timing #(
	parameter int H_TOTAL  = 320,
	parameter int V_TOTAL  = 280,
	parameter int H_ACTIVE = 240,
	parameter int V_ACTIVE = 224
)(
	input  logic        clk,
	input  logic        reset_n,
	input  logic        pix_cen,        // one strobe per pixel (5 MHz)
	output logic [8:0]  hcnt,
	output logic [8:0]  vcnt,
	output logic        hblank,
	output logic        vblank,
	output logic        vblank_start    // one clk pulse on the first pixel of vertical blanking
);

	always_ff @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			hcnt         <= '0;
			vcnt         <= '0;
			vblank_start <= 1'b0;
		end else begin
			vblank_start <= 1'b0;
			if (pix_cen) begin
				if (hcnt == H_TOTAL - 1) begin
					hcnt <= '0;
					vcnt <= (vcnt == V_TOTAL - 1) ? 9'd0 : vcnt + 9'd1;
					if (vcnt == V_ACTIVE - 1) vblank_start <= 1'b1;
				end else begin
					hcnt <= hcnt + 9'd1;
				end
			end
		end
	end

	assign hblank = (hcnt >= H_ACTIVE);
	assign vblank = (vcnt >= V_ACTIVE);

endmodule
