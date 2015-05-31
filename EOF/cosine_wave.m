function x = cosine_wave (t, parameters)
%% generates a column vector x from a given column vector t and parameters for use in test2
% Inputs: t - column vector of size nx1
%         Parameters - a structure containing the constants in the equation
%                      x_i = A*cos(omega*t_i + theta)
% Output: x - column vector of size nx1        

x = parameters.A*cos(parameters.omega*t + parameters.theta);

end