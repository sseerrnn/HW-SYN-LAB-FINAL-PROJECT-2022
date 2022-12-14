`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/31/2021 09:36:46 PM
// Design Name: 
// Module Name: vga_sync
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// from https://embeddedthoughts.com/2016/07/29/driving-a-vga-monitor-using-an-fpga/
// there are vga_sync and vga
// modify something in vga

module vga_sync(
    input wire clk, reset,
    output wire hsync, vsync, video_on, p_tick,
    output wire [9:0] x, y
	);
	
	// constant declarations for VGA sync parameters
	localparam H_DISPLAY       = 640; // horizontal display area
	localparam H_L_BORDER      =  48; // horizontal left border
	localparam H_R_BORDER      =  16; // horizontal right border
	localparam H_RETRACE       =  96; // horizontal retrace
	localparam H_MAX           = H_DISPLAY + H_L_BORDER + H_R_BORDER + H_RETRACE - 1;
	localparam START_H_RETRACE = H_DISPLAY + H_R_BORDER;
	localparam END_H_RETRACE   = H_DISPLAY + H_R_BORDER + H_RETRACE - 1;
	
	localparam V_DISPLAY       = 480; // vertical display area
	localparam V_T_BORDER      =  10; // vertical top border
	localparam V_B_BORDER      =  33; // vertical bottom border
	localparam V_RETRACE       =   2; // vertical retrace
	localparam V_MAX           = V_DISPLAY + V_T_BORDER + V_B_BORDER + V_RETRACE - 1;
    localparam START_V_RETRACE = V_DISPLAY + V_B_BORDER;
	localparam END_V_RETRACE   = V_DISPLAY + V_B_BORDER + V_RETRACE - 1;
	
	// mod-4 counter to generate 25 MHz pixel tick
	reg [1:0] pixel_reg;
	wire [1:0] pixel_next;
	wire pixel_tick;
	
	always @(posedge clk, posedge reset)
		if(reset) pixel_reg <= 0;
		else pixel_reg <= pixel_next;
	
	assign pixel_next = pixel_reg + 1; // increment pixel_reg 
	
	assign pixel_tick = (pixel_reg == 0); // assert tick 1/4 of the time
	
	// registers to keep track of current pixel location
	reg [9:0] h_count_reg, h_count_next, v_count_reg, v_count_next;
	
	// register to keep track of vsync and hsync signal states
	reg vsync_reg, hsync_reg;
	wire vsync_next, hsync_next;
 
	// infer registers
	always @(posedge clk, posedge reset)
		if(reset) begin
            v_count_reg <= 0;
            h_count_reg <= 0;
            vsync_reg   <= 0;
            hsync_reg   <= 0;
		end
		else begin
            v_count_reg <= v_count_next;
            h_count_reg <= h_count_next;
            vsync_reg   <= vsync_next;
            hsync_reg   <= hsync_next;
		end
			
	// next-state logic of horizontal vertical sync counters
	always @* begin
		h_count_next = pixel_tick ? 
		               h_count_reg == H_MAX ? 0 : h_count_reg + 1
			         : h_count_reg;
		
		v_count_next = pixel_tick && h_count_reg == H_MAX ? 
		               (v_count_reg == V_MAX ? 0 : v_count_reg + 1) 
			         : v_count_reg;
    end
    
    // hsync and vsync are active low signals
    // hsync signal asserted during horizontal retrace
    assign hsync_next = (h_count_reg >= START_H_RETRACE) && (h_count_reg <= END_H_RETRACE);

    // vsync signal asserted during vertical retrace
    assign vsync_next = (v_count_reg >= START_V_RETRACE) && (v_count_reg <= END_V_RETRACE);

    // video only on when pixels are in both horizontal and vertical display region
    assign video_on = (h_count_reg < H_DISPLAY) && (v_count_reg < V_DISPLAY);

    // output signals
    assign hsync  = hsync_reg;
    assign vsync  = vsync_reg;
    assign x      = h_count_reg;
    assign y      = v_count_reg;
    assign p_tick = pixel_tick;
endmodule


////////////////////////////////////////////////
module vga(
    input wire clk,
    input wire [3:0] num3,
    input wire [3:0] num2,
    input wire [3:0] num1,
    input wire [3:0] num0,
    input wire [3:0] op,
    input wire posneg,
    input wire is_nan,
    input wire [1:0] push,
    output wire hsync, vsync,
    output wire [11:0] rgb
	);
	
	parameter WIDTH = 640;
	parameter HEIGHT = 480;
	
	// register for Basys 2 8-bit RGB DAC 
	reg [11:0] rgb_reg;
	reg reset = 0;
	wire [9:0] x, y;
	
	// video status output from vga_sync to tell when to route out rgb signal to DAC
	wire video_on;
	wire p_tick;

    // instantiate vga_sync
    vga_sync vga_sync_unit (
        .clk(clk), .reset(reset), 
        .hsync(hsync), .vsync(vsync), .video_on(video_on), .p_tick(p_tick), 
        .x(x), .y(y)
        );
        
    // memory map
     parameter NUM_WIDTH = 65;
     parameter NUM_HEIGHT = 120;
     parameter LEFT_SPACE = 40;
     parameter TOP_SPACE = 180;
     parameter BLOCK_SPACE = 60;
     parameter BLOCK_WIDTH = 90;
     parameter BLOCK_HEIGHT = 140;
     parameter OP_WIDTH = 65;
     parameter OP_HEIGTH = 60;
     reg [64:0] rom [0:1739];
     initial $readmemb("7-seg_bin_map.data", rom);

     reg [3:0] tnum3 = 0;
     reg [3:0] tnum2 = 0;
     reg [3:0] tnum1 = 0;
     reg [3:0] tnum0 = 0;
//     reg posneg = 0;
//     reg [3:0] op = 3;
//     reg is_nan = 1;
     /*
     0 = +
     1 = -
     2 = *
     3 = /
     5 = none
     */
	always @(posedge p_tick)
	begin
        tnum3 = 0;
        tnum2 = 0;
        tnum1 = 0;
        tnum0 = 0;
	  if(is_nan == 1) begin
	       tnum3 = num3;
	       tnum2 = 10-num2;
	       tnum1 = 11-num1;
	       tnum0 = 10-num0;
	  end
	  if(y>=TOP_SPACE && y<(480-TOP_SPACE) && x >= LEFT_SPACE && x < (640-LEFT_SPACE)) begin
          if((x - LEFT_SPACE) < BLOCK_WIDTH) begin
               // map is neg
              if((y-TOP_SPACE-30) < OP_HEIGTH && (x - LEFT_SPACE) >= 0 && (x - LEFT_SPACE) < OP_WIDTH &&rom[(posneg*60+12*120+y-TOP_SPACE)][(x - LEFT_SPACE)] == 1 )begin
              // fill black
                   rgb_reg[11:0] <= 12'b000000000000;
              end
              else begin
              // fill white
                   rgb_reg[11:0] <= 12'b111111111111;
              end
           end
           else if((x - LEFT_SPACE) < (2*BLOCK_WIDTH)) begin
               // map num3
              if((x - LEFT_SPACE -BLOCK_WIDTH) >= 0 && (x - LEFT_SPACE -BLOCK_WIDTH) < NUM_WIDTH && rom[((num3-tnum3)*120+y-TOP_SPACE)][(x - LEFT_SPACE-BLOCK_WIDTH)] == 1)begin
              // fill black
                   rgb_reg[11:0] <= 12'b000000000000;
              end
              else begin
              // fill white
                   rgb_reg[11:0] <= 12'b111111111111;
              end
           end 
           else if((x - LEFT_SPACE) < (3*BLOCK_WIDTH)) begin
               // map num2
              if((x - LEFT_SPACE-2*BLOCK_WIDTH) >= 0 && (x - LEFT_SPACE-2*BLOCK_WIDTH) < NUM_WIDTH && rom[((num2+tnum2)*120+y-TOP_SPACE)][(x - LEFT_SPACE-2*BLOCK_WIDTH)] == 1 )begin
              // fill black
                   rgb_reg[11:0] <= 12'b000000000000;
              end
              else begin
              // fill white
                   rgb_reg[11:0] <= 12'b111111111111;
              end
           end 
           else if((x - LEFT_SPACE) < 4*BLOCK_WIDTH) begin
               // map num1
              if((x - LEFT_SPACE-3*BLOCK_WIDTH) >= 0 && (x - LEFT_SPACE-3*BLOCK_WIDTH )< NUM_WIDTH && rom[((num1+tnum1)*120+y-TOP_SPACE)][(x - LEFT_SPACE-3*BLOCK_WIDTH)] == 1 )begin
              // fill black
                   rgb_reg[11:0] <= 12'b000000000000;
              end
              else begin
              // fill white
                   rgb_reg[11:0] <= 12'b111111111111;
              end
           end
           else if((x - LEFT_SPACE) < 5*BLOCK_WIDTH) begin
               // map num0
              if((x - LEFT_SPACE-4*BLOCK_WIDTH) >= 0 && (x - LEFT_SPACE-4*BLOCK_WIDTH )< NUM_WIDTH && rom[(num0+tnum0)*120+y-TOP_SPACE)][(x - LEFT_SPACE-4*BLOCK_WIDTH)] == 1 )begin
              // fill black
                   rgb_reg[11:0] <= 12'b000000000000;
              end
              else begin
              // fill white
                   rgb_reg[11:0] <= 12'b111111111111;
              end
           end 
           else if( (x - LEFT_SPACE) < 6*BLOCK_WIDTH) begin
               // map opertator
              if((x - LEFT_SPACE-5*BLOCK_WIDTH) >= 0 && (y-TOP_SPACE) < OP_HEIGTH && (x - LEFT_SPACE-5*BLOCK_WIDTH )< OP_WIDTH && rom[(op*OP_HEIGTH+12*120+y-TOP_SPACE)][(x - LEFT_SPACE-5*BLOCK_WIDTH)] == 1 )begin
              // fill black
                   rgb_reg[11:0] <= 12'b000000000000;
              end
              else begin
              // fill white
                   rgb_reg[11:0] <= 12'b111111111111;
              end
           end 
	   end
	   else begin
	       rgb_reg[11:0] <= 12'b000111111100;
	   end
    end
    // output
    assign rgb = (video_on) ? rgb_reg : 12'b0;
endmodule