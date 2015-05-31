function Cov = cov_long_v2(cov_short, mean_short, C_short, t_interval,...
    normalize, is_cov_short_norm)
%% v2 has inputs (except cov_short) that were 3-dimensional arrays as cell  
%  arrays 
% Calculates the covariance matrix of m pressure series over the total time  
% from the covariance matrices of short time intervals
% Inputs: cov_short - array (m x m x N) containing the ordered set of  
%                     square matrices (mxm) of the UNNORMALIZED covariances  
%                     over short time periods
%         mean_short - matrix (m x N) containing the ordered set of columns
%                     of means of m pressure series over short time periods
%         C_short - matrix (m x N) containing the ordered set of columns  
%                   of normalizing factors of m pressure series over short 
%                   time periods
%         t_interval - matrix (2 x N) containing the ordered set of columns
%                      of [tstart; tfinal] of each short time period.                       
%         normalize - Boolean, user-specified. True normalizes cov; 
%                     default is false (unnormalized)
%         is_cov_short_norm - Boolean, user-specified. True if cov_short is
%                             normalized; default is false (unnormalized)
% Output: Cov - covariance matrix (mxm) of covariances between 
%               t_interval(1,1) and t_interval(2,N)

% Setting user-specified inputs to default settings if unspecified
if nargin < 5 || isempty(normalize);
    normalize = false; is_cov_short_norm = false;    
end

if nargin < 6 || isempty(is_cov_short_norm);
    is_cov_short_norm = false;    
end

% Checking that there are no time gaps in t_interval
A = size(cov_short);
m = A(1); N = A(3);

B = diff(reshape(t_interval,[1,(2*N)]));
B(1:2:(2*N-1)) = [];
if any(B);
    error('There are time gaps in t_interval');
end

% Calculations
pre_dt = diff(t_interval);
dt = repmat(pre_dt,m,1);
pre_mean_long = 1/(t_interval(2,N)-t_interval(1,1))*sum(mean_short.*dt,2);
mean_long = repmat(pre_mean_long,1,N);

if normalize;
    C_long = sqrt(1/(t_interval(2,N)-t_interval(1,1))*...
        sum(dt.*(C_short.^2+(mean_long-mean_short).^2),2));
else
    C_long = ones(m,1);
end

C_mat1 = repmat(C_long,1,m);
C_mat2 = C_mat1.'; 
C_array1 = reshape(repmat(C_short,m,1),[m,m,N]);
C_array2 = permute(C_array1,[2,1,3]);
K_mat = 1./(t_interval(2,N)-t_interval(1,1))./(C_mat1.*C_mat2);
dt_array = reshape(repmat(dt,m,1),[m,m,N]);
p_mat = mean_long-mean_short;
mean_array1 = reshape(repmat(p_mat,m,1),[m,m,N]);
mean_array2 = permute(mean_array1,[2,1,3]);

if is_cov_short_norm;
    Cov = K_mat.*sum((dt_array.*(cov_short.*C_array1.*C_array2+...
    mean_array1.*mean_array2)),3);
else
    Cov = K_mat.*sum((dt_array.*(cov_short+mean_array1.*mean_array2)),3);
end

end