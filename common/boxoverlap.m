function [o, inter, aarea, barea] = boxoverlap(a, b)

% Compute the symmetric intersection over union overlap between a set of
% bounding boxes in a and a single bounding box in b.
%
% a  a matrix where each row specifies a bounding box
% b  a single bounding box

x1 = max(a(:,1), b(1));
y1 = max(a(:,2), b(2));
x2 = min(a(:,3), b(3));
y2 = min(a(:,4), b(4));

%basically determines the possible intersection in the same way intersecting intervals would work but in 2D

w = x2-x1+1;
w(w <= 0) = 0;
h = y2-y1+1;
h(h <= 0) = 0;
inter = w.*h; %same procedure as before on new intersecting box
aarea = (a(:,3)-a(:,1)+1) .* (a(:,4)-a(:,2)+1);
barea = (b(3)-b(1)+1) * (b(4)-b(2)+1);
% intersection over union overlap
o = inter ./ (aarea+barea-inter);
% set invalid entries to 0 overlap
o(w <= 0) = 0;
o(h <= 0) = 0;
