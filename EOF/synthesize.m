function [x, t]= synthesize(t0, t1, npts, parameters, nanpts)
% Synthesize an artificial set of column vector t and its corresponding set
% of column vector x based on the equation x = A*cos(w*t+theta). nanpts 
% random entries of x vector is then replaced with NaN's to simulate real 
% data.
% Inputs: t0, t1 - starting and ending time
%         npts - number of points between, but not including, t0 and t1
%         parameters - structure with components A, omega and theta defined 
%                      in the equation x
%         nanpts - number of NaN's that randomly replace entries of column 
%                  vector x  
% Ouputs: x, t - column vectors of equal size

t = sort([t0; (t0+(t1-t0)*rand(npts,1)); t1]);
x = parameters.A.*cos(parameters.omega.*t+parameters.theta);
nan_loc = ceil(npts*rand(nanpts,1));
x(nan_loc) = NaN;    % Setting the entries at nan_loc to NaN

end