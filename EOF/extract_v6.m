function [p_out, t_out] = extract_v6(tstart, tfinal, t_in, p_in, norm,...
    dt,max_nan, max_succ_nan, interp_meth, max_dt, max_miss,...
    max_miss_int, max_miss_out)
% Extract the segment of data from column vectors t and p(press or temp), 
% remove the NaN's, and interpolate them (Units of all time-related 
% inputs and outputs are in days). t_out is made monotonic by removing all 
% "older" overlapping data points and the corresponding data points in 
% p_out is removed as well before being passed for interpolation. 
% The algorithm for doing this has also been fixed; versions 1-4 have an
% error in removing overlapping time stamps and the corresponding pressure
% values.
% v6 removes the mean and has an option to normalize the pressure series 
% output. 
% Inputs: tstart, tfinal - scalars in days. tstart must NOT be t_in(1) and 
%                          tfinal must NOT be t-in(end)
%         t_in, p_in - column vectors of equal size   
%         norm - Boolean, user-specified. True normalizes p_out;
%         dt - scalar in days, user-specified; default is 2 minutes if not 
%              specified
%         max_nan - maximum number of NaN's tolerated in vector p for
%                   removal; default is 10 if not specified 
%         max_succ_nan - maximum number of successive NaN's tolerated in 
%                        vector p for removal; default is 3 if not
%                        specified
%         interp_meth - interpolation method (string); default is 'spline'
%                       if not specified
%         max_dt - code interpolates missing data points at start and end
%                of interval if there is a data gap. The number of maximum 
%                missing data points permitted inside the interval
%                specified by tstart and tfinal is defined by max_miss_int
%                (see below); the maximum number of missing data points
%                outside (between the next point outside the interval for
%                interpolation and the end of the interval itself by
%                max_miss_out). To establish how many data points are
%                missing, the code uses the length of the data gap
%                (measured in days) and a nominal measurement interval.
%                That interval is the lesser of max_dt and the mean
%                measurement interval over the time period for which there
%                is data.
%                max_dt is also used to check on missing rather than nan
%                time stamps in the interval that has data; if the longest
%                time interval in that time period exceeds max_miss*max_dt,
%                the code outputs nan data values.
%         max_miss - maximum number of missing data points tolerated inside
%                the time series in the interval tstart to tfinal.
%         max_miss_int - maximum number of missing data points tolerated 
%                between (i) tstart and the first time stamp after tstart 
%                that has data, and (ii) the last time step before tfinal 
%                that has data and tfinal; default is max_succ_nan. If the 
%                maximum number of missing data points is exceeded, the 
%                code outputs nan data values.   
%         max_miss_out - maximum number of missing data points tolerated 
%                between (i) the data point before tstart used for 
%                interpolation and tstart itself, and (ii) tfinal and the 
%                data point after tfinal used for interpolation; default is 
%                max_succ_nan. If the maximum number of missing data points 
%                is exceeded, data points outside the interval are not used 
%                for interpolation.
%
% Outputs: p_out, t_out - column vectors of equal size with data between 
%                         tstart and tfinal

% Setting user-specified inputs to default if not specified
if nargin < 6 || isempty(dt);
    dt = 2/60/24; 
end

if nargin < 7 || isempty(max_nan);
    max_nan = 10;
end

if nargin < 8 || isempty(max_succ_nan);
    max_succ_nan = 4;
end

if nargin < 9 || isempty(interp_meth);
    interp_meth = 'spline';
end

if nargin < 10 || isempty(max_dt)
    max_dt =  20/60/24;
end

if nargin < 11 || isempty(max_miss);
    max_miss = max_succ_nan;
end

if nargin < 12 || isempty(max_miss_int);
    max_miss_int = max_succ_nan;
end

if nargin < 13 || isempty(max_miss_out);
    max_miss_out = max_succ_nan;
end

% Changing p_in to type 'double'
p_in = double(p_in);

% Define time stamps onto which we will interpolate
t_out = (tstart:dt:tfinal).';   

% Deleting the NaN's in the time stamps and the corresponding location in
% the pressure series
p_in(isnan(t_in)) = []; t_in(isnan(t_in)) = [];

% Finding the indices of the nearest data points before tstart (n_minus) 
% and after tfinal (n_plus) which are not NaN's, for interpolation of  
% column vector p 
n_minus = find((t_in<tstart&~isnan(p_in)), 1, 'last');
n_plus  = find((t_in>tfinal&~isnan(p_in)), 1);
% In case n_minus and/or n_plus is/are empty
n_inside = find(tstart<=t_in&t_in<=tfinal); 

% Extracting the column vectors p and t with 1 extra data point on each 
% ends
n1 = [n_minus; n_inside; n_plus];
t1 = t_in(n1);
p1 = p_in(n1);

% Removing the NaN's in t1 and p1
nan_num = sum(isnan(p1));
nanspacing = diff(find(isnan(p1)));
if nan_num <= max_nan && sum(nanspacing <= max_succ_nan)<1;
    n2 = isnan(p1); % n2 are the locations of the NaN's
    t1(n2) = []; p1(n2) = [];
else
    p_out = nan(length(t_out),1);
    return
end

% Making t1 monotonic by removing the "older" overlapping data in both t1
% and p1
[t1,I] = sort(t1);
p1 = p1(I);
J = (1:length(I)).';
t1(I<J) = []; p1(I<J) = [];

% Removing the "older" but same time data in both t1 and p1
n4 = find(diff(t1)==0); % Indices of the data that need to be removed
t1(n4) = []; p1(n4) = [];

% Identify non-nan data value time stamps in interval
t2 = t1(t1>=tstart&t1<=tfinal);
if length(t2)<=1;
    p_out = nan(length(t_out),1);
    return
end
% Compute maximum gap between these time stamps and identify missing data 
% points
miss = max(diff(t2))/max_dt-1;
if miss > max_miss
     p_out = nan(length(t_out),1);
    return
end   

% Check if max_miss_int and max_miss_out are exceeded
ave_dt = min((max(t2)-min(t2))/(length(t2)-1),max_dt);
miss_int_minus = (t2(1)-tstart)/ave_dt;
miss_int_plus = (tfinal-t2(end))/ave_dt;

if miss_int_minus > max_miss_int || miss_int_plus > max_miss_int
    p_out = nan(length(t_out),1);
    return
end

if isempty(n_minus);
    miss_out_minus = 0;
else
    miss_out_minus = (tstart-t1(1))/ave_dt-1;
end

if isempty(n_plus);
    miss_out_plus = 0;
else
    miss_out_plus = (t1(end)-tfinal)/ave_dt-1;
end

if miss_out_minus > max_miss_out
    t1(1) = []; p1(1) = [];
end

if miss_out_plus > max_miss_out
    t1(end) = []; p1(end) = [];
end

% Interpolate
p_out = interp1(t1,p1,t_out,interp_meth);

% Removing the mean and normalizing the column vector p_out
p_out = p_out - mean(p_out);

if norm;
    norm_fac = sqrt((1/(tfinal-tstart))*(p_out.'*p_out)*dt);
    p_out = p_out./norm_fac;
end

end