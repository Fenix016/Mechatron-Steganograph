% lsb_embedder_rgb_full.m
% Full standalone RGB LSB embedder for GNU Octave
% Usage: edit the three filenames below if needed, then run this script.

clc; clear; close all;

% === USER SETTINGS ===
cover_filename  = 'SRC.jpg';        % input RGB cover image
message_filename = 'text2000.txt';   % input text file (message)
stego_filename   = 'stego_LSB_RGB.png'; % output stego image (PNG recommended)

end_marker = '###';  % marker appended to message to signal its end

% === READ COVER IMAGE ===
if exist(cover_filename, 'file') ~= 2
    error('Cover image file "%s" not found in current folder.', cover_filename);
end
cover = imread(cover_filename);
if ndims(cover) ~= 3 || size(cover,3) ~= 3
    error('Cover image must be RGB (3 channels).');
end

[rows, cols, ch] = size(cover);
fprintf('Cover image: %s  (size: %d x %d, channels: %d)\n', cover_filename, rows, cols, ch);

% === READ MESSAGE TEXT ===
if exist(message_filename, 'file') ~= 2
    error('Message file "%s" not found in current folder.', message_filename);
end
fid = fopen(message_filename, 'r');
if fid == -1
    error('Failed to open message file.');
end
message = fread(fid, '*char')';
fclose(fid);

% remove CR if present, normalize newlines optionally
message = strrep(message, sprintf('\r'), '');

% append end marker so decoder will know where to stop
message_with_marker = [message end_marker];

fprintf('Message (chars, excluding marker): %d\n', length(message));
fprintf('Message + marker length: %d\n', length(message_with_marker));

% === CONVERT MESSAGE TO BITSTREAM ===
% convert to ASCII numbers, then to binary string matrix, then reshape to vector of bits
message_ascii = double(message_with_marker);               % numeric ASCII codes
bin_chars = dec2bin(message_ascii, 8);                    % each row is '01001010'
% dec2bin returns char array with rows = characters
bin_matrix = bin_chars - '0';                             % numeric 0/1 matrix (rows x 8)
bitstream = reshape(bin_matrix.', 1, []);                 % row-major sequence of bits
msg_bits_len = length(bitstream);
fprintf('Total message bits to embed: %d bits (=%d chars)\n', msg_bits_len, length(message_with_marker));

% === CAPACITY CHECK (blue channel only: 1 bit per pixel) ===
capacity_bits = rows * cols;   % one bit per pixel in blue channel
if msg_bits_len > capacity_bits
    error('Message too large for blue-channel embedding. Capacity (bits) = %d, required = %d', capacity_bits, msg_bits_len);
end
fprintf('Capacity OK: %d bits available in blue channel\n', capacity_bits);

% === EMBED INTO BLUE CHANNEL LSB ===
stego = cover;  % copy to modify
blue = cover(:,:,3);           % blue channel as uint8
blue_flat = double(blue(:));   % work in numeric array (double) for bitset / safety

% set LSB of first msg_bits_len blue pixels to the message bits
% bitset can accept vector inputs for the 'value' argument
indices = 1:msg_bits_len;
values  = bitstream(:);  % column vector of 0/1

% ensure integer pixel values and set LSB
blue_flat(indices) = bitset(floor(blue_flat(indices)), 1, values);

% reconstruct blue channel and stego image
blue_stego = reshape(uint8(blue_flat), rows, cols);
stego(:,:,3) = blue_stego;

% === SAVE STEGO IMAGE (PNG recommended to avoid lossy compression) ===
imwrite(stego, stego_filename);
fprintf('Stego image saved as "%s"\n', stego_filename);

% === QUALITY METRICS (MSE, PSNR) computed on full image (all channels) ===
orig_double  = double(cover);
stego_double = double(stego);

MSE = mean((orig_double(:) - stego_double(:)).^2);
if MSE == 0
    PSNR = Inf;
else
    PSNR = 10 * log10(255^2 / MSE);
end

fprintf('MSE (full image): %.6f\n', MSE);
if isinf(PSNR)
    fprintf('PSNR (full image): Inf (no difference)\n');
else
    fprintf('PSNR (full image): %.3f dB\n', PSNR);
end

% === Quick visual check (optional) ===
try
    figure('Name','Cover vs Stego','NumberTitle','off','Position',[200 200 900 400]);
    subplot(1,2,1); imshow(cover); title('Original Cover');
    subplot(1,2,2); imshow(stego);  title('Stego Image (blue LSB)');
catch
    % If running in non-GUI Octave, just skip plotting
end

fprintf('Embedding finished. To decode, run the matching decoder that reads the blue-channel LSBs and stops at the marker "%s".\n', end_marker);

