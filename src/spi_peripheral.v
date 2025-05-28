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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_counter       <= 5'd0;
            shift_reg         <= 16'd0;
            en_reg_out_7_0    <= 8'd0;
            en_reg_out_15_8   <= 8'd0;
            en_reg_pwm_7_0    <= 8'd0;
            en_reg_pwm_15_8   <= 8'd0;
            pwm_duty_cycle    <= 8'd0;
        end else begin
            if (ncs_falling_edge) begin
                bit_counter <= 5'd0;
                shift_reg   <= 16'd0;
            end else if (!nCS_sync2 && sclk_rising_edge && bit_counter < 16) begin
                shift_reg   <= {shift_reg[14:0], COPI_sync2};
                bit_counter <= bit_counter + 1;
            end else if (bit_counter == 16 && ncs_rising_edge) begin
                if (shift_reg[15]) begin
                    case (shift_reg[14:8])
                        7'h00: en_reg_out_7_0    <= shift_reg[7:0];
                        7'h01: en_reg_out_15_8   <= shift_reg[7:0];
                        7'h02: en_reg_pwm_7_0    <= shift_reg[7:0];
                        7'h03: en_reg_pwm_15_8   <= shift_reg[7:0];
                        7'h04: pwm_duty_cycle    <= shift_reg[7:0];
                        default: ; // Ignore invalid addresses
                    endcase
                end
                bit_counter <= 5'd0;
                shift_reg   <= 16'd0;
            end
        end
    end

endmodule
