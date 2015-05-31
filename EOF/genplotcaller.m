function results = genplotcaller(ID);
%% Produce the pressure series of the sensor. 1 Jan 2008 is set as day 0
% Input: ID - string; the sensor's ID. eg: 'SO8P09'.
% Output: results - string; irrelevant. See plot produced.
load('data 2014 v2.mat');
t = eval(['data.' ID '.time.serialtime']);
p = eval(['data.' ID '.pressure']);
p = p{1};
plot(t-datenum('1-Jan-2008'),p,'bx');
xlabel('Time');
ylabel('Pressure');
title(['Pressure Series, Sensor ' ID]);
end