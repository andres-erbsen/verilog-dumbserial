`default_nettype none
`define assert(condition) if(!((|{condition})===1)) begin $display("FAIL"); $finish(1); end

// vim: set ft=verilog ts=4 sw=4 et:


module testSerial;
    reg sendClock = 0, receiveClock = 0, start = 0;
    reg [15:0] sendData = 16'b0111011010100101;
    wire [15:0] receiveData;
    wire serialClock, serialData, sendReadyAtNext, receiveReady;

    always begin
        #3 receiveClock <= !receiveClock;
        #7 sendClock <= !sendClock;
    end

    sendFrame sendFrame(sendClock, start, sendData, serialClock, serialData, sendReadyAtNext);
    receiveFrame receiveFrame(receiveClock, serialClock, serialData, receiveData, receiveReady);

    initial begin
        $dumpfile("serial.vcd");
        $dumpvars(1, sendClock, receiveClock, serialClock, serialData);
        #40 start = 1;
        #20 start = 0;
    end

    always @(posedge receiveClock) begin
        if (receiveReady) begin
            $display("0b%b ==\n0b%b", receiveData, sendData);
            `assert(receiveData === sendData)
            $finish;
        end
    end
endmodule