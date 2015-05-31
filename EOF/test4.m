clear all;clc
%% Test to check whether the numerical calculations agree with 
%% analytical calculations of the covariance matrix
% Parameters for forming t vector
npts = 10000;
tstart = 0;
tfinal = 100;

% Forming column vector t with constant delta t (size nx1)
t = tsample(tstart,tfinal,npts,false);

% Defining cosine wave parameters (all column vectors of size mx1)
A = [2;2;2]; 
omega = [19.999;20;19.985]; 
theta = [pi/2;5*pi/2;3*pi/2]; 

% Forming matrix x of size mxn
parameters.A = A; parameters.omega = omega; parameters.theta = theta;
x = cosine_wave2 (t, parameters);

% Calculations by numerical methods
cov_num = cov_v2 (x, t)     
 
% Calculations by analytical methods
m = length(A);
n = length(t);
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
    theta_mat1+theta_mat2))./(2*omega_mat1)+tstart*cos(theta_mat1-theta_mat2)))))

%% Double checking results produced from cov_v2 against results constructed 
%% (entry by entry) from xymean1v2 (numerical and analytical)
% Double checking numerical value
cov_num2 = NaN(m,m);
for i=1:m;
    for j=1:m;
        cov_num2(i,j) = xymean1v2(x(i,:).',x(j,:).',t);
    end
end

disp('% cov_num2 should equal exactly to cov_num %')
cov_num2   

% Double checking analytical value
cov_exact2 = NaN(m,m);
for i=1:m;
    for j=1:m;
        if omega(i)==omega(j);
            cov_exact2(i,j) = (A(i)*A(j)/2/(tfinal-tstart))*(((sin(2*omega(i)*tfinal...
                + theta(i) + theta(j)))/(2*omega(i))+tfinal*cos(theta(i)-theta(j))) -...
                ((sin(2*omega(i)*tstart + theta(i) + theta(j)))/(2*omega(i))+...
                tstart*cos(theta(i)-theta(j))));
        else
            cov_exact2(i,j) = (A(i)*A(j)/2/(tfinal-tstart))*(((sin((omega(i)+omega(j))*tfinal+...
                (theta(i)+theta(j))))/(omega(i)+omega(j))+(sin((omega(i)-omega(j))*tfinal+...
                (theta(i)-theta(j))))/(omega(i)-omega(j)))-((sin((omega(i)+omega(j))*tstart+...
                (theta(i)+theta(j))))/(omega(i)+omega(j))+(sin((omega(i)-omega(j))*tstart+...
                (theta(i)-theta(j))))/(omega(i)-omega(j))));
        end
    end
end

disp('% cov_exact2 should equal exactly to cov_exact %')
cov_exact2     
    
