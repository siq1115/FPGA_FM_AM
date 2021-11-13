/*============================================================================
	ROM：	14位地址 16384位，	输出精度14位
	module name:NCO
	input:		CLOCK_200M	200M时钟输入
					rst_n			复位
					para_freq		1Hz*para_freq
					para_freq_phi	超前相位频率控制字
					para_aul		幅度控制字
					para_aul_phi	超前相位幅度控制字
					para_phi		相位控制字，精度360/16384 = 0.02197°
	output:			out_sine		输出14位正弦信号
					out_phi 		超前相位输出
					freq_out		输出同步频率时钟，可与频率计形成闭环
	note:			时钟为209.715200MHz可实现50Hz精度
=============================================================================*/
module NCO_u(	input CLOCK,
				input rst_n,
				input [31:0] 	para_freq,
				input [31:0] 	para_freq_phi,
				input [7:0] 	para_aul,
				input [7:0] 	para_aul_phi,
				input [21:0]	para_phi,
				output [13:0]	out_sine,
				output [13:0]	out_phi,
				output	wire	freq_out);
				
//================DECLARATION============//
//=======================================//
//==============时钟选择==================//
//wire 			clk_nco = para_freq > 32'd599999? CLOCK_200M : CLOCK_10M;				
//reg 			CLOCK_10M = 0;
//reg 	[6:0] cnt_clk = 0;
//reg 			CLOCK_500k = 0;
//reg 	[6:0] cnt_clk = 0;
wire clk_nco = CLOCK;
//================输出sine==================//
reg 	[21:0]data_sine;
wire	[21:0]out_temp_sine = (data_sine * para_aul);
assign 		out_sine = out_temp_sine[21:8];
//================输出sine_phi==================//
reg 	[21:0]data_phi;
wire	[21:0]out_temp_phi = (data_phi * para_aul_phi);
assign 		out_phi = out_temp_phi[21:8];
//=======================================//
assign freq_out = (data_sine[13:0] < 14'd8192)? 1'b1 : 1'b0;
//============转译频率参数================//
wire 	[21:0]freq = para_freq / 'd50;
wire 	[21:0]freq_phi = para_freq_phi / 'd50;
//================ROM====================//
reg 	[21:0]addr 		= 'b0;
reg 	[21:0]addr_phi 	= 'b0;
reg [13:0]	ROM_t [0 : 511] ;
//as the symmetry of cos function, just store 1/4 data of one cycle
initial  
        begin  
            $readmemh ("cos.txt",	ROM_t);  
        end 
//================PROCESS================//
//===============READ_ROM==================//
 always @(posedge clk_nco) begin
		if (addr[21:20] == 2'b00 ) begin  //quadrant 1, addr[0, 63]
			 data_sine[13:0] 	<= 14'd8192 + ROM_t[addr[19:11]]  ; //上移
		end

		else if (addr[21:20] == 2'b01 ) begin //2nd, addr[64, 127]
			 data_sine[13:0] 	<= 14'd8192 - ROM_t['d511-addr[19:11]] ; //两次翻转
		end

		else if (addr[21:20] == 2'b10 ) begin //3rd, addr[128, 192]
			 data_sine[13:0] 	<= 14'd8192 - ROM_t[addr[19:11]]; //翻转右移
		end

		else begin     //4th quadrant, addr [193, 256]
			 data_sine[13:0] 	<= 14'd8192 + ROM_t['d511-addr[19:11]]; //翻转上移
		end
 end
 //===============READ_ROM_phi==================//
 always @(posedge clk_nco) begin
		if (addr_phi[21:20] == 2'b00 ) begin  //quadrant 1, addr[0, 63]
			 data_phi[13:0] 	<= 14'd8192 + ROM_t[addr_phi[19:11]]  ; //上移
		end

		else if (addr_phi[21:20] == 2'b01 ) begin //2nd, addr[64, 127]
			 data_phi[13:0] 	<= 14'd8192 - ROM_t['d511-addr_phi[19:11]] ; //两次翻转
		end

		else if (addr_phi[21:20] == 2'b10 ) begin //3rd, addr[128, 192]
			 data_phi[13:0] 	<= 14'd8192 - ROM_t[addr_phi[19:11]]; //翻转右移
		end

		else begin     //4th quadrant, addr [193, 256]
			 data_phi[13:0] 	<= 14'd8192 + ROM_t['d511-addr_phi[19:11]]; //翻转上移
		end
 end
 //====================DDS===================
				
always@(posedge clk_nco or negedge rst_n)begin
	if(rst_n == 0)begin
		addr <= 'b0;
		addr_phi 	= 'b0;
	end
	else begin
		addr <= addr + freq ;
		addr_phi <= addr + freq_phi + para_phi;
	end
end	
//===================DIVIDE=====================
/*
always@(posedge CLOCK_200M or negedge rst_n)begin
	if(rst_n == 0)begin//频率参数分频
		cnt_clk <= 0;
		CLOCK_10M <= 0;
	end
	else begin
		if(cnt_clk >= 9)begin
			cnt_clk <= 0;
			CLOCK_10M <= ~CLOCK_10M;
		end
		else
			cnt_clk <= cnt_clk + 1'b1;
	end
end

//==================转译频率参数===================//
always@(para_freq)begin
	if(para_freq > 32'd599999)//clk=CLOCK_200M
		freq <= (para_freq - 'd3052) / 'd3052;
	else//clk=CLOCK_10M
		freq <= (para_freq - 'd153) / 'd153;
end
*/
//================================ROM==========================//	
				
				
endmodule 

