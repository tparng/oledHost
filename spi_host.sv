//-----------------------------------------------------------------------------
// Title         : Oled_host Sample IP for PULP-Training IP Integration Exercise
//-----------------------------------------------------------------------------
// File          : oled.sv
// Author        : Parng
// Created       : 14.09.2022
//-----------------------------------------------------------------------------
// Description :
//
//-----------------------------------------------------------------------------
// Copyright (C) 2013-2020 ETH Zurich, University of Bologna
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//-----------------------------------------------------------------------------

module spi_host
    import spi_host_pkg::optype_e;
    import spi_host_pkg::status_e;
    (
     input logic                            clk_i,
     input logic                            rst_ni,
     input logic                            send_start_i,
     input logic [7:0]                      send_data_i,
     output                                 send_ready_o,
     output                                 nCS_o,
     output                                 SDO_o,
     output                                 SCLK_o
     );
    localparam  IDLE   = 0,
                SEND   = 1,
                HOLDCS = 2,
                HOLD   = 3;
    localparam  COUNTER_MID = 4,
                COUNTER_MAX = 9,
                SCLK_DUTY = 5;
    logic [2:0]   state_e = IDLE;
    logic [7:0]   shift_register=0;
    logic [3:0]   shift_counter=0;
    logic [4:0]   counter=0;
    logic         temp_sdo;
    
    assign SCLK_o = (counter < SCLK_DUTY) | nCS_o;
    assign SDO_o = temp_sdo | nCS_o | (state_e == HOLDCS ? 1'b1 : 1'b0);
    assign nCS_o = ((state_e != SEND && state_e != HOLDCS) ? 1'b1 : 1'b0) | !rst_ni;	//nCs is active low
    assign send_ready_o = ((state_e == IDLE && send_start_i == 1'b0) ? 1'b1 : 1'b0) & rst_ni;

    always_ff@(posedge clk_i, negedge rst_ni)
        if (!rst_ni)
            state_e <= IDLE;
    else
        case (state_e)
        IDLE: begin
            if (send_start_i == 1'b1)
                state_e <= SEND;
        end
        SEND: begin
            if (shift_counter == 8 && counter == COUNTER_MID) begin
                state_e <= HOLDCS;
            end
        end
        HOLDCS: begin
            if (shift_counter == 4'd3)
                state_e <= HOLD;
        end
        HOLD: begin
            if (send_start == 1'b0)
                state_e <= IDLE;
        end
        endcase

    always_ff@(posedge clk, negedge rst_ni)
        if (!rst_ni)
            counter <= 0;
    else if (state_e == SEND && ~(counter == COUNTER_MID && shift_counter == 8)) begin
            if (counter == COUNTER_MAX)
                counter <= 0;
            else
                counter <= counter + 1'b1;
        end else
            counter <= 'b0;
    
    always_ff@(posedge clk, negedge rst_ni)
        if (!rst_ni || state_e == IDLE) begin
            shift_counter <= 'b0;
            shift_register <= send_data_i;
            temp_sdo <= 1'b1;
        end
        else if (state_e == SEND) begin
            if (counter == COUNTER_MID) begin
                temp_sdo <= shift_register[7];
                shift_register <= {shift_register[6:0], 1'b0};
                if (shift_counter == 4'b1000)
                    shift_counter <= 'b0;
                else
                    shift_counter <= shift_counter + 1'b1;
            end
        end
    else if (state_e == HOLDCS) begin
            shift_counter <= shift_counter + 1'b1;
        end

endmodule : spi_host
