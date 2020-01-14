function [bbox, ar] = boxinimage(imsz, bbox)
%sets dimensions for the box
x1 = max(1, bbox(:, 1));
y1 = max(1, bbox(:, 2));
x2 = min(imsz(2), bbox(:, 3));
y2 = min(imsz(1), bbox(:, 4));

w = x2-x1+1; h = y2-y1+1; inter = w .* h; %gets rect function of previous
barea = (bbox(:, 3) - bbox(:, 1) + 1) .* (bbox(:, 4) - bbox(:, 2) + 1);

ar = inter ./ barea; %standardized to area
bbox = [x1 y1 x2 y2]; %changes bbox to the actual box
