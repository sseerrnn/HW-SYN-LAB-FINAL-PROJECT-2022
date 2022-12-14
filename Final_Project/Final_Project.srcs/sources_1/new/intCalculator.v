`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/11/2022 04:10:03 PM
// Design Name: 
// Module Name: intCalculator
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


module intCalculator(
    input clk, input reset,
    input wire signed [31:0]   inputval,
    input wire        [2:0]    op,
    input wire                 en,
    output reg signed [31:0]   outputval,
    output reg zerodiv
    );
    reg  signed [31:0] currentval;     // current val in the accumulator
    wire signed [31:0] aluval;
    alu alu1(currentval, inputval, op, aluval);
    
    reg state;

    initial begin state = 0; currentval = 0;
    zerodiv = 0; end
    always @(posedge clk) begin
        if(inputval==0 && op==3) zerodiv = 1;
        if(reset)       begin currentval = 0;           state = 0; zerodiv= 0;end
        case(state)
            0: if(en)   begin currentval = aluval;      state = 1; end
            1: if(~en)  begin outputval = currentval;   state = 0; end
        endcase
    end
    
endmodule
module alu(
    input       signed  [31:0]  A,
    input       signed  [31:0]  B,
    input               [2:0]   op,
    output reg  signed  [31:0]  S
    );
    
    always@(A or B or op)
        
        case(op)
            0: S = A+B;
            1: S = A-B;
            2: S = A*B;
            3: S = A/B;
            4: S = A;
            5: S = 0;
        endcase
endmodule
