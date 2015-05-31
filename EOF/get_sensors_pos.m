clear all;clc
% Saving the pressure sensors position into position.mat
data = load('data 2014 v5 good only.mat');

% Preallocating structure position
sensors = fieldnames(data);
sensor_count = length(fieldnames(data));
positions = cell(sensor_count,1);
gridpos = cell(sensor_count,1);

for ii=1:sensor_count;
    location = eval(strcat('data.',sensors{ii},'.position'));
    positions{ii} = location{1};
    gridloc = eval(strcat('data.',sensors{ii},'.grid'));
    gridpos{ii} = gridloc{1};
end

filename = 'location of sensors';
save(filename,'sensors','positions', 'gridpos', 'sensor_count');