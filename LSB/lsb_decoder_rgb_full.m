% lsb_decoder_rgb_full.m
% Full standalone RGB LSB decoder (blue channel only) for GNU Octave
% This matches the embedder "lsb_embedder_rgb_full.m"

clc; clear; close all;

% === USER SETTINGS ===
stego_filename = 'stego_LSB_RGB.png';   % stego image from embedder
output_message_filename = 'extracted_message_lsb.txt';  % file to save extracted text
end_marker = '###';                     % must match embedder marker

% === READ STEGO IMAGE ===
if exist(stego_filename, 'file') ~= 2
    error('Stego image "%s" not found.', stego_filename);
end
stego = imread(stego_filename);
if ndims(stego) ~= 3 || size(stego,3) ~= 3
    error('Stego image must be RGB.');
end

[rows, cols, ch] = size(stego);
fprintf('Stego image: %s  (size: %d x %d, channels: %d)\n', stego_filename, rows, cols, ch);

% === EXTRACT LSBs FROM BLUE CHANNEL ===
blue = stego(:,:,3);
blue_flat = double(blue(:));

% extract least significant bit of each pixel value
lsb_bits = bitget(blue_flat, 1);   % get LSB for each pixel (0 or 1)

% === RECONSTRUCT BYTES ===
% group every 8 bits into a character
num_bytes = floor(length(lsb_bits) / 8);
bits_matrix = reshape(lsb_bits(1:num_bytes*8), 8, num_bytes).';   % each row = 1 byte

% convert 8 bits → decimal → char
ascii_vals = bits_matrix * [128;64;32;16;8;4;2;1];  % binary to decimal
message_chars = char(ascii_vals)';  % convert to characters

% === FIND END MARKER ===
marker_idx = strfind(message_chars, end_marker);
if isempty(marker_idx)
    warning('End marker "%s" not found — output may include garbage.', end_marker);
    extracted_message = message_chars;
else
    extracted_message = message_chars(1:marker_idx(1)-1);
end

% === SAVE TO FILE ===
fid = fopen(output_message_filename, 'w');
if fid == -1
    error('Cannot create output file.');
end
fwrite(fid, extracted_message);
fclose(fid);

% === DISPLAY RESULTS ===
fprintf('Extracted message length (chars): %d\n', length(extracted_message));
fprintf('Extracted message saved as "%s"\n', output_message_filename);

% print a short preview of message
preview_len = min(200, length(extracted_message));
fprintf('\n--- MESSAGE PREVIEW ---\n');
disp(extracted_message(1:preview_len));
if length(extracted_message) > preview_len
    fprintf('... (truncated)\n');
end
fprintf('--- END ---\n');

