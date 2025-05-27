module spi_peripheral (
    input wire clk,
    input wire rst_n,

    input wire sclk,
    input wire ncs,
    input wire copi,

    output reg [7:0] en_reg_out_7_0,
    output reg [7:0] en_reg_out_15_8,
    output reg [7:0] en_reg_pwm_7_0,
    output reg [7:0] en_reg_pwm_15_8,
    output reg [7:0] pwm_duty_cycle
);

    reg nCS_sync1, nCS_sync2;
    reg SCLK_sync1, SCLK_sync2;
    reg COPI_sync1, COPI_sync2;

    // Synchronize SPI signals to the clock domain
    // This is necessary to avoid metastability issues when the SPI signals are sampled by the clock
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin  
            nCS_sync1 <= 1'b1;
            nCS_sync2 <= 1'b1;
            SCLK_sync1 <= 1'b0;
            SCLK_sync2 <= 1'b0;
            COPI_sync1 <= 1'b0;
            COPI_sync2 <= 1'b0;
        end 
        
        else begin
            nCS_sync1 <= nCS;
            nCS_sync2 <= nCS_sync1;
            SCLK_sync1 <= sclk;
            SCLK_sync2 <= SCLK_sync1;
            COPI_sync1 <= copi;
            COPI_sync2 <= COPI_sync1;
        end
    end

    // detect edges on SCLK
    reg sclk_prev; 
    reg nCS_prev;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_prev <= 1'b0;
            nCS_prev <= 1'b1;
        end else begin
            sclk_prev <= SCLK_sync2;
            nCS_prev <= nCS_sync2;
        end
    end

    wire sclk_rising_edge = SCLK_sync2 && !sclk_prev;
    wire sclk_falling_edge = !SCLK_sync2 && sclk_prev;

    wire ncs_rising_edge = nCS_sync2 && !nCS_prev;
    wire ncs_falling_edge = !nCS_sync2 && nCS_prev;

    //Bit counter
    //Shift register logic
    reg [4:0] bit_counter;
    reg [15:0] shift_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_counter <= 5'b0;
            shift_reg <= 16'b0;
        end else if (!nCS_sync2) begin //Transaction is active
            if (sclk_rising_edge) begin
                shift_reg <= {shift_reg[14:0], COPI_sync2}; // Shift in the new bit
                bit_counter <= bit_counter + 1;
            end
        end else if (ncs_rising_edge) begin //Transaction is complete
            if (bit_counter == 16) begin // process the received data
                if (shift_reg[15]) begin //Write
                    case (shift_reg[14:8])
                        7'h00: en_reg_out_7_0   <= shift_reg[7:0];
                        7'h01: en_reg_out_15_8  <= shift_reg[7:0];
                        7'h02: en_reg_pwm_7_0   <= shift_reg[7:0];
                        7'h03: en_reg_pwm_15_8  <= shift_reg[7:0];
                        7'h04: pwm_duty_cycle   <= shift_reg[7:0];
                        default: ; // ignore invalid addresses
                    endcase
                end
            end
            //Reset the bit counter and shift register
            bit_counter <= 5'b0;
            shift_reg <= 16'b0;
        end
    end
endmodule