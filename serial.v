`default_nettype none
// vim: set ft=verilog ts=4 sw=4 et:

`define START_FRAME_DELIMITER 64'haaaaaaaaaaaaaaab
`define HIGH_CYCLES 8
`define LOW_CYCLES 8
// HIGH_CYCLES >= HIGH_CYCLES_READ > HIGH_CYCLES/2
`define HIGH_CYCLES_READ 6

module sendBit(input wire clock, 
               input wire start,
               input wire data,
               output wire serialClock, serialData,
               output wire readyAtNext);
    reg [$bits(`HIGH_CYCLES+`LOW_CYCLES+1):0] count = 0;
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
            serialClockHistory <= 0;
        end
        if (ready) ready <= 0;
    end
endmodule

module sendFrame #(parameter WIDTH=16)
                (input wire clock, start,
                input wire [WIDTH-1:0] data,
                output wire serialClock, serialData,
                output reg readyAtNext = 0);
    reg startBit = 0;
    reg [$bits($bits(`START_FRAME_DELIMITER)+WIDTH-1)-1:0] i = 0;
    wire bitReadyAtNext;
    wire [$bits(`START_FRAME_DELIMITER)+WIDTH-1:0] frame = {`START_FRAME_DELIMITER, data};
    sendBit sendBit(clock, startBit, frame[i], serialClock, serialData, bitReadyAtNext);
    always @(posedge clock) begin
        if (start) begin
            i <= $bits(`START_FRAME_DELIMITER)+WIDTH-1;
            startBit <= 1;
        end
        if (i >= 1 && bitReadyAtNext) begin
            i <= i - 1;
            startBit <= 1;
        end
        if (startBit) startBit <= 0;
    end
endmodule

module receiveFrame #(parameter WIDTH=16)
                (input wire clock,
                input wire serialClock, serialData,
                output reg [WIDTH-1:0] data,
                output reg ready = 0);
    reg receiving = 0; // 1:receiving 0:seeking
    reg [63:0] seekBuffer = 0;
    reg [$bits(WIDTH-1)-1:0] i = 15;
    wire receiveReady, receiveData;
    receiveBit receive(clock, serialClock, serialData, receiveReady, receiveData);
    always @(posedge clock) begin
        if (!receiving && receiveReady) begin
            seekBuffer = {seekBuffer, receiveData};
            if (seekBuffer == `START_FRAME_DELIMITER) receiving <= 1;
        end else if (receiving && receiveReady) begin
            data[i] <= receiveData;
            if (i != 0) i <= i - 1;
            else begin
                ready <= 1;
                receiving <= 0;
            end
        end
        if (ready) ready <= 0;
    end
endmodule

