module SramArbiter(
// Application interface
input reset,
output [2:0]  theState,

// W0
input         w0_clock,
output        w0_din_ready,
input         w0_din_valid,
input [53:0]  w0_din,// {mask,addr,data}

// W1
input         w1_clock,
output        w1_din_ready,
input         w1_din_valid,
input [53:0]  w1_din,// {mask,addr,data}

// R0
input         r0_clock,
output        r0_din_ready,
input         r0_din_valid,
input  [17:0] r0_din, // addr
input         r0_dout_ready,
output        r0_dout_valid,
output [31:0] r0_dout, // data

// R1
input         r1_clock,
output        r1_din_ready,
input         r1_din_valid,
input  [17:0] r1_din, // addr
input         r1_dout_ready,
output        r1_dout_valid,
output [31:0] r1_dout, // data

// SRAM Interface
input         sram_clock,
output        sram_addr_valid,
input         sram_ready,
output [17:0] sram_addr,
output [31:0] sram_data_in,
output  [3:0] sram_write_mask,
input  [31:0] sram_data_out,
input         sram_data_out_valid);

//Signals the writer that the fifo is full and should not
//be written to
wire w0_full_signal;
wire w1_full_signal;
assign w0_din_ready = ~w0_full_signal;
assign w1_din_ready = ~w1_full_signal;

//Unused
wire r0_dout_empty;
wire r1_dout_empty;

//Signals the reader that the fifo is full and should not 
//have any more address requests (should be kept full at
// all times.)
wire r0_addr_full;
wire r1_addr_full;
assign r0_din_ready = !r0_addr_full;
assign r1_din_ready = !r1_addr_full;

//Signals from w0_fifo to the arbiter
wire rd_en_w0; //output
wire valid_w0; //input
wire [53:0] dout_w0; //input

//Signals from w1_fifo to the arbiter
wire rd_en_w1; //output
wire valid_w1; //input
wire [53:0] dout_w1; //input

//Signals from r0_addr_fifo to arbiter
wire rd_en_r0; //output
wire valid_r0; //input
wire [17:0] r0_addr; //input

//Signals from arbiter to r0_data_fifo
wire r0_data_wr_en; //output
wire r0_data_full; //input

//Signals from r1_addr_fifo to arbiter
wire rd_en_r1; //output
wire valid_r1; //input
wire [17:0] r1_addr; //input

//Signals from arbiter to r1_data_fifo
wire r1_data_wr_en; //output
wire r1_data_full; //input

reg delay0;
reg delay1;
reg delay2;
reg outputreg;


// Clock crossing FIFOs --------------------------------------------------------

SRAM_WRITE_FIFO w0_fifo(
    //On Write side
    .rst(reset), //global reset
    .wr_clk(w0_clock),
    .din(w0_din),
    .wr_en(w0_din_valid),
    .full(w0_full_signal), //Assign the full to a register so the inverted output
                           //can be sent out as w0_din_ready

    //On Arbiter side
    .rd_clk(sram_clock),
    .rd_en(rd_en_w0),
    .valid(valid_w0),
    .dout(dout_w0),
    .empty());

SRAM_WRITE_FIFO w1_fifo(
    //On Write side
    .rst(reset), //global reset
    .wr_clk(w1_clock),
    .din(w1_din),
    .wr_en(w1_din_valid),
    .full(w1_full_signal), //Assign the full to a register so the inverted output
                           //can be sent out as w1_din_ready

    //On Arbiter side
    .rd_clk(sram_clock),
    .rd_en(rd_en_w1),
    .valid(valid_w1),
    .dout(dout_w1),
    .empty());

// Instantiate the Read FIFOs here
SRAM_ADDR_FIFO r0_addr_fifo (
    //On Read side
    .rst(reset),
    .wr_clk(r0_clock),
    .din(r0_din),
    .wr_en(r0_din_valid),
    .full(r0_addr_full),

    //On Arbiter side
    .rd_clk(sram_clock),
    .rd_en(rd_en_r0),
    .valid(valid_r0),
    .dout(r0_addr),
    .empty());

SRAM_DATA_FIFO r0_data_fifo (
    //On Arbiter side
    .rst(reset),
    .wr_clk(sram_clock),
    .din(sram_data_out),
    .wr_en(r0_data_wr_en),
    .prog_full(r0_data_full),

    //On Read side
    .rd_clk(r0_clock),
    .rd_en(r0_dout_ready),
    .valid(r0_dout_valid),
    .dout(r0_dout),
    .empty()); 

SRAM_ADDR_FIFO r1_addr_fifo (
    //On Read side
    .rst(reset),
    .wr_clk(r1_clock),
    .din(r1_din),
    .wr_en(r1_din_valid),
    .full(r1_addr_full),

    //On Arbiter side
    .rd_clk(sram_clock),
    .rd_en(rd_en_r1),
    .valid(valid_r1),
    .dout(r1_addr),
    .empty());

SRAM_DATA_FIFO r1_data_fifo (
    //On Arbiter side
    .rst(reset),
    .wr_clk(sram_clock),
    .din(sram_data_out),
    .wr_en(r1_data_wr_en),
    .prog_full(r1_data_full),

    //On Read side
    .rd_clk(r1_clock),
    .rd_en(r1_dout_ready),
    .valid(r1_dout_valid),
    .dout(r1_dout),
    .empty());

// Arbiter Logic ---------------------------------------------------------------

// Put your round-robin arbitration logic here

//State encoding
localparam  STATE_IDLE = 3'd0,
            STATE_W0 = 3'd1,
            STATE_W1 = 3'd2,
            STATE_R0 = 3'd3,
            STATE_R1 = 3'd4;

//State reg declarations
reg [2:0] CurrentState;
reg [2:0] NextState;

assign theState = CurrentState;

always@(posedge sram_clock) begin
    if (reset) begin
        CurrentState <= STATE_IDLE;
        delay1 <= 1'b0;
        delay2 <= 1'b0;
        outputreg <= 1'b0;
    end
    else begin
        CurrentState <= NextState;
	delay1 <= delay0;
        delay2 <= delay1;
        outputreg <= delay2;
    end
end 

//Next state handling
always@(*) begin
    case (CurrentState)
        STATE_IDLE: begin
            if (valid_w0) begin
                NextState = STATE_W0;
            end
            else if (valid_w1) begin
                NextState = STATE_W1;
            end
            else if (valid_r0 & ~r0_data_full) begin
                NextState = STATE_R0;
            end
            else if (valid_r1 & ~r1_data_full) begin
                NextState = STATE_R1;
            end
            else begin
                NextState = STATE_IDLE;
            end
        end
        STATE_W0: begin
            if (valid_w1) begin
                NextState = STATE_W1;
            end
            else if (valid_r0 & ~r0_data_full) begin
                NextState = STATE_R0;
            end
            else if (valid_r1 & ~r1_data_full) begin
                NextState = STATE_R1;
            end
            else begin
                NextState = STATE_IDLE;
            end
        end
        STATE_W1: begin
            if (valid_r0 & ~r0_data_full) begin
                NextState = STATE_R0;
            end
            else if (valid_r1 & ~r1_data_full) begin
                NextState = STATE_R1;
            end
            else if (valid_w0) begin
                NextState = STATE_W0;
            end
            else begin
                NextState = STATE_IDLE;
            end
        end
        STATE_R0: begin
            delay0 = 1'b0;

            if (valid_r1 & ~r1_data_full) begin
                NextState = STATE_R1;
            end
            else if (valid_w0) begin
                NextState = STATE_W0;
            end
            else if (valid_w1) begin
                NextState = STATE_W1;
            end
	        else begin
                NextState = STATE_IDLE;
            end
        end
        STATE_R1: begin
            delay0 = 1'b1;

            if (valid_w0) begin
                NextState = STATE_W0;
            end
            else if (valid_w1) begin
                NextState = STATE_W1;
            end
            else if (valid_r0 & ~r0_data_full) begin
                NextState = STATE_R0;
            end
            else begin
                NextState = STATE_IDLE;
            end
        end
        default: begin
            NextState = STATE_IDLE;
        end
    endcase
end

//Handling returning the data to r0 and r1
//CURRENTLY FORCED TO WORK, NOT SET UP RIGHT.
assign r0_data_wr_en = (sram_data_out_valid && !outputreg);
assign r1_data_wr_en = (sram_data_out_valid && outputreg);

assign rd_en_w0 = (CurrentState == STATE_W0);
assign rd_en_w1 = (CurrentState == STATE_W1);
assign rd_en_r0 = (CurrentState == STATE_R0);
assign rd_en_r1 = (CurrentState == STATE_R1);
assign sram_addr_valid = (CurrentState == STATE_W0 || CurrentState == STATE_W1 || CurrentState == STATE_R0 || CurrentState == STATE_R1);

assign sram_data_in = (CurrentState == STATE_W0) ? dout_w0[31:0] : dout_w1[31:0];
assign sram_write_mask = (CurrentState == STATE_W0) ? dout_w0[53:50] : ((CurrentState == STATE_W1) ? dout_w1[53:50] : 4'b0000);
assign sram_addr = (CurrentState == STATE_W0) ? dout_w0[49:32] : ((CurrentState == STATE_W1) ? dout_w1[49:32] : ((CurrentState == STATE_R0) ? r0_addr : ((CurrentState == STATE_R1) ? r1_addr : 0)));


endmodule
