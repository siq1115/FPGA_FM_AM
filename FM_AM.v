module FM_AM (
    clk_in_50,
    clk_in_27,
    ADC_BUS,
    ADC_CLK,
    DAC_CLK,
    DAC_BUS,
    SELBUS,
    KEYBUS,
    Shift_RCLK,
    Shift_CLK,
    Shift_Data,
    T_X,
    MM,
    LEDBUS,
    clk_1
);


//============输入输出脚定义==========//


//时钟源
input               clk_in_50;
input               clk_in_27;

//功能选择
input        [3:0]   KEYBUS;

//数码管显示选择
output       [3:0]   SELBUS;    
output       [3:0]   LEDBUS;
output               clk_1;

// //输出功能控制
// output              FM_AM_select;
// output              T_R_select;

//ADC部分
input       [7:0]   ADC_BUS;
output              ADC_CLK;

//DAC部分
output      [9:0]   DAC_BUS;
output              DAC_CLK;

//移位寄存器部分
output              Shift_RCLK;
output              Shift_CLK;
output              Shift_Data;

//输出控制信号
output              T_X;
output              MM;

//===============声明部分============//

reg   [7:0]  write_data_aul=8'd127;         //幅度控制量AM调制
reg  signed [31:0] fre_set = 32'd2_000_000;      //统一频率设置量 AM FM 默认1M
reg  [31:0] write_data_fre = 32'd0;      //频率偏移量
reg [7:0] write_data;               //写入数据 用于FM AM

wire [13:0] dac_out_temp;                //DAC输出数据缓存 14位对齐NCO

reg [31:0] cnt=32'd0;             //48k分频计数器
reg  [17:0] cnt_1k=18'd0 ;               //
reg  clk_in_1k = 'd0;                  //
reg clk_1hz = 'd0;                      //1hzk时钟

reg T_X_temp = 'd0;                 //发送接收选择
reg MM_temp  = 'd0;                 //FM AM选择
reg [3:0] clk_temp = 4'd0;

wire [7:0] dds_data_u;              //无符号DDS
wire [13:0] dds_data_u_14;          //dds14w位暂存

reg  [1:0]   channel=2'd1;          //通道

wire   [7:0] dout_o;                //rom读取（用于实现乐曲播放）

reg [31:0] signalFreq;              
wire signed [13:0] generater_data;  
wire signed [7:0] dds_data;         //FM dds数据

wire  [7:0] modulation_depth =8'd230;   //调制深度0.9
wire  [7:0] Ac = 8'd0;

wire  clk_105;                          //105M锁相环输出
reg   [3:0]  address_1='d0;



//===============FM_AM调制部分=======//

//ip锁相环 105M
Gowin_rPLL PLL_105M(
        .clkout(clk_105), //output clkout
        .clkin(clk_in_27) //input clkin
    );


//ROM核
Gowin_ROM16 lyc(
        .dout(dout_o), //output [7:0] dout
        .ad(address_1) //input [13:0] ad
    );


//用于调制的dds 
NCO_u u_NCO_u (
		.CLOCK(clk_105),//给了50M时钟试试看
		.rst_n('d1),
		//.para_freq(32'd2_000_000),
        .para_freq(write_data_fre),
		.para_freq_phi(32'b0),
		.para_aul(dds_data_u),
		.para_aul_phi(8'd200),
		.para_phi(21'b0),
        .freq_out(clk_1),
		.out_sine(dac_out_temp)
);



//信号产生dds 1k正弦信号

NCO u_generater (
		.CLOCK(clk_105),
		.rst_n('d1),
        .para_freq(signalFreq),
		.para_freq_phi(32'b0),
		.para_aul(8'd95),
		.para_aul_phi(8'd95),
		.para_phi(21'b0),
		.out_sine(generater_data)
);

//无符号正弦 用于AM
NCO_u u_generater_u (
		.CLOCK(clk_105),
		.rst_n('d1),
        .para_freq(32'd2_000),
		.para_freq_phi(32'b0),
		.para_aul(8'd245),
		.para_aul_phi(8'd240),
		.para_phi(21'b0),
		.out_sine(dds_data_u_14)
);





//50M主时钟控制
always @(posedge clk_in_50) begin
    T_X_temp<=0;
    MM_temp <= 1;

//MM0为FM 1为AM
//TX 0 为发送 1为接收
 //   FM_AM功能选择及控制
if(KEYBUS[0]==0) begin
     
    if(KEYBUS[1] == 0) begin
        MM_temp <= 1;
        write_data_aul <= Ac+(modulation_depth*dds_data)>>8;   //选择AM模式
       // write_data_fre <= 32'd2_000_000;
        fre_set <=32'd2_000_000;
    end

    if(KEYBUS[1] == 1)
    begin
       MM_temp <= 0;
        // write_data_fre<= $unsigned(32'd390 * dds_data+fre_set) ;//如果整体有符号则为上下50K选择FM模式
       write_data_aul<=8'd127;
       fre_set <=32'd21_400_000;
       clk_temp <= 4'b0000;
    end

  end 

end

always @(posedge clk_in_50) begin
         //48k采样信号产生
    if(cnt == 25_000_000) begin
        cnt<=0;
        clk_1hz <= (!clk_1hz);
    end
    
    else 
    begin
        cnt<=cnt+1;
        
    end
end




always @(posedge clk_in_50) begin
    if(cnt_1k == 4999) begin
        cnt_1k<=0;
        clk_in_1k <= (!clk_in_1k);
    end
    else 
    begin
        cnt_1k <= cnt_1k+1;
    end

    
end

always@(posedge KEYBUS[3])begin
    if(channel == 2'd3)
        channel <= 2'd1;
    else
        channel <= channel + 1'b1;
end



//48kADC采样设置 采集音频信号
always @(posedge clk_1hz) begin
    //TR选择接收模式还是发射模式 如果是发射模式 对应0则为adc直接采集音频信号
        address_1<= address_1+1;
    
    case(address_1)
        3'd0 : signalFreq <= 32'd400;
        3'd1 : signalFreq <= 32'd600;
        3'd2 : signalFreq <= 32'd800;
        3'd3 : signalFreq <= 32'd1000;
        3'd4 : signalFreq <= 32'd1200;
        3'd5 : signalFreq <= 32'd1400;
        3'd6 : signalFreq <= 32'd1600;
        3'd7 : signalFreq <= 32'd1800;
        default:signalFreq <= 32'd200;
    endcase
    
    


end

always@(*)begin
    if(KEYBUS[1] == 1'b0)begin
        case(channel)//am
            2'd1:   write_data_fre <= 32'd1_800_000;
            2'd2:   write_data_fre <= 32'd2_000_000;
            2'd3:   write_data_fre <= 32'd2_200_000;
            default:    write_data_fre <= 32'd2_000_000;
        endcase
    end
    else begin
        case(channel)//fm
            2'd1:   write_data_fre<= $unsigned(32'd390 * dds_data+32'd19_600_000) ;
            2'd2:   write_data_fre<= $unsigned(32'd390 * dds_data+32'd20_000_000) ;
            2'd3:   write_data_fre<= $unsigned(32'd390 * dds_data+32'd20_400_000) ;
            default:write_data_fre<= $unsigned(32'd390 * dds_data+32'd20_000_000) ;
        endcase
    end
end


seg u_seg(
        .clk(clk_in_1k),
        .SEL(SELBUS),
        .disnum({8'hCB , 3'b000, KEYBUS[1] ,2'b00 ,channel}),
        .rst(0),
        .SCLK(Shift_CLK),
        .RCLK(Shift_RCLK),
        .SER(Shift_Data)
);


assign ADC_CLK = clk_1hz;
assign DAC_BUS = dac_out_temp[13:4];

assign DAC_CLK = clk_105;

assign  T_X = 1'b0;
assign  MM = 1'b1;

assign dds_data = generater_data[13:6];//freq

assign dds_data_u = (KEYBUS[1]) ? 8'd240 : dds_data_u_14[13:0];//aul
assign LEDBUS= KEYBUS;



endmodule