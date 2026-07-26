import configure::*;
import wires::*;

module bus (
  input  logic        reset,
  input  logic        clear,
  input  logic        clock,
  input  mem_in_type  imem_in    [0:1],
  output mem_out_type imem_out   [0:1],
  input  mem_in_type  dmem_in    [0:1],
  output mem_out_type dmem_out   [0:1],
  input  mem_out_type itim_out   [0:1],
  input  mem_out_type dtim_out   [0:1],
  output mem_in_type  itim_in    [0:1],
  output mem_in_type  dtim_in    [0:1],
  input  mem_out_type rom_out,
  input  mem_out_type ram_out,
  input  mem_out_type spi_out,
  input  mem_out_type clint_out,
  input  mem_out_type uart_rx_out,
  input  mem_out_type uart_tx_out,
  output mem_in_type  rom_in,
  output mem_in_type  ram_in,
  output mem_in_type  spi_in,
  output mem_in_type  clint_in,
  output mem_in_type  uart_rx_in,
  output mem_in_type  uart_tx_in
);
  timeunit 1ns; timeprecision 1ps;

  mem_in_type bridge_in;
  mem_in_type ibridge_in[0:1];
  mem_in_type dbridge_in[0:1];

  mem_out_type bridge_out;
  mem_out_type ibridge_out[0:1];
  mem_out_type dbridge_out[0:1];

  logic [0 : 0] itim_rev[0:1];
  logic [0 : 0] dtim_rev[0:1];

  logic [0 : 0] itim_rev_reg[0:1];
  logic [0 : 0] dtim_rev_reg[0:1];

  logic itim_hit_i[0:1], dtim_hit_i[0:1];
  logic itim_hit_d[0:1], dtim_hit_d[0:1];

  always_comb begin

    for (int p = 0; p < 2; p++) begin
      itim_in[p]    = init_mem_in;
      dtim_in[p]    = init_mem_in;
      ibridge_in[p] = init_mem_in;
      dbridge_in[p] = init_mem_in;

      itim_rev[p] = itim_rev_reg[p];
      dtim_rev[p] = dtim_rev_reg[p];

      itim_hit_i[p] = ~|(ITIM_BASE ^ (imem_in[p].mem_addr & ITIM_MASK));
      dtim_hit_i[p] = ~|(DTIM_BASE ^ (imem_in[p].mem_addr & DTIM_MASK));
      itim_hit_d[p] = ~|(ITIM_BASE ^ (dmem_in[p].mem_addr & ITIM_MASK));
      dtim_hit_d[p] = ~|(DTIM_BASE ^ (dmem_in[p].mem_addr & DTIM_MASK));
    end

    for (int p = 0; p < 2; p++) begin
      if (imem_in[p].mem_valid & itim_hit_i[p]) begin
        itim_in[p]          = imem_in[p];
        itim_in[p].mem_addr = imem_in[p].mem_addr - ITIM_BASE;
        itim_rev[p]         = 0;
      end else if (dmem_in[p].mem_valid & itim_hit_d[p]) begin
        itim_in[p]          = dmem_in[p];
        itim_in[p].mem_addr = dmem_in[p].mem_addr - ITIM_BASE;
        itim_rev[p]         = 1;
      end

      if (imem_in[p].mem_valid & dtim_hit_i[p]) begin
        dtim_in[p]          = imem_in[p];
        dtim_in[p].mem_addr = imem_in[p].mem_addr - DTIM_BASE;
        dtim_rev[p]         = 1;
      end else if (dmem_in[p].mem_valid & dtim_hit_d[p]) begin
        dtim_in[p]          = dmem_in[p];
        dtim_in[p].mem_addr = dmem_in[p].mem_addr - DTIM_BASE;
        dtim_rev[p]         = 0;
      end

      if (imem_in[p].mem_valid & ~itim_hit_i[p] & ~dtim_hit_i[p]) begin
        ibridge_in[p] = imem_in[p];
      end
      if (dmem_in[p].mem_valid & ~itim_hit_d[p] & ~dtim_hit_d[p]) begin
        dbridge_in[p] = dmem_in[p];
      end
    end

    for (int p = 0; p < 2; p++) begin
      imem_out[p] = init_mem_out;
      dmem_out[p] = init_mem_out;
    end

    for (int p = 0; p < 2; p++) begin
      if (itim_out[p].mem_ready == 1 && itim_rev_reg[p] == 0) begin
        imem_out[p] = itim_out[p];
      end
      if (itim_out[p].mem_ready == 1 && itim_rev_reg[p] == 1) begin
        dmem_out[p] = itim_out[p];
      end

      if (dtim_out[p].mem_ready == 1 && dtim_rev_reg[p] == 1) begin
        imem_out[p] = dtim_out[p];
      end
      if (dtim_out[p].mem_ready == 1 && dtim_rev_reg[p] == 0) begin
        dmem_out[p] = dtim_out[p];
      end

      if (ibridge_out[p].mem_ready == 1) begin
        imem_out[p] = ibridge_out[p];
      end
      if (dbridge_out[p].mem_ready == 1) begin
        dmem_out[p] = dbridge_out[p];
      end
    end

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      for (int p = 0; p < 2; p++) begin
        itim_rev_reg[p] <= 0;
        dtim_rev_reg[p] <= 0;
      end
    end else begin
      for (int p = 0; p < 2; p++) begin
        itim_rev_reg[p] <= itim_rev[p];
        dtim_rev_reg[p] <= dtim_rev[p];
      end
    end
  end

  arbiter arbiter_comp (
    .reset   (reset),
    .clock   (clock),
    .imem_in (ibridge_in),
    .imem_out(ibridge_out),
    .dmem_in (dbridge_in),
    .dmem_out(dbridge_out),
    .mem_in  (bridge_in),
    .mem_out (bridge_out)
  );

  bridge bridge_comp (
    .reset      (reset),
    .clock      (clock),
    .bridge_in  (bridge_in),
    .bridge_out (bridge_out),
    .rom_in     (rom_in),
    .ram_in     (ram_in),
    .spi_in     (spi_in),
    .clint_in   (clint_in),
    .uart_rx_in (uart_rx_in),
    .uart_tx_in (uart_tx_in),
    .rom_out    (rom_out),
    .ram_out    (ram_out),
    .spi_out    (spi_out),
    .clint_out  (clint_out),
    .uart_rx_out(uart_rx_out),
    .uart_tx_out(uart_tx_out)
  );

endmodule
