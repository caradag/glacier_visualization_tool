clear all; clc
%% To show on a graph how the number of points between tfinal and tstart affects
%% the accuracy of cov_num
% Parameters for forming t vectors
npts1 = 100; npts2 = 1000; npts3 = 10000; 
tstart = 0;
tfinal = 10;

% Forming column vectors t with constant delta t (size nx1)
t1 = tsample(tstart,tfinal,npts1,false);
t2 = tsample(tstart,tfinal,npts2,false);
t3 = tsample(tstart,tfinal,npts3,false);

% Defining cosine wave parameters (all column vectors of size mx1)
A = [2;2;2]; 
omega = [1;2;3]; 
theta = [pi/2;5*pi/2;3*pi/2]; 

% Forming matrices x of size mxn
parameters.A = A; parameters.omega = omega; parameters.theta = theta;
x1 = cosine_wave2 (t1, parameters);
x2 = cosine_wave2 (t2, parameters);
x3 = cosine_wave2 (t3, parameters);

% Calculations by numerical methods
cov_num1 = cov_v2 (x1, t1);     
cov_num2 = cov_v2 (x2, t2);    
cov_num3 = cov_v2 (x3, t3);     
 
% Calculations by analytical methods
m = length(A);
n = length(t1);
A_mat1 = repmat(A,1,m); 
A_mat2 = A_mat1.';
omega_mat1 = repmat(omega,1,m); 
omega_mat2 = omega_mat1.';
theta_mat1 = repmat(theta,1,m); 
theta_mat2 = theta_mat1.';

% cor_mat is a matrix of logicals that is used to determine when to 
% calculate using the formula when both omega values are equal  
cor_mat = omega_mat1==omega_mat2;

% intermediate matrix that changes the diagonals from NaN to zeros
cov_int = (~cor_mat).*(((sin((omega_mat1+omega_mat2)*tfinal+(theta_mat1+...
    theta_mat2)))./(omega_mat1+omega_mat2) + (sin((omega_mat1-...
    omega_mat2)*tfinal+(theta_mat1-theta_mat2)))./(omega_mat1-omega_mat2))...
    - ((sin((omega_mat1+omega_mat2)*tstart+(theta_mat1+...
    theta_mat2)))./(omega_mat1+omega_mat2) + (sin((omega_mat1-...
    omega_mat2)*tstart+(theta_mat1-theta_mat2)))./(omega_mat1-omega_mat2)));

cov_int(isnan(cov_int))=0;

cov_exact = (A_mat1.*A_mat2/2/(tfinal-tstart)).*(cov_int+...
    (cor_mat.*(((sin(2*omega_mat1*tfinal+theta_mat1+theta_mat2))./(2*omega_mat1)...
    +tfinal*cos(theta_mat1-theta_mat2)) - ((sin(2*omega_mat1*tstart +...
    theta_mat1+theta_mat2))./(2*omega_mat1)+tstart*cos(theta_mat1-theta_mat2)))));

% Plotting the graph to show the convergence of cov_num to cov_exact as npts
% increases
frac_error1 = abs((cov_num1-cov_exact)./cov_exact); frac_error1 = frac_error1(:); 
frac_error2 = abs((cov_num2-cov_exact)./cov_exact); frac_error2 = frac_error2(:);
frac_error3 = abs((cov_num3-cov_exact)./cov_exact); frac_error3 = frac_error3(:);

xaxis = [1:length(frac_error1)];

plot(xaxis,frac_error1,'rx--',xaxis,frac_error2,'bo--',xaxis,frac_error3,'g*--')
legend('100 pts', '1000 pts', '10000 pts');
xlabel('Entry Number in Fractional Error Vectors'); ylabel('Absolute Fractional Error'); 
title('Absolute Fractional Error of Numerical Covariance from Exact Covariance Graph');

