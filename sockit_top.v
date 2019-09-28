//
// Demo of Analog Devices SSM2603 audio codec
// Digilent Anvyl Board
// Source: Github: https://github.com/zhemao/rtaudio_effects/tree/part8
// https://zhehaomao.com/blog/fpga/2014/01/15/sockit-8.html
//
// Srinivas Katkoori 20 Apr 2018
//
// To hear the results of the test hardware on the FPGA, 
// plug your speakers into the green audio port 
// and the microphone into the pink audio port. Flip SW7 
// to hear the sine wave and SW6 to hear the microphone feedback. 
// If you are using headphones, strongly suggest that 
// you do not actually put them on in the sine wave mode, 
// as the volume at 0 dB is quite loud.
//  SW7 - Pure tone mode
//  SW6 - Feedback mode
//  SW0 - Active Low Reset


module sockit_top (
	 input  clk,
	 input playback,
	 input	[1:0] volume_control,
    inout  AUD_ADCLRCK,
    input  AUD_ADCDAT,


    inout  AUD_DACLRCK,
    output AUD_DACDAT,

    output AUD_XCK,
    inout  AUD_BCLK,

    output AUD_I2C_SCLK,
    inout  AUD_I2C_SDAT,

    output AUD_MUTE,
	 output PLL_LOCKED,
	 
    input  [3:0] KEY,
    input  [3:0] SW,
    //output [3:0] LED,
	 
	 output [15:0] audio_out,
	 input  [15:0] audio_in,
	 
	 output audio_clk
	 //output [1:0]sample_end,
	 //output [1:0]sample_req
);

//wire [15:0] audio_out;
reg [15:0] audio_selection;
wire [15:0] audio_output;
wire [15:0] audio_input;

assign audio_out = audio_output;

always @(posedge audio_clk) begin
	if(playback) begin
		audio_selection <= audio_in * volume_control;
	end
	else begin
		audio_selection <= audio_output * volume_control;
	end
end

wire reset = !KEY[0];
wire main_clk;
//wire audio_clk;

wire [1:0] sample_end; // write to internal register
wire [1:0] sample_req; // take the audio input


// Clock PLL that synthesizes two frequencies: 50 MHz and 11.2896 MHz
// Input 100 MHz 
clk_wiz_v3_6 pll (
	 .CLK_IN1 (clk),
	 .CLK_OUT1 (main_clk),   // 50 MHz
    .CLK_OUT2 (audio_clk),  // 11.2896 MHz
	 .RESET (reset),
	 .LOCKED (PLL_LOCKED)
);

// I2C Protocol - FPGA is Master, Codec is Slave
i2c_av_config av_config (
    .clk (main_clk),
    .reset (reset),
    .i2c_sclk (AUD_I2C_SCLK),
    .i2c_sdat (AUD_I2C_SDAT),
    .status (LED)
);

assign AUD_XCK = audio_clk;
assign AUD_MUTE = 1'b1;  // active low, so set to 1 and disable mute

// Serial to parallel conversion 
audio_codec ac (
    .clk (audio_clk),
    .reset (reset),
	 .volume_control(volume_control),
    .sample_end (sample_end),
    .sample_req (sample_req),
    .audio_output (audio_selection),
    .audio_input (audio_input),
    .channel_sel (2'b10),
    .AUD_ADCLRCK (AUD_ADCLRCK),
    .AUD_ADCDAT (AUD_ADCDAT),
    .AUD_DACLRCK (AUD_DACLRCK),
    .AUD_DACDAT (AUD_DACDAT),
    .AUD_BCLK (AUD_BCLK)
);

// Audio source
// (1) Sine wave mode (tone)  SW7 UP
// (2) Playback mode (feedback from LINE IN to LINE OUT) SW6 UP

audio_effects ae (
	  .clk (audio_clk),
    .sample_end (sample_end[1]),
    .sample_req (sample_req[1]),
	 .volume_control(volume_control),
    .audio_output (audio_output),
    .audio_input  (audio_input),
    .control (SW)
);

endmodule
