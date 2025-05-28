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

    // Synchronizers
    reg nCS_sync1, nCS_sync2;
    reg SCLK_sync1, SCLK_sync2;
    reg COPI_sync1, COPI_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nCS_sync1   <= 1'b1;
            nCS_sync2   <= 1'b1;
            SCLK_sync1  <= 1'b0;
            SCLK_sync2  <= 1'b0;
            COPI_sync1  <= 1'b0;
            COPI_sync2  <= 1'b0;
        end else begin
            nCS_sync1   <= ncs;
            nCS_sync2   <= nCS_sync1;
            SCLK_sync1  <= sclk;
            SCLK_sync2  <= SCLK_sync1;
            COPI_sync1  <= copi;
            COPI_sync2  <= COPI_sync1;
        end
    end

    // Edge detection
    reg sclk_prev, nCS_prev;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_prev <= 1'b0;
            nCS_prev  <= 1'b1;
        end else begin
            sclk_prev <= SCLK_sync2;
            nCS_prev  <= nCS_sync2;
        end
    end

    wire sclk_rising_edge =  SCLK_sync2 && !sclk_prev;
    wire ncs_rising_edge  =  nCS_sync2  && !nCS_prev;
    wire ncs_falling_edge = !nCS_sync2  &&  nCS_prev;

    // SPI state
    reg [4:0] bit_counter;
    reg [15:0] shift_reg;
    reg write_pending;  // New: Flag to indicate a write is pending
    reg [7:0] write_data;  // New: Store data to write
    reg [6:0] write_addr;  // New: Store address to write

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_counter <= 5'd0;
            shift_reg <= 16'd0;
            write_pending <= 1'b0;
            write_data <= 8'd0;
            write_addr <= 7'd0;
            en_reg_out_7_0 <= 8'd0;
            en_reg_out_15_8 <= 8'd0;
            en_reg_pwm_7_0 <= 8'd0;
            en_reg_pwm_15_8 <= 8'd0;
            pwm_duty_cycle <= 8'd0;
        end else begin
            // Clear write_pending when CS goes high (transaction complete)
            if (ncs_rising_edge) begin
                write_pending <= 1'b0;
            end

            // Start of new transaction
            if (ncs_falling_edge) begin
                bit_counter <= 5'd0;
                shift_reg <= 16'd0;
            end 
            // Shift in data on rising edge of SCLK when CS is active low
            else if (!nCS_sync2 && sclk_rising_edge) begin
                if (bit_counter < 16) begin
                    shift_reg <= {shift_reg[14:0], COPI_sync2};
                    bit_counter <= bit_counter + 1;

                    // If we've received all 16 bits
                    if (bit_counter == 15) begin
                        // Check if it's a write command (MSB = 1)
                        if ({shift_reg[14:0], COPI_sync2}[15]) begin
                            write_pending <= 1'b1;
                            write_addr <= {shift_reg[13:8], COPI_sync2};
                            write_data <= shift_reg[7:0];
                        end
                    end
                end
            end

            // Process write immediately when all bits received
            if (write_pending) begin
                case (write_addr)
                    7'h00: en_reg_out_7_0 <= write_data;
                    7'h01: en_reg_out_15_8 <= write_data;
                    7'h02: en_reg_pwm_7_0 <= write_data;
                    7'h03: en_reg_pwm_15_8 <= write_data;
                    7'h04: pwm_duty_cycle <= write_data;
                    default: ; // Ignore invalid addresses
                endcase
                write_pending <= 1'b0;
            end
        end
    end

endmodule
