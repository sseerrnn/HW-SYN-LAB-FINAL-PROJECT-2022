module round
(
    input   wire[31:0] x,
    output         signbuffer,
    output  reg[31:0] rounded3,
    output  reg[31:0] rounded2,
    output  reg[31:0] rounded1,
    output  reg[31:0] rounded0,
    output reg           validout
);
    assign signbuffer = x[31];
    reg [31:0] y ;
    
    reg[31:0] rounded4;
    always @(*) begin
        
        
        if(x[31]) y = -x;
        else y = x;
        
        rounded4 = (y % 32'd100000)/32'd10000;
        if(rounded4==0) validout = 1;
        else validout =0;
        
        
        // % operator is VERY slow and expensive!!!
        rounded3 = (y % 32'd10000)/32'd1000;
        rounded2 = (y % 32'd1000)/32'd100;
        rounded1 = (y %32'd100)/32'd10;
        rounded0 = y %32'd10;
//        rounded3 = 0;
//        rounded2 = 0;
//        rounded1 = 0;
//        rounded0 = 0;
//        end
//        else begin
//        rounded3 = (y % 32'd10000)/32'd1000;
//        rounded2 = (y % 32'd1000)/32'd100;
//        rounded1 = (y %32'd100)/32'd10;
//        rounded0 = y %32'd10;
//        end

    end


endmodule