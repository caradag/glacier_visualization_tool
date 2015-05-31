clc
%Logger	Type	Diff channel	Sensor ID	Ice Thickness(m)	Northing	Easting	Elevation	Year Installed	Julian Day Installed	Time Installed	Date program resumed	Transducer model
[logger,type,channel,sensor,thickness,north,east,elev,year,day,time,date_resumed,model]...
    = textread('boreholes_2013.csv','%s %s %f %s %f %f %f %f %f %f %s %s %s','delimiter',',','emptyvalue',NaN);

    
for s=1:length(sensor)
    disp(['Prossesing sensor ' sensor{s} ' (' num2str(s) ' of ' num2str(length(sensor)) ')']);
    try
        d = sensor_read_raw(logger{s},type{s},channel(s),2013,190,0,2013,220,0,[],[],[],[],[]);
    catch
        fprintf(2,['Error reading sensor ' sensor{s} ' (' model{s} ')\n']);
        continue;
    end
    switch model{s}
        case 'Honeywell'
            color='b';
        case 'New Barksdale'
            color='g';
        case 'Refurbished Barksdale'
            color='r';
    end
    try
        lineMenu=plot_timeseries(d.time,d.pressure,[],[],[],[],[],[],[],'days',color);
        uimenu(lineMenu, 'Label', ['Sensor: ' sensor{s} ' @ logger ' logger{s} ' ch' num2str(channel(s)) ' Type: ' model{s}]);

    catch
        fprintf(2,['Error plotting sensor ' sensor{s} ' (' model{s} ')\n']);
    end
end
box on
title(['Summer 2013 pressure time series by sensot brand (Honeywell=Blue, Barksdale=Gree, Refurbished Barksdale=red)'])
        
            