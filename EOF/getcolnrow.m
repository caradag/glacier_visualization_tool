function [col, row] = getcolnrow(posstr)
%% Get the column and row number (scalars) of a sensor 
% Input: posstr - string, the column and row number of a sensor.
% Output: col, row - scalars, the column and row number of a sensor. 
row = eval(posstr(2:strfind(posstr,'C')-1));

if isletter(posstr(end));
    col = eval(posstr(strfind(posstr,'C')+1:length(posstr)-1));
else
    col = eval(posstr(strfind(posstr,'C')+1:length(posstr)));
end
 
end