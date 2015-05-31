function lineMenu = plot_timeseries(timestamp,data,sensor_index,tmin,tmax,datmin,datmax,bound,zeroJan1,t_unit,linestyle)
%plot_timeseries(timestamp,data,sensor_index,tmin,tmax,datmin,datmax,bound,zeroJan1,t_unit)
%plots cell array time series data for multiple sensors
%Input format:
%timestamp: a structure corresponding to the sensor_read output field output.time with fields
%   year: cell array whose ith entry is a vector containing the year time stamps for the ith
%   sensor
%   day: cell array whose ith entry is a vector containing the day time stamps for the ith
%   sensor
%   hour: cell array whose ith entry is a vector containing the hour time stamps for the ith
%   sensor
%The ith entry in each of the above cell array must be vectors of the same
%length
%data: a cell array wose ith entry is a vector containing the data for the
%ith sensor
%sensor_index: a vector containing indices in timestamp and data to be
%   plotted
%tmin: a structure with scalar fields year, day containing lower axis limit information
%tmax: analogous to tmin, with upper axis limit information
%datmin, datmax: vertical axis limit
%zeroJan1: optional Boolean that sets the beginning of January 1st to have a zero time
%axis tick, otherwise 0000 hours on January 1st has a time axis tick of one
%t_unit: currently no functionality, intended to toggle to different units
%for time
    
%set defaults: plot everything, axes tight, units of days, no bound
if nargin < 3 || isempty(sensor_index)
    sensor_index = 1:length(data);
end
if nargin < 4 || isempty(tmin)
    tmin.year = inf; tmin.day = 0; tmax.year = -inf; tmax.day = 366;
    for ii=sensor_index
        tmin.year=min(tmin.year,min(timestamp.year{ii}));
        tmax.year=max(tmax.year,max(timestamp.year{ii}));
     end
    for ii=sensor_index
        minaux = timestamp.day{ii};
        minaux=min(minaux(timestamp.year{ii}==tmin.year));
        maxaux = timestamp.day{ii};
        maxaux=max(maxaux(timestamp.year{ii}==tmin.year));
        %if ismepty(minaux)
        %    minaux=inf;
        %else
        %    minaux=min(minaux);
        %end
        %if ismepty(maxaux)
        %    maxaux=-inf;
        %else
        %    maxaux=max(maxaux);
        %end
        tmin.day=min(tmin.day,minaux);
        tmax.day=max(tmax.day,maxaux);
    end
end
if nargin < 6 || isempty(datmin)
    datmin = 0;
    datmax = 0;
    for ii=sensor_index
        datmax = max(datmax,max(data{ii}));
    end
end
if nargin < 8 || isempty(bound)
    bound = NaN;
end
if nargin < 9 || isempty(zeroJan1)
    zeroJan1 = false;
end
if nargin < 9 || isempty(t_unit)
    t_unit = 'days';
end
if nargin < 10 || isempty(linestyle)
    linestyle = {'b' 'r' 'g' 'c' 'b--' 'r--' 'g--' 'c--' 'b:' 'r:' 'g:' 'c:' 'b-.' 'r-.' 'g-.' 'c-.' 'm' 'y' 'm--' 'y--' 'm:' 'y:' 'm-.' 'y-.'};
else
    linestyle={linestyle};
end

% tmin.day
% tmin.year
% tmax.day
% tmax.year

monthlength = [31 28 31 30 31 30 31 31 30 31 30 31];
monthlength_leap = [31 29 31 30 31 30 31 31 30 31 30 31];

%figure
hold on

for ii=sensor_index
    t_decimal = 365*(timestamp.year{ii}-2008)...  %January 1 2008 is time 0
        +ceil((timestamp.year{ii}-2008)/4)....%fix leap years
        +timestamp.day{ii}...%add recorded days
        +timestamp.hours{ii}/24+timestamp.minutes{ii}/(60*24);%add fractions of day from 24 hour clock recording
    lineMenu = uicontextmenu;
    plot(t_decimal,data{ii},linestyle{min(ii,length(linestyle))},'UIContextMenu', lineMenu)
end
tlim_decimal = 365*([tmin.year tmax.year]-2008) + ceil(([tmin.year tmax.year]-2008)/4) + [tmin.day tmax.day];
plot(tlim_decimal,bound*ones(size(tlim_decimal)),'r','LineWidth',1);
xlim(tlim_decimal)
ylim([datmin datmax])


%One tick mark per day, label only beginnings of each month with Julian Day
timeticks = (tmin.year-2008)*365:((tmax.year+1-2008)*365+ceil((tmax.year-2008)/4));
if zeroJan1
    timeticks = mod(timeticks-1,365);
end
timeticklabels = cell(length(timeticks),1);
monthstart = 1;
for ii=tmin.year:tmax.year
    for jj=1:12
       timeticklabels{monthstart} = mod(monthstart-ceil((ii-2008)/4),365);
       if zeroJan1
           timeticklabels{monthstart} = timeticklabels{monthstart}-1;
       end
       if mod(ii,4) == 0
           monthstart = monthstart + monthlength_leap(jj);
       else
           monthstart = monthstart + monthlength(jj);
       end
    end
end

set(gca,'XTick',timeticks,'XTickLabel',timeticklabels)

end
    
    