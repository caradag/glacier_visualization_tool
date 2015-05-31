function Cov = cov_long(cov_short,mean_short,C_short,t_interval,tstart,tfinal)
% Calculates the covariance matrix of m pressure series over the total time  
% from the covariance matrices of short time intervals
% Inputs: cov_short - cell array (Nx1) containing the ordered set of  
%                     square matrices (mxm) of the NORMALIZED covariances  
%                     over short time periods
%         mean_short - cell array (Nx1) containing the ordered set of
%                      COLUMN vectors (mx1) of means of m pressure series
%                      over short time periods
%         C_short - cell array (Nx1) containing the ordered set of COLUMN  
%                   vectors (mx1) of normalizing factors of m pressure  
%                   series over short time periods
%         t_interval - COLUMN vector (Nx1) containing the ordered set 
%                      of (tfinal-tstart) of each short time period. 
%                      (Note: tfinal and tstart in brackets are not those 
%                      in the inputs)
%         tstart, tfinal - initial and final time over which Cov is 
%                          calculated 
% Output: Cov - covariance matrix of covariances between tstart and tfinal

N = length(t_interval);
m = length(mean_short{1});

sum2 = zeros(m,1);
for n = 1:N;
    sum2 = sum2 + mean_short{n}*t_interval(n);
end
mean_long = 1/(tfinal-tstart).*sum2;

sum1 = zeros(m,1);
for n = 1:N;
    sum1 = sum1 + (C_short{n}.^2 + (mean_short{n}-mean_long).^2)*t_interval(n);
end
C_long = sqrt(1/(tfinal-tstart).*sum1);

K_mat = 1/(tfinal-tstart)./(C_long*(C_long.'));

sum3 = zeros(m);
for n = 1:N;
    sum3 = sum3 + t_interval(n)*((C_short{n}*(C_short{n}.')).*cov_short{n}+...
        (mean_long-mean_short{n})*((mean_long-mean_short{n}).'));
end
    
Cov = K_mat.*sum3;

end