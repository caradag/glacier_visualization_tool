function xy = xymean1v2 (x, y, t)
%% xymean1 assumes delta t throughout t is constant 
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
xy = (1/(t(end)-t(1)))*(x.'*y)*(t(2)-t(1));

end
