import configure::*;
import wires::*;

module register (
  input  logic                  reset,
  input  logic                  clock,
  input  register_read_in_type  register_rin[            0:1],
  input  register_write_in_type register_win[0:ISSUE_WIDTH-1],
  output register_out_type      register_out[            0:1]
);
  timeunit 1ns; timeprecision 1ps;

  logic [31:0] reg_file[0:31] = '{default: '0};

  always_ff @(posedge clock) begin
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      if (register_win[k].wren == 1) begin
        reg_file[register_win[k].waddr] <= register_win[k].wdata;
      end
    end
  end

  assign register_out[0].rdata1 = reg_file[register_rin[0].raddr1];
  assign register_out[0].rdata2 = reg_file[register_rin[0].raddr2];
  assign register_out[1].rdata1 = reg_file[register_rin[1].raddr1];
  assign register_out[1].rdata2 = reg_file[register_rin[1].raddr2];

endmodule
