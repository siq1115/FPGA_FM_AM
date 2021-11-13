
module seg(clk,SEL,disnum,rst,SCLK,RCLK,SER);

input                   clk;//1khz
input           [15:0]  disnum;
//{disnum3,disnum2,disnum1,disnum0}
output                  SER;
output                  SCLK;
output                  RCLK;
output           [3:0]  SEL;
input                   rst;


wire [4:0]   dis1bit;
reg [1:0]   cnt = 3'b0;
reg [7:0]   sel;
reg [7:0]   dig;
reg [3:0]   cntClkDiv = 4'd0;

assign SCLK = (cntClkDiv < 4'd8) ? ~clk : 1'b0;
assign SEL = sel;
assign RCLK = (cntClkDiv == 4'd9) ? 1'b1 : 1'b0;
assign SER = (cntClkDiv < 4'd8) ? dig[cntClkDiv] : dig[7];
assign dis1bit = disnum[cnt*4 +: 4];
//==============clk8Div============//
always @(posedge clk or posedge rst) begin
    if (rst) begin
        // reset
        cntClkDiv <= 3'd0;
    end
    else begin
        if (cntClkDiv > 4'd10) begin
            cntClkDiv <= 4'd0;
        end
        else begin
            cntClkDiv <= cntClkDiv + 4'd1;
        end
    end
end

//==============1bitControl============//
always @(dis1bit) begin
    case(dis1bit)
    //对数字0到9进行数码管管脚编码
        4'd0: dig <= 8'b11111100;
        4'd1: dig <= 8'b01100000;
        4'd2: dig <= 8'b11011010;
        4'd3: dig <= 8'b11110010;
        4'd4: dig <= 8'b01100110;
        4'd5: dig <= 8'b10110110;
        4'd6: dig <= 8'b10111110;
        4'd7: dig <= 8'b11100000;
        4'd8: dig <= 8'b11111110;
        4'd9: dig <= 8'b11110110;
        4'd10: dig <=8'b11101110;
        4'd11: dig <=8'b01101110;
        4'd12: dig <=8'b10011100;
    default : dig <= 8'b00000000;
    endcase
end

//============selCotrol=====================//
always @(cnt) begin
    case(cnt-1'b1)
    //扫描dsp0到dsp7
        2'd3:sel<=4'b1110;
        2'd2:sel<=4'b1101;
        2'd1:sel<=4'b1011;
        2'd0:sel<=4'b0111;
    endcase
end
//===============selCnter======================//
always @(posedge clk or posedge rst) begin
    if (rst) begin
        // reset
        cnt <= 3'b0;
    end
    else begin
        if (cntClkDiv == 4'd8) begin
            cnt <= cnt + 1'b1;//数码管正常显示
        end
        else begin
            cnt <= cnt;
        end
        
    end
end


endmodule 