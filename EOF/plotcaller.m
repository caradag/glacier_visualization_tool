function results = plotcaller(ind, wk, yr, version, cov_data);
%% Produce the pressure series of the relevant sensor. 1 Jan 2008 is set as day 0
% Inputs: ind - the sensor's number.
%         wk - week of the map.
%         yr - year of the map.
%         mp - map number.
%         version - version number of the cov data used to produce the map
%         cov_data - string, the partial name of the cov_data.
%                    Eg; '5days_int_unnorm_cov_data_' 
% Output: results - string; irrelevant. See plot produced.
if isempty(version);
    load([cov_data num2str(yr) '_' num2str(wk) '.mat']);
else 
    load([cov_data num2str(yr) '_' num2str(wk) ' (' num2str(version) ').mat']);
end

load('clean data v6.mat');
ID = sensors_clean{ind};
t = eval(['data.' ID '.time.serialtime']);
p = eval(['data.' ID '.pressure']);
p = p{1};
figure;
plot(t-datenum('1-Jan-2008'),p,'bx');
xlabel('Time');
ylabel('Pressure');
title(['Pressure Series, Sensor ' ID]);
end