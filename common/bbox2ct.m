function ct = bbox2ct(bbox)
ct = (bbox(1:2) + bbox(3:4)) ./ 2; %takes 1st and 3rd entry of box and averages
end
