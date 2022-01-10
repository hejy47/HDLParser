// Circular buffer for audio samples, clears when full.
// By Sameer Puri https://github.com/sameer
// If the buffer is cleared, either a larger buffer is needed or output is slower than input.

// Operating principles:
// * remove_position is the next available audio sample, unless remove_position == insert_position
// * insert_position is the next empty buffer location
// * remaining is the distance between insert and remove
//     * insert is always ahead of remove -- if remove > insert, a position has wrapped around from BUFFER_END and an alternate calculation is used
// * if the buffer is completely filled, insert_position and remove_position become equal and the buffer is cleared (remaining = 0)
module buffer 
#(
    parameter BUFFER_SIZE = 16,
    parameter BIT_WIDTH = 16,
    parameter CHANNELS = 2
)
(
    input logic clk_audio,
    input logic clk_pixel,
    input logic packet_enable,
    input logic [BIT_WIDTH-1:0] audio_in [CHANNELS-1:0],
    output logic [BIT_WIDTH-1:0] audio_out [CHANNELS-1:0],
    output logic [$clog2(BUFFER_SIZE)-1:0] remaining
);

localparam BUFFER_WIDTH = $clog2(BUFFER_SIZE);

const bit [BUFFER_WIDTH-1:0] BUFFER_END = BUFFER_WIDTH'(BUFFER_SIZE - 1);

logic [BUFFER_WIDTH-1:0] insert_position = 0;
logic [BUFFER_WIDTH-1:0] remove_position = 0;

assign remaining = insert_position >= remove_position ? (insert_position - remove_position) : (BUFFER_END - remove_position + insert_position + BUFFER_WIDTH'(1));

logic [BIT_WIDTH-1:0] audio_buffer [BUFFER_SIZE-1:0] [CHANNELS-1:0];

assign audio_out = audio_buffer[remove_position];

always @(posedge clk_audio)
begin
    // Insert
    audio_buffer[insert_position] <= audio_in;
    if (remaining == BUFFER_END)
        $fatal("Audio buffer overflow");
    insert_position <= insert_position == BUFFER_END ? BUFFER_WIDTH'(0) : insert_position + BUFFER_WIDTH'(1);
end

always @(posedge clk_pixel)
begin
    if (packet_enable)
    begin
        if (remaining > BUFFER_WIDTH'(0)) // Remove.
        begin
            remove_position <= remove_position == BUFFER_END ? BUFFER_WIDTH'(0) : remove_position + BUFFER_WIDTH'(1);
        end else
        begin
            // clk_packet but no items left
        end
    end
end

endmodule
