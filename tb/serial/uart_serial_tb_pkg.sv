`include "uart_config.svh"

package uart_serial_tb_pkg;

    // One externally visible UART frame. Keeping the framing bits alongside
    // the payload lets a monitor report protocol errors without knowing
    // anything about the AXI-Lite register interface.
    typedef struct packed {
        logic                  start_bit;
        logic [`DATA_BITS-1:0] data;
        logic                  stop_bit;
    } uart_serial_frame_t;

    function automatic uart_serial_frame_t make_uart_serial_frame(
        input logic [`DATA_BITS-1:0] data,
        input logic                  stop_bit = 1'b1
    );
        uart_serial_frame_t frame;

        frame.start_bit = 1'b0;
        frame.data      = data;
        frame.stop_bit  = stop_bit;
        return frame;
    endfunction

endpackage
