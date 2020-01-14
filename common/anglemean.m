function m = anglemean(angles)
n = length(angles); %gets number of angles
m = atan2(sum(sin(angles)) / n, sum(cos(angles)) / n); %returns the arctan where average cosine is avg real part and vice versa
end
