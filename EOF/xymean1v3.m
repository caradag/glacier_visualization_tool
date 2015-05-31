function xy = xymean1v3 (x, y, t)
%% v3 assumes delta t throughout t is constant
% Inputs: x, y, t - row vectors of dimensions 1 x n
% Output: xy - scalar mean of xy

% Checks
A=size(x); B=size(y);

if A(1)~=1 || B(1)~=1;
    error ('one or both inputs are not row vectors')
end
    
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
xy = (1/(t(end)-t(1)))*(x*(y.'))*(t(2)-t(1));

end
