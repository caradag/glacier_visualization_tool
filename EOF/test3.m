clear all;clc
%% Test cov_v1
t=[1;2;3];
x=[1:3; 4:6];
cov=cov_v1(x,t)   % Expected cov is [2/3 2/3; 2/3 2/3]