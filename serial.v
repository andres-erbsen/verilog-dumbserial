`default_nettype none
// vim: set ft=verilog ts=4 sw=4 et:

`define START_FRAME_DELIMITER 8'haaaaaaaaaaaaaaab
`define START_FRAME_DELIMITER_BITS 8
`define HIGH_CYCLES 8
`define LOW_CYCLES 8
`define CYCLE_COUNTER_WIDTH 5
// HIGH_CYCLES >= HIGH_CYCLES_READ > HIGH_CYCLES/2
`define HIGH_CYCLES_READ 6

module sendBit(input wire clock, 
               input wire start,
               input wire data,
               output wire serialClock, serialData,
               output wire readyAtNext);
    reg [`CYCLE_COUNTER_WIDTH-1:0] count = 0;
    always @(posedge clock) begin 
        if (start) count <= `HIGH_CYCLES + `LOW_CYCLES - 1;
        else if (count != 0) count <= count - 1;
    end
    assign readyAtNext = (!start) && count <= 1;
    assign serialClock = count >= `LOW_CYCLES;
    assign serialData  = serialClock & data;
endmodule

module receiveBit(input wire clock, serialClock, serialData,
                  output reg ready = 0, output reg data = 0);
    reg [`HIGH_CYCLES_READ-1:0] serialClockHistory = 0;
    always @(posedge clock) begin
        serialClockHistory = {serialClockHistory, serialClock};
        if (&serialClockHistory) begin
            ready <= 1;
            data <= serialData;
            serialClockHistory = 0;
        end
        if (ready) ready <= 0;
    end
endmodule

module sendFrame #(parameter WIDTH=16, LOGSIZE=1)
                (input wire clock, start,
                output reg [LOGSIZE-1:0] index = (1<<LOGSIZE)-1,
                input wire [WIDTH-1:0] data,
                output wire serialClock, serialData,
                output reg readyAtNext = 0);
    reg startBit = 0;
    reg [15:0] i = 0;
    wire bitReadyAtNext;
    wire [`START_FRAME_DELIMITER_BITS+WIDTH-1:0] frame = {`START_FRAME_DELIMITER, data};
    sendBit sendBit(clock, startBit, frame[i], serialClock, serialData, bitReadyAtNext);
    always @(posedge clock) begin
        if (start) begin
            i <= `START_FRAME_DELIMITER_BITS+WIDTH-1;
            startBit <= 1;
            index <= 0;
        end
        if (bitReadyAtNext) begin
            if (i >= 1) begin
                i <= i - 1;
                startBit <= 1;
            end
            if (i == 0 && ~(&index)) begin // NOT end of packet
                index <= index + 1;
                i <= WIDTH-1;
                startBit <= 1;
            end
        end
        if (startBit) startBit <= 0;
    end
endmodule

module receiveFrame #(parameter WIDTH=16, LOGSIZE=1)
                (input wire clock,
                input wire serialClock, serialData,
                output reg [WIDTH-1:0] data=0,
                output reg ready = 0,
                output reg [LOGSIZE-1:0] index = 0,
                output reg [15:0] i = WIDTH-1);
    reg receiving = 0; // 1:receiving 0:seeking
    reg [`START_FRAME_DELIMITER_BITS-1:0] seekBuffer = 0;
    wire receiveReady, receiveData;
    receiveBit receive(clock, serialClock, serialData, receiveReady, receiveData);
    always @(posedge clock) begin
        if (!receiving && receiveReady) begin
            seekBuffer = {seekBuffer, receiveData};
            if (seekBuffer == `START_FRAME_DELIMITER) begin
                receiving <= 1;
                seekBuffer = 0;
                i <= WIDTH-1;
                index <= 0;
            end
        end else if (receiving && receiveReady) begin
            data[i] <= receiveData;
            if (i != 0) i <= i - 1;
            else begin
                i <= WIDTH-1;
                if (&index) begin // end of packet
                    ready <= 1;
                    receiving <= 0;
                end else begin 
                    index <= index + 1;
                end
            end
        end
        if (ready) ready <= 0;
    end
endmodule

