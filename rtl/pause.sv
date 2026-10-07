//============================================================================
//  Generic pause handling for MiSTer cores.
//
//  https://github.com/JimmyStones/Pause_MiSTer
//
//  Copyright (c) 2021 Jim Gregory
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 3 of the License, or (at your option)
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
//============================================================================
/*
 Features:
  - Pause can be triggered by user input, hiscore module or OSD opening (optionally controlled by setting in OSD)
  - When paused the RGB outputs will be halved after 10 seconds to reduce burn-in (optionally controlled by setting in OSD)
  - Reset signal will cancel user triggered pause

 Version history:
 0001 - 2021-03-15 -    First marked release
 0002 - 2021-08-28 -    Add optional output of dim_video signal (currently used by Galaga)
============================================================================
*/
module pause #(
	parameter                        RW=8,                   // Width of red channel
	parameter                        GW=8,                   // Width of green channel
	parameter                        BW=8,                   // Width of blue channel
	parameter                        CLKSPD = 12,            // Main clock speed in MHz
	parameter                        DIM_CYCLES = CLKSPD * 10000000
)
(
	input                            clk_sys,                // Core system clock (should match HPS module)
	input                            reset,                  // CPU reset signal (active-high)
	input                            user_button,            // User pause button signal (active-high)
	input                            pause_request,          // Pause requested by other code (active-high)
	input [1:0]                      options,                // Pause options from OSD
															 //   [0] = pause in OSD (active-high)
															 //   [1] = dim video (active-high)
	input                            OSD_STATUS,             // OSD is open (active-high)
	input    [(RW-1):0]              r,                      // Red channel
	input    [(GW-1):0]              g,                      // Green channel
	input    [(BW-1):0]              b,                      // Blue channel

	output                           pause_cpu,              // Pause signal to CPU (active-high)
`ifdef PAUSE_OUTPUT_DIM
	output                           dim_video,              // Dim video requested (active-high)
`endif

	output   [(RW-1):0]              r_out,                  // Red channel
	output   [(GW-1):0]              g_out,                  // Green channel
	output   [(BW-1):0]              b_out                   // Blue channel
);

// Option constants
localparam        pause_in_osd    = 1'b0;
localparam        dim_video_timer = 1'b1;

reg               pause_toggle    = 1'b0;                 // User paused (active-high)
reg [31:0]        pause_timer     = 32'd0;                // Time since pause
localparam [31:0] dim_timeout     = DIM_CYCLES;           // Default: ten seconds
reg               user_button_last = 1'b0;
`ifndef PAUSE_OUTPUT_DIM
wire              dim_video;                                 // Dim video requested (active-high)
`endif

assign pause_cpu = (pause_request | pause_toggle  | (OSD_STATUS & options[pause_in_osd])) & !reset;
assign dim_video = (pause_timer >= dim_timeout);

always @(posedge clk_sys) begin

	// Track user pause button down
	user_button_last <= user_button;
	// Reset has priority, even when the pause button is pressed simultaneously.
	if(reset) pause_toggle <= 0;
	else if(!user_button_last & user_button) pause_toggle <= ~pause_toggle;

	if(pause_cpu & options[dim_video_timer])
	begin
		// Track pause duration for video dim
		if((pause_timer<dim_timeout))
		begin
			pause_timer <= pause_timer + 1'b1;
		end
	end
	else
	begin
		pause_timer <= 32'd0;
	end
end

assign r_out = dim_video ? r >> 1 : r;
assign g_out = dim_video ? g >> 1 : g;
assign b_out = dim_video ? b >> 1 : b;

endmodule
