function t = tsample (tstart, tfinal, N, random)
%% generates a column vector t with constant or non-constant dt for use in test2
% Inputs: tstart - initial time, t_1
%         tfinal - end time, t_N
%         N - number of entries
%         random - Boolean, with true giving t vector of non constant 
%                  delta t and false giving non-constant delta t
% Output: t - column vector of size Nx1 

if random
    t_entries = randi(tfinal,1,(N-2));
    t = (sort([[tstart] t_entries [tfinal]])).';
else
    t = (linspace(tstart,tfinal,N)).';
end

end