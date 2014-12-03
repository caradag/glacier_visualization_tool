%Data table path + file name
dataTableFile='/home/camilo/5_UBC/Field/FIELD_DATA/DATA/Pressure_Sensor_Reference_Table_2012.csv';

% defining path to import rutine
path(path,'/home/camilo/5_UBC/Field/FIELD_DATA/DATA/');
%import rutine name
sensor_read=@sensor_read_2012_v4;


[inst.logger_ID,inst.logger_type,inst.channel,inst.sensor_ID,inst.hole_ID,inst.thickness,...
        inst.sensor_grid,inst.sensor_north,inst.sensor_east,inst.sensor_elev,inst.nominal_north,inst.nominal_east,inst.install_year,...
        inst.install_day,inst.install_time,inst.uninstall_year,inst.uninstall_day,inst.uninstall_time,...
        inst.atpress,inst.icepress]...
    = textread(dataTableFile,'%s %s %f %s %s %f %s %f %f %f %f %f %f %f %f %f %f %f %f %f','delimiter',',','emptyvalue',NaN,'headerlines',1);

data=[];
sensors={};
minTime=Inf;
maxTime=-Inf;
for i=1:length(inst.sensor_ID)
    if ~isempty(char(inst.sensor_ID(i)))
        sensorcode=['S' char(inst.sensor_ID(i))];
        sensors{end+1}=sensorcode;
        disp(['Procesing sensor ' char(inst.sensor_ID(i)) '...'])
        sdata=rmfield(sensor_read('sensor',inst.sensor_ID(i)), 'sensor');
        timelen=length(sdata.time.year{:});
        serialyear=datenum([double(sdata.time.year{:}) repmat([1 0 0 0 0],timelen,1)]);
        serialday=double(sdata.time.day{:});
        serialhours=double(sdata.time.hours{:})/24;
        serialminutes=double(sdata.time.minutes{:})/(24*60);
        serialtime=serialyear+serialday+serialhours+serialminutes;

        minTime=min([minTime; serialtime]);
        maxTime=max([maxTime; serialtime]);
        
        sdata.time.serialtime=serialtime;
        data = setfield(data, sensorcode, sdata);
    end
end
sensor_count=length(sensors);

disp([num2str(sensor_count) ' sensors processed']);
disp(['From ' datestr(minTime) ' to ' datestr(maxTime)]);

disp('Saving data...');
save('sensors_data', 'data','sensors','sensor_count');
