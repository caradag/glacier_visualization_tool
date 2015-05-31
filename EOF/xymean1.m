function xy = xymean1 (x, y, t)
% Inputs: x, y, t - vectors of dimensions n x 1
% Output: xy - mean of xy
% Assumptions: x, y, t are all of the same size
%              delta t is constant

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
del_t = t(2)-t(1);
sumxy = 0;

for i = 1:n;
    sumxy = sumxy + x(i)*y(i); 
end

xy = (1/(t(n)-t(1)))*sumxy*del_t;

end
