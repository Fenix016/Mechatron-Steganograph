clc; clear; close all;
pkg load image;   % ensure im2uint8 and im2double work

%% === Input ===
cover_image = 'SRC.jpg';
message_file = 'text250.txt';  % or text2000.txt
stego_image = 'stego_DWT_RGB.png';

%% --- Read cover image
cover = im2double(imread(cover_image));
[rows, cols, channels] = size(cover);
if channels ~= 3
    error("Cover image must be RGB");
end

%% --- Read message
fid = fopen(message_file,'r');
message = fread(fid,'*char')';
fclose(fid);
message = [message '###'];   % end marker
msg_len_chars = length(message);
bin_message = reshape(dec2bin(double(message),8).'-'0',1,[]);
msg_len_bits = length(bin_message);

%% --- Prepend 16-bit header for message length
header_bin = dec2bin(msg_len_bits,16)-'0';
bin_message = [header_bin bin_message];
total_bits = length(bin_message);

fprintf('Message length (with marker): %d chars, %d bits\n', msg_len_chars, msg_len_bits);

%% --- DB2 filters (1-level DWT) ---
Lo_D = [(1+sqrt(3))/(4*sqrt(2)), (3+sqrt(3))/(4*sqrt(2)), ...
        (3-sqrt(3))/(4*sqrt(2)), (1-sqrt(3))/(4*sqrt(2))];
Hi_D = [Lo_D(4), -Lo_D(3), Lo_D(2), -Lo_D(1)];

%% --- Manual 2D DWT function ---
function [LL,LH,HL,HH] = dwt2_manual(img,Lo,Hi)
    L = conv2(img,Lo,'same');
    H = conv2(img,Hi,'same');
    LL = L(:,1:2:end); LH = H(:,1:2:end);
    HL = L(:,2:2:end); HH = H(:,2:2:end);
end

%% --- Manual 2D IDWT function ---
function img = idwt2_manual(LL,LH,HL,HH,Lo,Hi)
    % upsample columns
    [r,c] = size(LL);
    L_up = zeros(r,2*c); H_up = zeros(r,2*c);
    L_up(:,1:2:end) = LL; L_up(:,2:2:end) = HL;
    H_up(:,1:2:end) = LH; H_up(:,2:2:end) = HH;
    img = conv2(L_up,Lo,'same') + conv2(H_up,Hi,'same');
end

%% --- Embed bits into LH subband ---
idx = 1;
stego = zeros(size(cover));
for ch = 1:channels
    channel = cover(:,:,ch);
    [LL,LH,HL,HH] = dwt2_manual(channel,Lo_D,Hi_D);
    LH_flat = LH(:);
    for k = 1:length(LH_flat)
        if idx > total_bits
            break;
        end
        val = LH_flat(k);
        % scale to 0-255 for LSB operation
        val_uint8 = round((val+1)/2*255);
        val_uint8 = bitset(val_uint8,1,bin_message(idx));
        LH_flat(k) = double(val_uint8)/255*2-1;
        idx = idx + 1;
    end
    LH = reshape(LH_flat,size(LH));
    stego(:,:,ch) = idwt2_manual(LL,LH,HL,HH,Lo_D,Hi_D);
end

%% --- Clip and save stego image ---
stego = min(max(stego,0),1);
imwrite(stego,stego_image);

%% --- PSNR and MSE ---
mse_val = mean((cover(:)-stego(:)).^2);
psnr_val = 10*log10(1^2/mse_val);

fprintf('Embedding completed.\nMSE: %.6f, PSNR: %.2f dB\n', mse_val, psnr_val);

%% --- Quick visual check ---
try
    figure('Name','Cover vs Stego','NumberTitle','off','Position',[200 200 900 400]);
    subplot(1,2,1); imshow(cover); title('Original Cover');
    subplot(1,2,2); imshow(stego); title('Stego Image (DWT LH)');
catch
    % skip if non-GUI Octave
end

