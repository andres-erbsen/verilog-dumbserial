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
    wire serialClock, serialData, sendReadyAtNext, receiveReady;

    always begin
        #3 receiveClock <= !receiveClock;
        #7 sendClock <= !sendClock;
    end

    sendFrame #(8) sendFrame(sendClock, start, sendIndex, sendIndex == 0 ? sendData[15:8] : sendData[7:0], serialClock, serialData, sendReadyAtNext);
    receiveFrame #(8) receiveFrame(.clock(receiveClock), .serialClock(serialClock), .serialData(serialData), .data(receiveWord), .ready(receiveReady), .index(receiveIndex));

    initial begin
        $dumpfile("serial.vcd");
        $dumpvars(1, sendClock, receiveClock, serialClock, serialData, receiveReady, receiveData, sendIndex, receiveIndex);
        #80 start = 1;
        #20 start = 0;
    end

    always @(posedge receiveClock) begin
        if (receiveIndex == 0) receiveData[15:8] = receiveWord;
        if (receiveIndex == 1) receiveData [7:0] = receiveWord;
        if (receiveReady) begin
            $display("0b%b ==\n0b%b", receiveData, sendData);
            `assert(receiveData === sendData)
            $finish;
        end
    end
endmodule
