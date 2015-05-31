clear all;clc
%% Test to check whether numerical calculations agree with analytical calculations
% Parameters for forming t vector
npts = 10000;
tstart = 0;
tfinal = 100;

% Forming vectors t1 (constant delta t) and t2 (non-constant delta t)
t1 = tsample(tstart,tfinal,npts,false);
t2 = tsample(tstart,tfinal,npts,true);

% Define cosine wave parameters
A1 = 1; 
A2 = 1; 
omega1 = 1; 
omega2 = 2; 
theta1 = 1; 
theta2 = 1;

% Forming x, y vectors
parameters.A = A1; parameters.omega = omega1; parameters.theta = theta1;
x1 = cosine_wave (t1, parameters);
x2 = cosine_wave (t2, parameters);
parameters.A = A2; parameters.omega = omega2; parameters.theta = theta2;
y1 = cosine_wave (t1, parameters);
y2 = cosine_wave (t2, parameters);

% Calculations by numerical methods
xy_num1 = xymean1v2 (x1, y1, t1)     
xy_num2 = xymean2v2 (x2, y2, t2)     
 
% Calculations by analytical methods
if omega1 == omega2;
    xy_exact = (A1*A2/2/(tfinal-tstart))*(((sin(2*omega1*tfinal + theta1 +...
        theta2))/(2*omega1)+tfinal*cos(theta1-theta2)) -...
        ((sin(2*omega1*tstart + theta1 + theta2))/(2*omega1)+...
        tstart*cos(theta1-theta2)))
else
    xy_exact = (A1*A2/2/(tfinal-tstart))*(((sin((omega1+omega2)*tfinal+...
        (theta1+theta2)))/(omega1+omega2)+(sin((omega1-omega2)*tfinal+...
        (theta1-theta2)))/(omega1-omega2))-((sin((omega1+omega2)*tstart+...
        (theta1+theta2)))/(omega1+omega2)+(sin((omega1-omega2)*tstart+...
        (theta1-theta2)))/(omega1-omega2)))
end
