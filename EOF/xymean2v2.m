function xy = xymean2v2 (x, y, t)
%% xymean2 assumes delta t throughout t is NOT constant
% Inputs: x, y, t - column vectors of dimensions n x 1
% Output: xy - scalar mean of xy

% Checks
if (length (x) ~= length (y));
    error ('x and y do not have the same size')
end

if (length (x) ~= length (t));
    error ('x and t do not have the same size')
end

if (length (y) ~= length (t));
    error ('y and t do not have the same size')
end

% Calculations
n = length(t);

% t1, t2 is used for vectorizing
t1 = t; t1(1:2, :) = []; t1 = [0; t1; 0];
t2 = t; t2((n-1):n, :) = []; t2 = [0; t2; 0];

xy = (0.5/(t(n)-t(1)))*(sum(x.*y.*(t1-t2)) + x(1)*y(1)*(t(2)-t(1)) + x(n)*y(n)*(t(n)-t(n-1)));

end
