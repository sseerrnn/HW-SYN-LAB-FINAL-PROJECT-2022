`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/09/2022 09:29:47 PM
// Design Name: 
// Module Name: system2
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


module system2(output wire RsTx,
    output [6:0] seg,
    output wire [15:10] led,
    output dp,
    output [3:0] an,
    input wire RsRx,
    input clk,
    input btnC);
    //////////////////////////////////
    // uart
    wire                baud; // baudrate
    baudrate_gen baudrate(clk, baud);

    wire    [7:0]       data_out; // 1 char from receive
    wire                received; // = received 8 bits successfully
    reg                 last_rec; // = check if received is new
    wire                new_input;
    assign new_input = ~last_rec & received;
    uart_rx receiver(baud, RsRx, received, data_out);

    reg     [7:0]       data_in; // 1 char to transmit
    wire                sent; // = sent 8 bits successfully
    reg                 wr_en; // = enable transmitter
    uart_tx transmitter(baud, data_in, wr_en, sent, RsTx);

    //////////////////////////////////
    // push button
    wire                reset;
    singlePulser resetButton(reset, btnC, baud);

    //////////////////////////////////
    // r/w buffer

    reg     [31:0]      readbufferBFD; // 4 chars


    //////////////////////////////////
    // casting i/o
    reg     [31:0]      inputbuffer;
    wire    [31:0]      inputval; //int
    wire    [31:0]      readval; //int
    

    wire    [3:0]       outputbuffer3,outputbuffer2,outputbuffer1,outputbuffer0;
    wire    [31:0]      outputval; //int
    wire                readValidOutput;
    wire                validOutput; // for invalid output (NaN)
    wire                signbuffer;
    wire                readsignbuffer;
    wire    [31:0]      bufferBFD;
    strToInt inputCast(inputbuffer, inputval);
    strToInt inputCast2(readbufferBFD, readval);
    assign {outputbuffer3,outputbuffer2,outputbuffer1,outputbuffer0}  = {m3,m2,m1,m0};


    //////////////////////////////////
    // calculation
    reg     [2:0]       op; // 0+ 1- 2* 3/ 4s 5c
    reg                 enterkey;
    reg                 calculate;
    intCalculator cal(baud, reset, inputval, op, calculate, outputval);
    //////////////////////////////////
    // 7-segment
    wire [3:0] num0;
    wire [3:0] num1;
    wire [3:0] num2;
    wire [3:0] num3;

    wire targetClk;
    wire an0, an1, an2, an3;

    assign an = {an3, an2, an1, an0};
    assign {num3,num2,num1,num0} = {write3,write2,write1,write0};
    wire [3:0] m3,m2,m1,m0 ;
    wire [3:0] in3,in2,in1,in0 ;
    reg [3:0] write3,write2,write1,write0;

    round ro0(outputval,signbuffer,m3,m2,m1,m0,validOutput);
    round ro1(readval,readsignbuffer,in3,in2,in1,in0,readValidOutput);




    wire [18:0] tclk;

    assign tclk[0] = clk;

    genvar c;

    generate for(c = 0; c < 18; c = c + 1)
        begin
            clockDiv fdiv(tclk[c+1], tclk[c]);
        end
    endgenerate

    clockDiv fdivTarget(targetClk, tclk[10]);

    quadSevenSeg q7Seg(seg, dp, an0, an1, an2, an3, num0, num1, num2, num3, targetClk);
    //////////////////////////////////
    // led
    reg op0,op1,op2,op3,nan;
    assign led[15] = signbuffer;
    assign led[14] = op0;
    assign led[13] = op1;
    assign led[12] = op2;
    assign led[11] = op3;
    assign led[10] = ~validOutput;


    //////////////////////////////////
    // state
    reg     [2:0]       state;
    parameter STATE_OPERATOR        = 3'd0;
    parameter STATE_BEFOREPOINT    	= 3'd1;
    parameter STATE_SENDMORE    	= 3'd2;
    parameter STATE_DELAY           = 3'd3;
    parameter STATE_ENTERKEY        = 3'd4;
    parameter STATE_CALCULATE       = 3'd5;

    reg     [7:0]       sendlen; // length of sending sting
    reg     [7:0]       counter; // for delay state

    reg beforePoint; // state of input 
    reg operator; // 1 = need new operator , 0 = no more operator needs

    initial begin
        counter = 0; enterkey = 1; op = 5;operator = 1;
        op0 = 0;op1 = 0;op2 = 0;op3 = 0;
        sendlen = 0;
        readbufferBFD   = 32'h30303030;
        {write3,write2,write1,write0}=0;
        state = STATE_ENTERKEY;
    end

    always @(posedge baud) begin
        case(state)
            STATE_OPERATOR: begin
                if(new_input) begin
                    op0 = 0;op1 = 0;op2 = 0;op3 = 0;
                    case(data_out)
                        8'h63: op = 5; // c
                        8'h73: op = 4; // s
                        8'h2F: begin op = 3;op3 = 1; end // /
                        8'h2A: begin op = 2;op2 = 1;end // *
                        8'h2D: begin op = 1;op1 = 1; end // -
                        default:  begin op = 0;op0 = 1;end //+
                    endcase
                    if(data_out == 13) begin enterkey = 1; inputbuffer = readbufferBFD; end //enter
                    else if(data_out == 8'h08) ; //backspace
                    else begin //number
                        if(data_out >= 8'h30 && data_out <=8'h39) begin
                            readbufferBFD[31:8] = readbufferBFD[23:0];
                            readbufferBFD[7:0] = data_out;

                        end
                    end
                    sendlen = 1;
                    operator = 0;
                    state = STATE_ENTERKEY;
                end
            end

            STATE_ENTERKEY:begin //clear data after enter
                if(enterkey) begin
                    readbufferBFD = 32'h30303030;
                    enterkey = 0;
                    calculate =1;
                    sendlen =0 ;
                    state = STATE_CALCULATE;
                end
                else  state  = STATE_SENDMORE;
            end
            STATE_BEFOREPOINT:
            if(new_input) begin
                case(data_out)
                    13: begin enterkey = 1; inputbuffer = readbufferBFD; end
                    default:
                    if(data_out >= 8'h30 && data_out <=8'h39) begin // 0-9
                        readbufferBFD[31:8] = readbufferBFD[23:0];
                        readbufferBFD[7:0] = data_out;
                        sendlen = sendlen+1;

                    end
                endcase
                state = STATE_ENTERKEY;
            end
            STATE_CALCULATE: begin
                calculate = 0;
                if(counter < 32) counter = counter+1; //delay for counter
                else begin

                    if(validOutput) begin
                        {write3,write2,write1,write0} = {outputbuffer3,outputbuffer2,outputbuffer1,outputbuffer0};
                    end
                    else begin
                        {write3,write2,write1,write0} = 0;
                    end
                    operator = 1;
                    state = STATE_SENDMORE;
                    counter = 0;
                end
            end
            STATE_SENDMORE: begin
                if(sendlen>0){ write3,write2,write1,write0} = {in3,in2,in1,in0};
                if(operator) state = STATE_OPERATOR;
                else   state = STATE_BEFOREPOINT;
            end

        endcase

        last_rec = received;
    end
endmodule
