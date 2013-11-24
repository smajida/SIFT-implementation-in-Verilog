module GAUSSIAN #(
	parameter 	K1 = 6,
			  	K2 = 58,
				K3 = 128)
		   (input Clk,
			input [7:0] din,
			input Reset,
			input Clk_en,
			output [7:0] dout);

	reg [7:0] sra;
	reg [15:0] srb, src_a, src_b , srd_a, srd_b;
	
	wire [7:0] out_stage_1;
	wire  [15:0] A, B, C, D, E;

	
	initial begin
		sra <= 8'd0;
		srb <= 16'd0;
		src_a <= 16'd0;
		src_b <= 16'd0;
		srd_a <= 16'd0;
		srd_b <= 16'd0;
	end

	assign A = din * K1;
	assign B = sra * K2;
	assign C = srb * K3;
	assign D = src_b;
	assign E = srd_b;

	assign out_stage_1 = ( A + B + C + D + E ) >> 8;

	always @(posedge Clk) begin
		if (Reset) begin
			sra <= 8'd0;
			srb <= 16'd0;
			src_a <= 16'd0;
			src_b <= 16'd0;
			srd_a <= 16'd0;
			srd_b <= 16'd0;
		end
		else begin
			if (Clk_en) begin
				sra <= din;
				srd_a <= A;
				srd_b <= srd_a;
				srb <= sra;
				src_a <= B;
				src_b <= src_a;
			end
		end
	end

	wire  [15:0] a2, b2, c2, d2, e2, sra_2, srb_2, src_2, srd_2;

	assign dout = ( a2 + b2 + c2 + d2 + e2 ) >> 8;
	
	assign a2 = out_stage_1 * K1; 
	assign b2 = sra_2 * K2;
	assign c2 = srb_2 * K3;
	assign d2 = src_2;
	assign e2 = srd_2;

	shiftreg8x400 srA2 (
		.clk(clock),
		.ce(Clk_en),
		.sclr(reset),
		.d(out_stage_1),
		.q(sra_2));

	shiftreg16x400 srB2 (
		.clk(clock),
		.ce(Clk_en),
		.sclr(reset),
		.d(shift_out_1_b),
		.q(srb_2));

	shiftreg16x800 srC2 (
		.clk(clock),
		.ce(Clk_en),
		.sclr(reset),
		.d(b2),
		.q(src_2));

	shiftreg16x800 srD2 (
		.clk(clock),
		.ce(Clk_en),
		.sclr(reset),
		.d(a2),
		.q(srd_2));

endmodule