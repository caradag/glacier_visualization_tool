clear all;clf;clc

% Plotting the position of the sensors
load('location of sensors.mat');
northing = nan(sensor_count,1);
easting = nan(sensor_count,1);

for ii=1:sensor_count;
    northing(ii)=positions{ii}.north;
    easting(ii)=positions{ii}.east;
end

plot(easting,northing,'kx');
xlabel('Easting/m');
ylabel('Northing/m');
filename = 'Relative Positions of Sensors';
title('Relative Positions of Sensors');
% print(gcf, '-djpeg', filename); 