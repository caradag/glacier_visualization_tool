clear all;clc
%% Test to check xymean1v2 and xymean2v2 are running properly
t1=[1;2;3;4;5];
t2=[1;5;8;10;11];
x=[20;30;40;50;60];
y=[5;10;15;20;25];
xy1=xymean1v2(x,y,t1);   % expected value = 875
xy2=xymean2v2(x,y,t2);   % expected vlaue = 500