`default_nettype none
`define assert(condition) if(!((|{condition})===1)) begin $display("FAIL"); $finish(1); end

// vim: set ft=verilog ts=4 sw=4 et:


module testSerial;
    reg sendClock = 0, receiveClock = 0, start = 0;
    reg [15:0] sendData = 16'b0111011010100101;
    wire [7:0] receiveWord;
    reg [15:0] receiveData = 0;
    wire [0:0] receiveIndex;
    wire [0:0] sendIndex;
    wire sampleReady;
    wire serialClock, serialData, sendReadyAtNext, receiveReady;

    always begin
        #3 receiveClock <= !receiveClock;
        #7 sendClock <= !sendClock;
    end

    sendFrame #(8) sendFrame(sendClock, start, sendIndex, sendData[sendIndex*8 +: 8], serialClock, serialData, sendReadyAtNext);
    receiveFrame #(8) receiveFrame(.clock(receiveClock), .serialClock(serialClock), .serialData(serialData), .data(receiveWord), .ready(receiveReady), .index(receiveIndex), .sampleReady(sampleReady));

    initial begin
        $dumpfile("serial.vcd");
        $dumpvars(1, sendClock, receiveClock, serialClock, serialData, receiveReady, receiveWord, receiveData, sendIndex, receiveIndex, sendReadyAtNext, sampleReady);
    end

    always @(posedge sendClock) begin
        if (sendReadyAtNext) begin
            #400
            start <= 1;
            sendData <= sendData + 1;
        end
        if (start) start <= 0;
    end

    always @(posedge receiveClock) begin
        if (sampleReady) begin
            receiveData[receiveIndex*8 +: 8] = receiveWord;
        end
        if (receiveReady) begin
            $display("0b%b ==\n0b%b", receiveData, sendData);
            `assert(receiveData === sendData)
            #20000 $finish;
        end
    end
endmodule
