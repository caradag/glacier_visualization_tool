clear all;clc
%% Testing cov_long

% Forming column vectors x and t. All t0's < tstart and t1's > tfinal.  
t0_1=0 ; t1_1=10 ; npts1=10000 ; 
parameters1.A=1 ; parameters1.omega=1 ;parameters1.theta=2 ; nanpts1=20 ;
[x1, t1] = synthesize(t0_1, t1_1, npts1, parameters1, nanpts1);

t0_2=1 ; t1_2=12 ; npts2=12000 ; 
parameters2.A=2 ; parameters2.omega=2 ;parameters2.theta=3 ; nanpts2=10 ;
[x2, t2] = synthesize(t0_2, t1_2, npts2, parameters2, nanpts2);

% Extracting multiple successive segments from x's and t's for calculation 
% of the covariance matrix
tstart1=2 ; tfinal1=3.889 ; dt1=0.0001 ; 
tstart2=tfinal1 ; tfinal2=6.3004 ; dt2=0.00005 ;
tstart3=tfinal2 ; tfinal3=8 ; dt3=0.0001 ;

[x_out11, t_out11, x_mean11, C11] = extract_v3(tstart1, tfinal1, t1, x1, dt1, true);
[x_out12, t_out12, x_mean12, C12] = extract_v3(tstart2, tfinal2, t1, x1, dt2, true);
[x_out13, t_out13, x_mean13, C13] = extract_v3(tstart3, tfinal3, t1, x1, dt3, true);
[x_out21, t_out21, x_mean21, C21] = extract_v3(tstart1, tfinal1, t2, x2, dt1, true);
[x_out22, t_out22, x_mean22, C22] = extract_v3(tstart2, tfinal2, t2, x2, dt2, true);
[x_out23, t_out23, x_mean23, C23] = extract_v3(tstart3, tfinal3, t2, x2, dt3, true);

% Calculating the covariances of x1 and x2 over multiple successive time 
% intervals
x1 = [x_out11.';x_out21.'];
x2 = [x_out12.';x_out22.'];
x3 = [x_out13.';x_out23.'];

cov1 = cov_v2(x1, t_out11);
cov2 = cov_v2(x2, t_out12);
cov3 = cov_v2(x3, t_out13);

% Calculating the (long) covariance over the total time
cov_short = {cov1;cov2;cov3};
mean_short = {[x_mean11;x_mean21];[x_mean12;x_mean22];[x_mean13;x_mean23]};
C_short = {[C11;C21];[C12;C22];[C13;C23]};
t_interval = [tfinal1-tstart1;tfinal2-tstart2;tfinal3-tstart3]; 

Cov_num = cov_long(cov_short,mean_short,C_short,t_interval,tstart1,tfinal3); 
           
% Calculating the (long) covariance analytically
mean_ilong = parameters1.A/(tfinal3-tstart1)/parameters1.omega*(sin...
    (parameters1.omega*tfinal3+parameters1.theta)-...
    sin(parameters1.omega*tstart1+parameters1.theta));
mean_jlong = parameters2.A/(tfinal3-tstart1)/parameters2.omega*(sin...
    (parameters2.omega*tfinal3+parameters2.theta)-...
    sin(parameters2.omega*tstart1+parameters2.theta));
meanz = [mean_ilong;mean_jlong];

C_ilong = sqrt(parameters1.A*parameters1.A/2/(tfinal3-tstart1)*((sin(2*...
    parameters1.omega.*tfinal3+2*parameters1.theta)/2/parameters1.omega+...
    tfinal3)-(sin(2*parameters1.omega.*tstart1+2*parameters1.theta)/2/...
    parameters1.omega+tstart1)));

C_jlong = sqrt(parameters2.A*parameters2.A/2/(tfinal3-tstart1)*((sin(2*...
    parameters2.omega.*tfinal3+2*parameters2.theta)/2/parameters2.omega+...
    tfinal3)-(sin(2*parameters2.omega.*tstart1+2*parameters2.theta)/2/...
    parameters2.omega+tstart1)));
C = [C_ilong;C_jlong];

A = [parameters1.A; parameters2.A];
omega = [parameters1.omega; parameters2.omega];
theta = [parameters1.theta; parameters2.theta];

m = length(A);
A_mat1 = repmat(A,1,m); 
A_mat2 = A_mat1.';
omega_mat1 = repmat(omega,1,m); 
omega_mat2 = omega_mat1.';
theta_mat1 = repmat(theta,1,m); 
theta_mat2 = theta_mat1.';
C_mat1 = repmat(C,1,m);
C_mat2 = C_mat1.';
mean_mat1 = repmat(meanz,1,m);
mean_mat2 = mean_mat1.';

% cor_mat is a matrix of logicals that is used to determine when to 
% calculate using the formula when both omega values are equal  
cor_mat = omega_mat1==omega_mat2;

% intermediate matrix that changes the diagonals from NaN to zeros
Cov_int = (~cor_mat).*(1/(tfinal3-tstart1)./(C_mat1.*C_mat2).*...
    (A_mat1.*A_mat2/2.*((sin((omega_mat1+omega_mat2).*tfinal3+theta_mat1+...
    theta_mat2)./(omega_mat1+omega_mat2)+sin((omega_mat1-omega_mat2).*...
    tfinal3+theta_mat1-theta_mat2)./(omega_mat1-omega_mat2))-...
    (sin((omega_mat1+omega_mat2).*tstart1+theta_mat1+...
    theta_mat2)./(omega_mat1+omega_mat2)+sin((omega_mat1-omega_mat2).*...
    tstart1+theta_mat1-theta_mat2)./(omega_mat1-omega_mat2)))));

Cov_int(isnan(Cov_int))=0;

Cov_exact = Cov_int+cor_mat.*(1/(tfinal3-tstart1)./(C_mat1.*C_mat2)).*...
    (A_mat1.*A_mat2/2.*((sin(2*omega_mat1.*tfinal3+theta_mat1+theta_mat2)./...
    2./omega_mat1+tfinal3.*cos(theta_mat1-theta_mat2))-...
    (sin(2*omega_mat1.*tstart1+theta_mat1+theta_mat2)./...
    2./omega_mat1+tstart1.*cos(theta_mat1-theta_mat2))));

Cov_exact = Cov_exact + (1/(tfinal3-tstart1)./(C_mat1.*C_mat2)).*...
    ((-mean_mat2.*A_mat1.*sin(omega_mat1*tfinal3+theta_mat1)./omega_mat1-...
    mean_mat1.*A_mat2.*sin(omega_mat2*tfinal3+theta_mat2)./omega_mat2+...
    mean_mat1.*mean_mat2*tfinal3)-...
    (-mean_mat2.*A_mat1.*sin(omega_mat1*tstart1+theta_mat1)./omega_mat1-...
    mean_mat1.*A_mat2.*sin(omega_mat2*tstart1+theta_mat2)./omega_mat2+...
    mean_mat1.*mean_mat2*tstart1));

frac_error = abs((Cov_num-Cov_exact)./Cov_exact)






