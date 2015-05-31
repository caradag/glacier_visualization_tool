function x = cosine_wave2 (t, parameters)
%% generates a matrix x = [ x_11 ... x_1k ... x_1n  
%                           ...                      
%                           x_i1 ... x_ik ... x_in 
%                           ...
%                           x_m1 ... x_mk ... x_mn ]
%  where i = 1...m, k = 1...n, from a given vector t and parameters for use in test4
%  with its entries based on the equation x_i (t_k) = A_i*cos(omega_i*t_k + theta_i) 
% Inputs: t - column vector of size nx1
%         Parameters - a structure containing the constant column vectors 
%                      (i) A, size mx1 (ii) omega, size mx1  (iii) theta, size mx1
%                      in the equation x_i (t_k) = A_i*cos(omega_i*t_k + theta_i)
% Output: x - matrix of size mxn        

% Calculations:
n = length(t);
m = length(parameters.A);
mtx_A = repmat(parameters.A,1,n);
mtx_omega = repmat(parameters.omega,1,n);
mtx_t = (repmat(t,1,m)).';
mtx_theta = repmat(parameters.theta,1,n);
x = mtx_A.*cos(mtx_omega.*mtx_t+mtx_theta); 

end