clc; clear; close all;

pkg load image; % load image package for imread/imwrite

% === Input parameters ===
stego_image_file = 'stego_DWT_RGB.png';        % Stego image
extracted_message_file = 'extracted_message_dwt.txt'; % Output message
end_marker = '###';                            % End marker for extraction

% === Load stego image ===
stego = imread(stego_image_file);
[rows, cols, channels] = size(stego);

% === Wavelet filter coefficients (DB2) ===
Lo_D = [0.4829629131445341 0.8365163037378079 0.2241438680420134 -0.12940952255092145];
Hi_D = [-0.12940952255092145 -0.2241438680420134 0.8365163037378079 -0.4829629131445341];

% === Manual 1-level DWT function ===
function [LL,LH,HL,HH] = dwt2_manual(img_channel, Lo, Hi)
    % Rows
    L = conv2(img_channel, Lo(:)', 'same');
    H = conv2(img_channel, Hi(:)', 'same');
    % Columns
    LL = conv2(L, Lo(:), 'same');
    LH = conv2(L, Hi(:), 'same');
    HL = conv2(H, Lo(:), 'same');
    HH = conv2(H, Hi(:), 'same');
end

% === Parameters ===
max_message_length = 2000; % chars
end_marker = '###';
num_bits = (max_message_length + length(end_marker)) * 8; % maximum bits to read

% Flatten LH subbands
LH_bits = [];
for ch = 1:channels
    [~, LH, ~, ~] = dwt2_manual(double(stego(:,:,ch)), Lo_D, Hi_D);
    LH_bits = [LH_bits; LH(:)];
end

% Limit to the number of bits actually embedded
LH_bits = LH_bits(1:num_bits);

% Extract bits by sign
bin_message = double(LH_bits > 0);

% Trim to full bytes
bin_message = bin_message(1:8*floor(length(bin_message)/8));

% Convert to chars
msg_chars = char(bin2dec(reshape(char(bin_message+'0'),8,[])'))';

% Trim at end marker
end_idx = strfind(msg_chars, end_marker);
if ~isempty(end_idx)
    msg_chars = msg_chars(1:end_idx(1)-1);
end


% === Save extracted message ===
fid = fopen(extracted_message_file, 'w');
fwrite(fid, msg_chars);
fclose(fid);

fprintf('Message extracted and saved as "%s"\n', extracted_message_file);
fprintf('Extracted length: %d characters\n', length(msg_chars));

