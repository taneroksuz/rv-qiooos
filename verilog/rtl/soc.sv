import configure::*;
import wires::*;

module soc (
  input  logic        reset,
  input  logic        clear,
  input  logic        clock,
  output logic        sclk,
  output logic        mosi,
  input  logic        miso,
  output logic        ss,
  input  logic        rx,
  output logic        tx,
  input  mem_out_type ram_out,
  output mem_in_type  ram_in
);
  timeunit 1ns; timeprecision 1ps;

  mem_in_type  imem_in [0:1];
  mem_in_type  dmem_in [0:1];
  mem_out_type imem_out[0:1];
  mem_out_type dmem_out[0:1];

  mem_in_type  itim_in [0:1];
  mem_in_type  dtim_in [0:1];
  mem_out_type itim_out[0:1];
  mem_out_type dtim_out[0:1];

  mem_in_type rom_in, spi_in, clint_in, uart_rx_in, uart_tx_in;
  mem_out_type rom_out, spi_out, clint_out, uart_rx_out, uart_tx_out;

  logic [0:0] meip, msip, mtip;
  logic [0:0] rx_irq, tx_irq;
  logic [63:0] mtime;

  assign meip = rx_irq | tx_irq;

  cpu cpu_comp (
    .reset   (reset),
    .clear   (clear),
    .clock   (clock),
    .imem_in (imem_in),
    .imem_out(imem_out),
    .dmem_in (dmem_in),
    .dmem_out(dmem_out),
    .meip    (meip),
    .msip    (msip),
    .mtip    (mtip),
    .mtime   (mtime)
  );

  bus bus_comp (
    .reset      (reset),
    .clear      (clear),
    .clock      (clock),
    .imem_in    (imem_in),
    .imem_out   (imem_out),
    .dmem_in    (dmem_in),
    .dmem_out   (dmem_out),
    .itim_in    (itim_in),
    .dtim_in    (dtim_in),
    .itim_out   (itim_out),
    .dtim_out   (dtim_out),
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

  tim itim_comp (
    .reset  (reset),
    .clock  (clock),
    .tim_in (itim_in),
    .tim_out(itim_out)
  );

  tim dtim_comp (
    .reset  (reset),
    .clock  (clock),
    .tim_in (dtim_in),
    .tim_out(dtim_out)
  );

  rom rom_comp (
    .reset  (reset),
    .clock  (clock),
    .rom_in (rom_in),
    .rom_out(rom_out)
  );

  clint #(
    .CLOCK_RATE(CLK_DIVIDER_RTC)
  ) clint_comp (
    .reset      (reset),
    .clock      (clock),
    .clint_in   (clint_in),
    .clint_out  (clint_out),
    .clint_msip (msip),
    .clint_mtip (mtip),
    .clint_mtime(mtime)
  );

  spi #(
    .CLOCK_RATE(CLK_DIVIDER_PER)
  ) spi_comp (
    .reset  (reset),
    .clock  (clock),
    .spi_in (spi_in),
    .spi_out(spi_out),
    .sclk   (sclk),
    .mosi   (mosi),
    .miso   (miso),
    .ss     (ss)
  );

  uart_rx #(
    .CLOCK_RATE(CLK_DIVIDER_BIT)
  ) uart_rx_comp (
    .reset   (reset),
    .clock   (clock),
    .uart_in (uart_rx_in),
    .uart_out(uart_rx_out),
    .rx_irq  (rx_irq),
    .rx      (rx)
  );

  uart_tx #(
    .CLOCK_RATE(CLK_DIVIDER_BIT)
  ) uart_tx_comp (
    .reset   (reset),
    .clock   (clock),
    .uart_in (uart_tx_in),
    .uart_out(uart_tx_out),
    .tx_irq  (tx_irq),
    .tx      (tx)
  );

endmodule
