function d = anglediff(a1, a2)
%computes the difference in angles
a1 = mod(a1, 2 * pi);
a2 = mod(a2, 2 * pi);
%makes argument of angle
d = abs(a1 - a2);
if(d > pi)
    d = 2 * pi - d;
end

end
