clear all;clc
% Testing extract_v2 with some simple data
t = (0:.09:3).';
x = t.^2;
t_initial = 1;  t_final = 2;
[x_out1s, t_out1s, x_mean1s] = extract_v2(t_initial, t_final, t, x, 0.1,...
    false, 10, 3, 'spline');
[x_out1l, t_out1l, x_mean1l] = extract_v2(t_initial, t_final, t, x, 0.1,...
    false, 10, 3, 'linear');
x(10:12) = NaN;
[x_out2s, t_out2s, x_mean2s] = extract_v2(t_initial, t_final, t, x, 0.1,...
    false, 10, 3, 'spline');
[x_out2l, t_out2l, x_mean2l] = extract_v2(t_initial, t_final, t, x, 0.1,...
    false, 10, 3, 'linear');

% Adding back the mean to simplify check
x_out1s = x_out1s + x_mean1s;
x_out1l = x_out1l + x_mean1l;
x_out2s = x_out2s + x_mean2s;
x_out2l = x_out2l + x_mean2l;

% Plots
subplot(2,2,1);
plot(t_out1s, x_out1s);
xlabel('Time'); ylabel('x');title('Spline, no NaN');
subplot(2,2,2);
plot(t_out1l, x_out1l);
xlabel('Time'); ylabel('x');title('Linear, no NaN');
subplot(2,2,3);
plot(t_out2s, x_out2s);
xlabel('Time'); ylabel('x');title('Spline, NaN at 10th entry');
subplot(2,2,4);
plot(t_out2l, x_out2l);
xlabel('Time'); ylabel('x');title('Linear, NaN at 10th entry');
