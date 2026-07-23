`timescale 1ns/1ps

module i2c_master_tb;

    reg clk,rst,start,rw;
    reg [6:0] address;
    reg [7:0] data_in;
    wire [7:0] data_out;
    wire busy,done,ack_error,sda,scl;
    assign sda = (sda === 1'bz) ? 1'b0 : 1'bz;

    i2c_master #(.CLK_FREQ(50_000_000),.I2C_FREQ(100_000)) UUT (
        .clk(clk),
        .rst(rst),
        .start(start),
        .rw(rw),
        .address(address),
        .data_in(data_in),
        .data_out(data_out),
        .busy(busy),
        .done(done),
        .ack_error(ack_error),
        .sda(sda),
        .scl(scl));
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    initial begin
        rst = 1; start = 0; rw = 0;          // Write
        address = 7'h50;
        data_in = 8'hA5;
        #100; rst = 0;
        // Start transaction
        #100; start = 1;
        #20; start = 0;
        wait(done);#100;
        $display("ACK Error = %b", ack_error);
        $display("Data Out  = %h", data_out);#100;
    end

    initial begin
        $monitor("Time=%0t  State Busy=%b Done=%b SDA=%b SCL=%b ACK=%b",
                 $time, busy, done, sda, scl, ack_error);
    end

endmodule