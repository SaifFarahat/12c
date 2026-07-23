`timescale 1ns/1ps
module i2c_master
#(
    parameter CLK_FREQ = 50000000,
    parameter I2C_FREQ = 100000
)
(
    input wire clk,rst,start,rw,
    input wire [6:0] address,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    output reg busy,done,ack_error,
    inout wire sda,
    output wire scl
);

// Clock Divider
localparam DIVIDER = CLK_FREQ/(I2C_FREQ*4);
reg [15:0] div_cnt;
reg scl_clk;

assign scl = busy ? scl_clk : 1'b1;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        div_cnt <= 0;
        scl_clk <= 1;
    end
    else
    begin
        if(div_cnt == DIVIDER-1)
        begin
            div_cnt <= 0;
            scl_clk <= ~scl_clk;
        end
        else
            div_cnt <= div_cnt + 1;
    end
end

// Open Drain SDA
reg sda_drive;
reg sda_out;

assign sda = sda_drive ? sda_out : 1'bz;
wire sda_in = sda;

// FSM States
localparam IDLE        = 0;
localparam START       = 1;
localparam SEND_ADDR   = 2;
localparam ADDR_ACK    = 3;
localparam WRITE_DATA  = 4;
localparam WRITE_ACK   = 5;
localparam READ_DATA   = 6;
localparam READ_ACK    = 7;
localparam STOP        = 8;
localparam FINISH      = 9;
reg [3:0] state;
reg [7:0] shift_reg;
reg [2:0] bit_cnt;

// FSM
always @(posedge scl_clk or posedge rst)
begin

    if(rst)
    begin
        state <= IDLE;

        busy <= 0;
        done <= 0;
        ack_error <= 0;

        sda_drive <= 1;
        sda_out <= 1;

        data_out <= 0;
    end

    else
    begin

        done <= 0;

        case(state)
        IDLE: begin
            busy <= 0;
            sda_drive <= 1;
            sda_out <= 1;
            if(start) begin
                busy <= 1;
                ack_error <= 0;
                state <= START;
            end
        end
        START: begin
            sda_out <= 0;
            shift_reg <= {address,rw};
            bit_cnt <= 7;
            state <= SEND_ADDR;
        end
        SEND_ADDR: begin
            sda_drive <= 1;
            sda_out <= shift_reg[bit_cnt];

            if(bit_cnt==0)
                state <= ADDR_ACK;
            else
                bit_cnt <= bit_cnt-1;
        end
        ADDR_ACK: begin
            sda_drive <= 0;
            if(sda_in)
                ack_error <= 1;
            if(rw==0) begin
                shift_reg <= data_in;
                bit_cnt <= 7;
                state <= WRITE_DATA;
            end
            else begin
                bit_cnt <= 7;
                data_out <= 0;
                state <= READ_DATA;
            end
        end
        WRITE_DATA: begin
            sda_drive <= 1;
            sda_out <= shift_reg[bit_cnt];
            if(bit_cnt==0)
                state <= WRITE_ACK;
            else
                bit_cnt <= bit_cnt-1;
        end
        WRITE_ACK: begin
            sda_drive <= 0;
            if(sda_in)
                ack_error <= 1;
            state <= STOP;
        end

        READ_DATA: begin
            sda_drive <= 0;
            data_out[bit_cnt] <= sda_in;
            if(bit_cnt==0)
                state <= READ_ACK;
            else
                bit_cnt <= bit_cnt-1;
        end

        READ_ACK: begin
            sda_drive <= 1;
            sda_out <= 1;
            state <= STOP;
        end

        STOP: begin
            sda_drive <= 1;
            sda_out <= 0;
            state <= FINISH;
        end

        FINISH: begin
            sda_out <= 1;
            busy <= 0;
            done <= 1;
            state <= IDLE;
        end
        endcase

    end

end

endmodule