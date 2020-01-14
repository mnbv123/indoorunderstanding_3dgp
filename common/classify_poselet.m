function [labels, p] = classify_poselet(model, train_data, test_data)
%gets function from previous data
addpath('../3rdParty/libsvm-3.12/matlab/');

n = size(test_data, 1);
Ktest = hist_isect(test_data, train_data);
Ktest_svm = [(1:n)', Ktest];
[labels, ~, p] = svmpredict(ones(n, 1), Ktest_svm, model, '-b 1');
%predicts how everything should be labeled based on previous data
end

function K = hist_isect(x1, x2)

% Evaluate a histogram intersection kernel, for example
%
%    K = hist_isect(x1, x2);
%
% where x1 and x2 are matrices containing input vectors, where 
% each row represents a single vector.
% If x1 is a matrix of size m x o and x2 is of size n x o,
% the output K is a matrix of size m x n.

n = size(x2,1);
m = size(x1,1);
K = zeros(m,n);

if (m <= n)
   for p = 1:m
       nonzero_ind = find(x1(p,:)>0);
       tmp_x1 = repmat(x1(p,nonzero_ind), [n 1]); 
       K(p,:) = sum(min(tmp_x1,x2(:,nonzero_ind)),2)';
   end
else
   for p = 1:n
       nonzero_ind = find(x2(p,:)>0);
       tmp_x2 = repmat(x2(p,nonzero_ind), [m 1]);
       K(:,p) = sum(min(x1(:,nonzero_ind),tmp_x2),2);
   end
end

end

