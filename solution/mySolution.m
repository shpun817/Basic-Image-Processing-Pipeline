%% Initials

image = imread("../data/banana_slug.tiff");
imageSize = size(image);
width = imageSize(2);
height = imageSize(1);
fprintf("The width of the image is %d and the height is %d.\n", width, height);
fprintf("Before conversion, the class of the image array is %s.\n", class(image));
image = double(image);
fprintf("After conversion, the class of the image array is %s.\n", class(image));

%% Linearization

minLevel = 2047;
maxLevel = 15000;
image = (image - minLevel) / (maxLevel - minLevel);
image = min(max(image, 0), 1);

%% Identifying the correct Bayer pattern

% Create 4 subimages
im1 = image(1:2:end, 1:2:end);
im2 = image(1:2:end, 2:2:end);
im3 = image(2:2:end, 1:2:end);
im4 = image(2:2:end, 2:2:end);

% Combine the above images into RGB images, each corresponding to one
% pattern
im_grbg = cat(3, im2, im1, im3);
im_rggb = cat(3, im1, im2, im4);
im_bggr = cat(3, im4, im2, im1);
im_gbrg = cat(3, im3, im1, im2);

% Show each one in a figure and see which one looks the best
%figure; imshow(min(1, im_grbg*4)); title("grbg");
%figure; imshow(min(1, im_rggb*4)); title("rggb");
%figure; imshow(min(1, im_bggr*4)); title("bggr");
%figure; imshow(min(1, im_gbrg*4)); title("gbrg");

% 'rggb' seems to be correct.

%% White balancing

% Setup the parameters
red = image(1:2:end,1:2:end);
green1 = image(1:2:end,2:2:end);
green2 = image(2:2:end,1:2:end);
blue = image(2:2:end,2:2:end);

r_max = max(red(:));
g_max = max([green1(:); green2(:)]);
b_max = max(blue(:));
r_avg = mean(red(:));
g_avg = mean([green1(:); green2(:)]);
b_avg = mean(blue(:));

% Setup the matrices to multiply into the RGB vectors
gray_world_matrix = [g_avg/r_avg 0 0; 0 1 0; 0 0 g_avg/b_avg];
white_world_matrix = [g_max/r_max 0 0; 0 1 0; 0 0 g_max/b_max];

% Apply white-balancing
im_gw = zeros(size(image));
im_gw(1:2:end, 1:2:end) = red * g_avg / r_avg;
im_gw(1:2:end, 2:2:end) = green1;
im_gw(2:2:end, 1:2:end) = green2;
im_gw(2:2:end, 2:2:end) = blue * g_avg / b_avg;

im_ww = zeros(size(image));
im_ww(1:2:end, 1:2:end) = red * g_max / r_max;
im_ww(1:2:end, 2:2:end) = green1;
im_ww(2:2:end, 1:2:end) = green2;
im_ww(2:2:end, 2:2:end) = blue * g_max / b_max;

%% Demosaicing

% Select which white-balancing method to use
im = im_gw;

% Demosaic the red channel
[X, Y] = meshgrid(1:2:width, 1:2:height); % the existing red points' coordinates
V = im(1:2:end, 1:2:end); % the intensities of the existing red points

r_result = zeros(size(im));
r_result(1:2:end, 1:2:end) = V; % the demosaic result of course contains the original red points

[Xq, Yq] = meshgrid(1:2:width, 2:2:height); % every top-right corner which is to be interpolated
r_result(1:2:end, 2:2:end) = interp2(X, Y, V, Xq, Yq);
[Xq, Yq] = meshgrid(2:2:width, 1:2:height);
r_result(2:2:end, 1:2:end) = interp2(X, Y, V, Xq, Yq);
[Xq, Yq] = meshgrid(2:2:width, 2:2:height);
r_result(2:2:end, 2:2:end) = interp2(X, Y, V, Xq, Yq);

% Demosaic the green channel
[X1, Y1] = meshgrid(1:2:width, 2:2:height); % the first set of existing green points' coordinates
V1 = im(1:2:end, 2:2:end); % the intensities of the first set of existing green points
[X2, Y2] = meshgrid(2:2:width, 1:2:height); % the second set of existing green points' coordinates
V2 = im(2:2:end, 1:2:end); % the intensities of the second set of existing green points

g_result = zeros(size(im));
g_result(1:2:end, 2:2:end) = V1;
g_result(2:2:end, 1:2:end) = V2;

[Xq, Yq] = meshgrid(1:2:width, 1:2:height);
g_result(1:2:end, 1:2:end) = (interp2(X1, Y1, V1, Xq, Yq) + interp2(X2, Y2, V2, Xq, Yq)) / 2;
[Xq, Yq] = meshgrid(2:2:width, 2:2:height);
g_result(2:2:end, 2:2:end) = (interp2(X1, Y1, V1, Xq, Yq) + interp2(X2, Y2, V2, Xq, Yq)) / 2;

% Demosaic the blue channel
[X, Y] = meshgrid(2:2:width, 2:2:height); % the existing blue points' coordinates
V = im(2:2:end, 2:2:end); % the intensities of the existing blue points

b_result = zeros(size(im));
b_result(2:2:end, 2:2:end) = V; % the demosaic result of course contains the original blue points

[Xq, Yq] = meshgrid(1:2:width, 1:2:height); % every top-left corner which is to be interpolated
b_result(1:2:end, 1:2:end) = interp2(X, Y, V, Xq, Yq);
[Xq, Yq] = meshgrid(2:2:width, 1:2:height);
b_result(2:2:end, 1:2:end) = interp2(X, Y, V, Xq, Yq);
[Xq, Yq] = meshgrid(1:2:width, 2:2:height);
b_result(1:2:end, 2:2:end) = interp2(X, Y, V, Xq, Yq);

im_rgb = cat(3, r_result, g_result, b_result);

% figure; imshow(im_rgb);
% The current image is very dark.

%% Brightness adjustment

im_gray = rgb2gray(im_rgb);
gray_max = max(im_gray(:));
percentage = 4.5;
im_rgb = im_rgb * percentage * gray_max;

% figure; imshow(im_rgb);
% The image is much brighter

%% Gamma correction

threshold = .0031308;

ind = im_rgb<=threshold;

im_rgb(ind) = 12.92*im_rgb(ind);
im_rgb(~ind) = (1+0.055)*(im_rgb(~ind).^(1/2.4))-0.055;

% figure; imshow(im_rgb);

%% Compression

imwrite(im_rgb,'outputUncompressed.png');
imwrite(im_rgb,'output95.jpg','jpg','quality',95);

% The compression ratio is about 5.3763.

imwrite(im_rgb,'output25.jpg','jpg','quality',25);
disp('Compression Done');

% I think 25 is the lowest quality such that it is nearly
% indistinguishable.
% The corresponding compression ratio is about 37.9349.