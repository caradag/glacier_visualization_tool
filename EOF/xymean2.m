function xy = xymean2 (x, y, t)
% Inputs: x, y, t - vectors of dimensions n x 1
% Output: xy - mean of xy
% Assumptions: x, y, t are all of the same size
%              delta t is not constant

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
sumxy = 0;

for i = 2:(n-1);
    sumxy = sumxy + x(i)*y(i)*0.5*(t(i+1)-t(i-1)); 
end

xy = (1/(t(n)-t(1)))*(sumxy + x(1)*y(1)*0.5*(t(2)-t(1)) + x(n)*y(n)*0.5*(t(n)-t(n-1)));

end
