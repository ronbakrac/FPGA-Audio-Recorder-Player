`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:06:18 04/24/2019 
// Design Name: 
// Module Name:    controller 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module controller(switches, rs232_tx, rs232_rx, reset, clk,
	AUD_ADCLRCK, AUD_ADCDAT, AUD_DACLRCK, AUD_DACDAT, AUD_XCK, AUD_BCLK, AUD_I2C_SCLK, AUD_I2C_SDAT, AUD_MUTE,
	hw_ram_rasn, hw_ram_casn, hw_ram_wen, hw_ram_ba, hw_ram_udqs_p, 
	hw_ram_udqs_n, hw_ram_ldqs_p, hw_ram_ldqs_n, hw_ram_udm, hw_ram_ldm, hw_ram_ck, 
	hw_ram_ckn, hw_ram_cke, hw_ram_odt, hw_ram_ad, hw_ram_dq, hw_rzq_pin, hw_zio_pin, LED,
	status, BTN, STATLED0, STATLED1, STATLED2, STATLED3, STATLED4, LEDRAM, volup, voldown);

input clk;
input BTN;
wire clk37;
wire clk100mhz;
input	reset;
input volup, voldown;
output wire STATLED0, STATLED1, STATLED3, STATLED4;
output reg STATLED2;
output reg LEDRAM;
reg [7:0] state;

output [3:0] LED;

// Memory Module Wires
output 		hw_ram_rasn;
output 		hw_ram_casn;
output 		hw_ram_wen;
output[2:0] hw_ram_ba;
inout 		hw_ram_udqs_p;
inout 		hw_ram_udqs_n;
inout 		hw_ram_ldqs_p;
inout 		hw_ram_ldqs_n;
output 		hw_ram_udm;
output 		hw_ram_ldm;
output 		hw_ram_ck;
output 		hw_ram_ckn;
output 		hw_ram_cke;
output 		hw_ram_odt;
output[12:0]hw_ram_ad;
inout [15:0]hw_ram_dq;
inout 		hw_rzq_pin;
inout 		hw_zio_pin;
input [3:0]	switches; 		// address
output 		status;
reg [15:0] RAMin;
wire 	[15:0]	RAMout;
reg [25:0] address;
reg enableWrite;
reg reqRead;
reg ackRead;
wire dataPresent;
wire [25:0]max_ram_address;
reg rdy;
reg [15:0] mem_in;
reg [15:0] mem_out;
reg [15:0] count;


// Audio Codec Wires
inout 	AUD_ADCLRCK;
input 	AUD_ADCDAT;
inout 	AUD_DACLRCK;
output 	AUD_DACDAT;
output 	AUD_XCK;
inout  	AUD_BCLK;
output 	AUD_I2C_SCLK;
inout  	AUD_I2C_SDAT;
output 	AUD_MUTE;
wire 		PLL_LOCKED;
reg [1:0]volume_control;
reg 		playback;
wire [15:0] audio_output;


// RS232 Lines
input		rs232_rx;
output	rs232_tx;



// PicoBlaze Data Lines
wire	[7:0]	pb_port_id;
wire	[7:0]	pb_out_port;
reg		[7:0]	pb_in_port;
wire			pb_read_strobe;
wire			pb_write_strobe;
// PicoBlaze CPU Control Wires
wire			pb_reset;
wire			pb_interrupt;
wire			pb_int_ack;


// UART wires
wire			write_to_uart;
wire			uart_buffer_full;
wire			uart_data_present;
reg				read_from_uart;
wire			uart_reset;
// UART Data Lines
// TX does not need a wire, as it is fed directly by pb_out_port
wire	[7:0]	uart_rx_data;



reg record, play, delete, delete_all, pause;
reg deletedall;


wizard myclock
  (
    .clk37(clk37), 
    .clk100mhz(clk100mhz)
	);


initial begin
	record <= 0;
	play <= 0;
	delete <= 0;
	delete_all <= 0;
	pause <= 0;
	count <= 0;
	volume_control <= 1;
	playback <= 0;
	address <= 0;
	//count <= 0;
	//deleted_all <= 0;
	state <= 8'h00;
	//STATLED0 <= 0;
	//STATLED1 <= 0;
	STATLED2 <= 0;
	//STATLED3 <= 0;
	//STATLED4 <= 0;
	enableWrite <= 0;
	LEDRAM <= 1'b0;
end
	

assign pb_reset = ~reset;
assign uart_reset =  ~reset;
assign pb_interrupt = 1'b0;
assign write_to_uart = pb_write_strobe & (pb_port_id == 8'h03);
assign write_to_state_reg = pb_write_strobe & (pb_port_id == 8'h06);

assign STATLED0 = record;
assign STATLED1 = play;
//assign STATLED2 = delete_all;
//assign STATLED3 = dataPresent;
//assign STATLED4 = pause;
//assign LEDRAM = AUD_I2C_SDAT;




always @(posedge clk100mhz)
begin
	if(vu_dn && (volume_control < 4))
		volume_control <= volume_control + 1;
	
	else if(vd_dn && (volume_control > 0))
		volume_control <= volume_control - 1;
end


wire volupstate, vu_up, vu_dn;
debounce volumeup(
	 .clk(clk100mhz),
    .i_btn(volup),
    .o_state(volupstate),
    .o_ondn(vu_dn),
    .o_onup(vu_up)
);

wire voldnstate, vd_up, vd_dn;
debounce volumedn(
	 .clk(clk100mhz),
    .i_btn(voldown),
    .o_state(voldnstate),
    .o_ondn(vd_dn),
    .o_onup(vd_up)
);




always @(posedge clk100mhz or posedge pb_reset)
	begin
		if(pb_reset) begin
			pb_in_port <= 0;
			read_from_uart <= 0;
		end else begin
			// Set pb input port to appropriate value
			case(pb_port_id)
				//8'h00: pb_in_port <= switches;
				8'h02: pb_in_port <= uart_rx_data;
				8'h04: pb_in_port <= {7'b0000000,uart_data_present};
				8'h05: pb_in_port <= {7'b0000000,uart_buffer_full};
				8'h07: pb_in_port <= {7'b0000000,deletedall};
				default: pb_in_port <= 8'h00;
			endcase
			// Set up acknowledge/enable signals.
			//
			// Some modules, such as the UART, need confirmation that the data
			// has been read, since it needs to push it off the queue and make
			// the next byte available. This logic will set the 'read_from'
			// signal high for corresponding ports, as needed. Most input
			// ports will not need this.
			read_from_uart <= pb_read_strobe & (pb_port_id == 8'h04);
			if(write_to_state_reg) begin 
				record <= (pb_out_port == 8'h01); //use led to check
				play <= (pb_out_port == 8'h00);
				delete <= (pb_out_port == 8'h02);
				pause <= (pb_out_port == 8'h03);
				delete_all <= (pb_out_port == 8'h04);
			end
		end
	end

picoblaze pblaze(
	.port_id(pb_port_id),
	.read_strobe(pb_read_strobe), 
	.in_port(pb_in_port),
	.write_strobe(pb_write_strobe), 
	.out_port(pb_out_port),
	.interrupt(pb_interrupt),
	.interrupt_ack(),
	.reset(pb_reset),
	.clk(clk100mhz)
 );
 
 
ram_interface_wrapper RAMRapper (
	.address(address),				// input 
	.data_in(RAMin), 					// input (16bits) obtained from codec
	.write_enable(enableWrite), 	//	input, enable when recording
	.read_request(reqRead), 		//	input, should be high to be 'playing'
	.read_ack(ackRead), 				//
	.data_out(RAMout), 				// output from ram to wire
	.reset(0), 
	.clk(clk), 
	.hw_ram_rasn(hw_ram_rasn), 
	.hw_ram_casn(hw_ram_casn),
	.hw_ram_wen(hw_ram_wen), 
	.hw_ram_ba(hw_ram_ba), 
	.hw_ram_udqs_p(hw_ram_udqs_p), 
	.hw_ram_udqs_n(hw_ram_udqs_n), 
	.hw_ram_ldqs_p(hw_ram_ldqs_p), 
	.hw_ram_ldqs_n(hw_ram_ldqs_n), 
	.hw_ram_udm(hw_ram_udm), 
	.hw_ram_ldm(hw_ram_ldm), 
	.hw_ram_ck(hw_ram_ck), 
	.hw_ram_ckn(hw_ram_ckn), 
	.hw_ram_cke(hw_ram_cke), 
	.hw_ram_odt(hw_ram_odt),
	.hw_ram_ad(hw_ram_ad), 
	.hw_ram_dq(hw_ram_dq), 
	.hw_rzq_pin(hw_rzq_pin), 
	.hw_zio_pin(hw_zio_pin), 
	.clkout(clk37), 
	.sys_clk(clk37), 
	.rdy(status), 
	.rd_data_pres(dataPresent),
	.max_ram_address(max_ram_address),
	
	.STATLED3(STATLED3),
	.STATLED4(STATLED4)
);


rs232_uart urt(
		.tx_data_in(pb_out_port), 
		.write_tx_data(write_to_uart), 
		.tx_buffer_full(uart_buffer_full),
		.rx_data_out(uart_rx_data),
		.read_rx_data_ack(read_from_uart),
		.rx_data_present(uart_data_present),
		.rs232_tx(rs232_tx),
		.rs232_rx(rs232_rx),
		.reset(uart_reset),
		.clk(clk100mhz)
);	


wire audio_clk;
// Audio Codec Interface Instantiation
sockit_top audio(
    .clk(clk100mhz),
	 .playback(playback),
	 .volume_control(volume_control),
    .AUD_ADCLRCK(AUD_ADCLRCK), 
    .AUD_ADCDAT(AUD_ADCDAT), 
    .AUD_DACLRCK(AUD_DACLRCK), 
    .AUD_DACDAT(AUD_DACDAT), 
    .AUD_XCK(AUD_XCK), 
    .AUD_BCLK(AUD_BCLK), 
    .AUD_I2C_SCLK(AUD_I2C_SCLK), 
    .AUD_I2C_SDAT(AUD_I2C_SDAT), 
    .AUD_MUTE(AUD_MUTE), 
    .PLL_LOCKED(PLL_LOCKED), 
    .KEY(1), 
    .SW(switches),
	 .audio_in(mem_out), 	//audio_input
	 .audio_out(audio_output),
	 .audio_clk(audio_clk)
);



// Memory FSMD
always@(posedge clk37)
begin
	//LEDRAM <= enableWrite;
	if(~reset) begin
		address <= 0;
	end
	
	else if(status)begin //led for status too
		case (state)
	//MAIN STATE
		8'h00: begin
		if(record)
			state <= 8'h01;
		else if(play && (address < max_ram_address)) begin
			address <= 0;
			state <= 8'h03;
		end
		else if(delete)
			state <= 8'h00;
		else if(pause)
			state <= 8'h06;
		else if(delete_all) begin
			address <= 0;
			state <= 8'h17;
		end
		else
			state <= 8'h00;
		
		count <= 0;		
		playback <= 0;
		end
		
		
		
		
	//RECORD STATE
		8'h11: begin
			address <= 0;
			state <= 8'h01;
		end
		
		8'h01: begin
			playback <= 0;
			LEDRAM <= 1'b0;
			if(count < 350) begin
				count <= count + 1;
				state <= 8'h01;
			end
			else if(record) begin
			RAMin <= audio_output;
			state <= 8'h12;
			end
			else begin
				state <= 8'h00;
				count <= 0;
				address <= 0;
			end
		end
		
		8'h12: begin
			enableWrite <= 1'b1;
			state <= 8'h02;
		end
		
		8'h02: begin
			count <= 0;
			enableWrite <= 1'b0;
			address <= address + 1;
			if(address >= max_ram_address) begin
				LEDRAM <= 1'b1;
				state <= 8'h00;
			end
			else	begin
				state <= 8'h01;
				STATLED2 <= 1;
			end
		end
		
		
		
		
		//PLAYBACK STATE
		8'h03: begin
			playback <= 1;
			if(play) 
				state <= 8'h14;
			else
				state <= 8'h00;
		end
			
			
		8'h14: begin
			if (count < 350) begin
				count <= count + 1;
				state <= 8'h14;
			end
			else state <= 8'h24;
			end
			
		8'h24: begin
			enableWrite <= 1'b0;
			reqRead <= 1'b1;			// was 1'b0
			state <= 8'h04;
		end
			
		8'h04: begin
			reqRead <= 1'b0;
			if(dataPresent) begin
				mem_out <= RAMout;
				ackRead <= 1'b1;
				state <= 8'h05;
			end
			
			else begin
				reqRead <= 1'b1;
				state <= 8'h04;
			end
		end
		
		8'h05: begin
			ackRead <= 1'b0;
			address <= address + 1;
			count <= 0;
			if (address >= max_ram_address) begin
				state <= 8'h00;
			end
			
			else
				state <= 8'h03;
		end
		
	//PAUSE
		8'h06: begin
			if(pause)
				state <= 8'h06;
			else if(play) 
				state <= 8'h03;
			else begin
				address <= 0;
				state <= 8'h00;
			end
		end
		
		
	//DELETE_ALL
	
		8'h17: begin
			address <= 0;
			state <= 8'h07;
		end
		
		8'h07: begin
			playback <= 0;
			if(delete_all) begin
			RAMin <= 0;
			state <= 8'h18;
			end
			
			else begin
				address <= 0;
				state <= 8'h00;
			end
		end
		
		8'h18: begin
			enableWrite <= 1'b1;
			state <= 8'h08;
		end
		
		8'h08: begin
			enableWrite <= 1'b0;
			address <= address + 1;
			if(address >= max_ram_address) begin
				LEDRAM <= 1'b0;
				deletedall <= 1;
				address <= 0;
				state <= 8'h00;
				end
				else	begin
					deletedall <= 0;
					state <= 8'h07;
				end
			end
		
		
	endcase
	end
end
	 

endmodule