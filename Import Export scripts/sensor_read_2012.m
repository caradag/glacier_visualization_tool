function output = sensor_read5(type,sensor_list,start,finish,raw,tseries_break,use_offset_data,CR10,use_textscan)
%sensor_read3(type,sensor_list,start,finish,raw,tseries_break,use_offset_data,CR10,use_textscan)
%Reads in metadata from pressure sensor reference table, reads in raw data
%from CR10(X) or CR1000 data loggers, and outputs as a data structure, with
%time stamping and optional applied calibration.
%Input format:
%type:   is a string that defines the format of sensor_list. Currently
%        available is identification of data by sensor ID (type 'sensor'),
%        by grid location (type 'grid') and by hole ID (type 'hole').
%        Defaults to 'grid'
%sensor_list: a cell array of strings containing identifiers of sensors (e.g. '10P03') / grid
%        locations (e.g. 'R18C16c') / holes (e.g. '09H03') for which
%        data is to be extracted. Must correspond to type specified in first input variable. Defaults to all grid locations.
%start:  structure with with integer / floating point fields .year and .day specifying the date in
%        year, Julian day format from which data is to be read. Defaults to
%        January 1st 2000
%finish: same as start but specifies finish date. Defaults to December 31
%        2020
%raw:    Boolean that specifies whether raw (true) or calibrated (false)
%        data should be output. Defaults to false
%tseries_break: Boolean that specifies whether NaNs should be inserted in
%        time series whenever two separate data logger files are spliced
%        together. This introduces a break in curve when plotting and
%        allows separate files to be identified visually. Default is true.
%use_offset_data: Boolean that specifies whether time offset data contained
%        in par files should be used to shift recorded time stamps (true) or not (false).
%        Default is false.
%CR10:   Boolean that fixes any possible Y2K problems in old loggers (true)
%        by adding 2000 to year stamps less than 2000. Default is true.
%        Presently not clear if this is a real problem, only CR10 time
%        series to date output four digit year.
%use_textscan: Boolean that uses whether textscan (true) or textread
%       (false) should be used to read data files. textscan requires MATLAB
%       version 7 or above, textread capability designed to make code
%       backward compatible with older versions. Default is true if version
%       7 or above, false otherwise
%Output format: output structure has fields
%time:   substructure containing cell array fields .year, .day, .hours,
%        .minutes. The ith entry in each of these cell arrays is an array
%        containing the relevant time stamps for the sensor corresponding to the ith entry in
%        sensor_list
%pressure:  cell array whose ith entry contains pressure readings in Pa for the
%        sensor corredponding to the itht entry in sensor_list
%effpress: cell array of same format as .pressure, containing effective
%        pressures in Pa corresponding to entries in pressure. Only outout if raw
%        is false
%temperature: cell array of same format as .pressure, containing panel
%       temperature of logger that the corresponding sensor is hooked up to.
%       Useful for checking consistency between time stamps
%battvolt:  cell array of same format as .pressure, containing battery
%       voltage of logger that the corresponding sensor is hooked up to.
%       Useful for identifying possible logger failure
%sensor: cell array containing strings specifying sensor IDs of sensors.
%       ith entry corresponds to ith entry in sensor_list
%grid:  cell array containing strings specifying grid locations of sensors.
%       ith entry corresponds to ith entry in sensor_list
%position: substructure containing floating point array fields north, east, elev,
%       nominal_north and nominal_east. The ith entry in each field is the relevant
%       coordinate of the ith entry in sensor_list.
%icepress: floating point array containing overburdens in Pascal
%logger: cell array containing strings specifying logger serial numbers to which sensors are hooked up.
%       ith entry corresponds to ith entry in sensor_list
%
%NOTE: convention for offset sign plus par files for summer 08 / winter
%08-09 need checking / correcting


filename_info = '../../DATA/Pressure_Sensor_Reference_Table_2012.csv';       %comma-delimited file containing logger / sensor / hole information
filespec.path = '../../DATA/';       %directory containing annual data
filespec.suff_max = 20; %maximum suffix of individual data files

%Thicknes and ice pressure may change over time (advection, surface mass balance) - do we want a way of including that as
%well? Do any sensors survive long enough to worry about that?
[inst.logger_ID,inst.logger_type,inst.channel,inst.sensor_ID,inst.hole_ID,inst.thickness,...
        inst.sensor_grid,inst.sensor_north,inst.sensor_east,inst.sensor_elev,inst.nominal_north,inst.nominal_east,inst.install_year,...
        inst.install_day,inst.install_time,inst.uninstall_year,inst.uninstall_day,inst.uninstall_time,...
        inst.atpress,inst.multiplier,inst.icepress]...
    = textread(filename_info,'%s %s %f %s %s %f %s %f %f %f %f %f %f %f %f %f %f %f %f %f %f','delimiter',',',...
    'emptyvalue',NaN,'headerlines',1);
%%Clean up missing install / uninstall times
inst.install_time(isnan(inst.install_time)) = 0;
inst.uninstall_time(isnan(inst.uninstall_time)) = 2400;
inst.atpress(isnan(inst.atpress)) = 0.5512;
inst.multiplier(isnan(inst.multiplier)) = 6894.75729*20; 
%Converts Raw Data into Effective Pressure
%First calculate Water Pressure = Raw Data-Atmospheric Pressure.
%Second conversion of pressure data from PSI to Pa: 1psi=6894.75729
%Pa, full range (reading of 10) = 200 psi.

%Set to defaults for missing inputs: read everything and apply calibration;
%put in NaN's at breaks between files
if nargin == 0 || isempty(type)
    type = 'grid';
end
if nargin < 2 || isempty(sensor_list)  
    sensor_list=inst.sensor_grid;
end
if nargin < 3
    start.year = 2000;
    finish.year = 2020;
    start.day = 0;
    finish.day = 366;
end

if nargin < 5 || isempty(raw)
    raw = false;
end
if nargin < 6 || isempty(tseries_break)
    tseries_break = true;
end
if nargin < 7 || isempty(use_offset_data)
    use_offset_data = false;%true;
end
if nargin < 8 || isempty(CR10)
    CR10 = true;
end
if nargin < 8 || isempty(use_textscan)
    use_textscan = true;
end

n_sensor = length(sensor_list);

output.time.year = cell(1,n_sensor);
output.time.day = cell(1,n_sensor);
output.time.hours = cell(1,n_sensor);
output.time.minutes = cell(1,n_sensor);
output.pressure = cell(1,n_sensor);
output.temperature = cell(1,n_sensor);
output.battvolt = cell(1,n_sensor);

for ii=1:n_sensor
    sensor_list{ii}
    [log_read,log_type,chan_read,date_start,date_finish,sensor_ID,grid,position,atpress,multiplier,icepress]  = identify(type,sensor_list{ii},inst,start, finish);
                    %outputs vector of logger ids and channels and
                    %structures date_start, date_finish giving the
                    %corresponding start and end dates for measurement with
                    %fields year and day (Julian day), falling in bracket
                    %given by start and finish
    date_decimal = date_start.year + date_start.day/365;
    [date_decimal,date_order] = sort(date_decimal);
    log_read = log_read(date_order); chan_read = chan_read(date_order);
    date_start.year = date_start.year(date_order); date_start.day = date_start.day(date_order);
    date_finish.year = date_finish.year(date_order); date_finish.day = date_finish.day(date_order);
                    %sort dates in ascending order
                    %Now read in:
    year = cell(length(log_read),1); day = cell(length(log_read),1); hours = cell(length(log_read),1); minutes = cell(length(log_read),1); rawpress = cell(length(log_read),1); rawtemp = cell(length(log_read),1); rawbatt = cell(length(log_read),1);
    for jj=1:length(log_read)
        [year{jj},day{jj},hours{jj},minutes{jj},rawpress{jj},rawtemp{jj},rawbatt{jj}] = logger_read(log_read{jj},log_type{jj},chan_read(jj),date_start.year(jj),date_start.day(jj),date_start.time(jj),date_finish.year(jj),date_finish.day(jj),date_finish.time(jj),tseries_break,use_offset_data,CR10,use_textscan,filespec);
                    %read data - outputs column vectors containing year and day of
                    %measurement, raw measurement and raw temperature
                    %reading (for time checking purposes)
                    %NOTE: NEEDS TIME OFFSET FROM par files
    end
                    %Splice different loggers:
    for jj=1:length(log_read)
        output.time.year{ii} = [output.time.year{ii}; year{jj}];
        output.time.day{ii} = [output.time.day{ii}; day{jj}];
        output.time.hours{ii} = [output.time.hours{ii}; hours{jj}];
        output.time.minutes{ii} =  [output.time.minutes{ii}; minutes{jj}];
        output.pressure{ii} = [output.pressure{ii}; rawpress{jj}];
        output.temperature{ii} = [output.temperature{ii}; rawtemp{jj}];
        output.battvolt{ii} = [output.battvolt{ii}; rawbatt{jj}];
    end
                    %Now apply pressure calibration
    if ~raw
        %Convert Raw Data into pressure above atmospheric gauge pressure in Pa
        output.pressure{ii} = (output.pressure{ii}-atpress)*6894.75729*20; 
        %Third calculate Effective Pressure = Ice Pressure - Water Pressure.
        output.effpress{ii} = icepress - output.pressure{ii};
    end
                    %complete output
    output.sensor{ii} = sensor_ID;
    output.grid{ii} = grid;
    output.position{ii} = position;
    output.icepress{ii} = icepress;
    output.logger{ii} = log_read;
end
        
end

function [log_read,log_type,chan_read,date_start,date_finish,sensor_ID,grid,position,atpress,multiplier,icepress]  = identify(type,sensor,inst,start,finish)

n_entries = length(inst.sensor_ID);
         %number of possiblities to work through

grid = [];

log_count = 1;

for ii=1:n_entries
    if ((strcmp(type,'sensor') && strcmpi(sensor,inst.sensor_ID{ii})) ||  (strcmp(type,'grid') && strcmpi(sensor,inst.sensor_grid{ii}))...
            || (strcmp(type,'hole') && strcmpi(sensor,inst.hole_ID{ii}))) && ...
        (isnan(inst.uninstall_year(ii)) || inst.uninstall_year(ii) > start.year || (inst.uninstall_year(ii) == start.year && inst.uninstall_day(ii) > start.day)) && ...
        (inst.install_year(ii) < finish.year || (inst.install_year(ii) == finish.year && inst.install_day(ii) < finish.day))
        %assumes no uninstall date may be given but install date
        %always present
        log_read{log_count} = inst.logger_ID{ii};
        log_type{log_count} = inst.logger_type{ii}
        chan_read(log_count) = inst.channel(ii);
        date_start.year(log_count) = max(start.year,inst.install_year(ii));
        if inst.install_year(ii) < start.year
            date_start.day(log_count) = start.day;
            date_start.time(log_count) = 0;
        else
            date_start.day(log_count) = max(start.day,inst.install_day(ii));
            if date_start.day(log_count) == inst.install_day(ii)
                date_start.time(log_count) = inst.install_time(ii);
            else
                date_start.time(log_count) = 0;
            end
        end
        date_finish.year(log_count) = min(finish.year,inst.uninstall_year(ii));
        if isnan(inst.uninstall_year(ii)) || finish.year < inst.uninstall_year(ii)
            date_finish.day(log_count) = finish.day;
            date_finish.time(log_count) = 2400;
        else
            date_finish.day(log_count) = min(finish.day,inst.uninstall_day(ii));
            if date_finish.day(log_count) == inst.uninstall_day(ii)
                date_finish.time(log_count) = inst.uninstall_time(ii);
            else
                date_finish.time(log_count) = 2400;
            end
        end
        if isempty(grid)
            sensor_ID = inst.sensor_ID{ii};
            grid = inst.sensor_grid{ii};
            position.north = inst.sensor_north(ii);
            position.east = inst.sensor_east(ii);
            position.elev = inst.sensor_elev(ii);
            position.thickness = inst.thickness(ii);
            position.nominal_north = inst.nominal_north(ii);
            position.nominal_east = inst.nominal_east(ii);
            atpress = inst.atpress(ii);
            multiplier = inst.multiplier(ii);
            icepress = inst.icepress(ii);
            if isnan(icepress), icepress = inst.thickness(ii)*9.8*916; end
            %use rho*g*h if not already in spreadsheet
        end
        log_count = log_count+1;
    end
end

end
                    
function [year_out,day_out,hours_out,minutes_out,rawpress,rawtemp,rawbatt] = logger_read(log_read,log_type,chan_read,start_year,start_day,start_time,finish_year,finish_day,finish_time,tseries_break,use_offset_data,CR10,use_textscan,filespec)

n_data_out=0;

log_read
log_type
chan_read
start_year
start_day
finish_year
finish_day

%initialize in case data files indicated by metadata file filename_info are
%missing
year_out = []; day_out = []; hours_out = []; minutes_out = []; rawpress = []; rawtemp = []; rawbatt = [];


for year_nominal=start_year:finish_year+1
    for ii = 1:2
        season_names = {'winter' 'summer'};
        season = season_names{ii};
        offset_day = []; offset_time = 0;
        for suffix=0:filespec.suff_max;
            if suffix < 10;
                filename_read=strcat(filespec.path,'/',num2str(year_nominal),'/',season,'/loggers/raw','/',log_read,'.00',num2str(suffix));
                filename_offset=strcat(filespec.path,'/',num2str(year_nominal),'/',season,'/loggers/par','/',log_read,'.p0',num2str(suffix));
            elseif suffix < 100
                filename_read=strcat(filespec.path,'/',num2str(year_nominal),'/',season,'/loggers/raw','/',log_read,'.0',num2str(suffix));
                filename_offset=strcat(filespec.path,'/',num2str(year_nominal),'/',season,'/loggers/par','/',log_read,'.p',num2str(suffix));
            else error('suffix too large')
            end
            if exist(filename_offset,'file') && use_offset_data
                [nothing offset_read] = textread(filename_offset,'%s %s',1,'delimiter','=');
                offset_string = offset_read{1};
                offset_day = str2double(offset_string(1:4));
                lstr = length(offset_string);
                offset_hours = str2double(strcat(offset_string(lstr-8:lstr-6)));
                offset_minutes = str2double(strcat(offset_string([lstr-8 lstr-4:lstr-3])));
                if offset_day ~= 0 || offset_time ~= 0,
                    warning(strcat('For individual data file, detected non-zero time offset of ',num2str(offset_day),' days and ',num2str(offset_time),' hhmm on the 24 hour clock')); 
                end
            elseif isempty(offset_day) 
                offset_day = 0;
                offset_hours = 0;
                offset_minutes = 0;
            end
            if exist(filename_read,'file')
                ver = version;      %use textscan if available
                ver = str2num(ver(1));
                ver = ver(1);
                if ver > 6 && use_textscan
                    disp(strcat('really:',num2str(ver(1)),' > 6'))
                    filename_read
                    fid=fopen(filename_read);
                    if strcmp(log_type,'CR10') || strcmp(log_type,'CR10X')
                        data_in=textscan(fid, '%u %f %f %f %f %f %f %f %f %f %f %f', 'delimiter', ',','emptyvalue',NaN);
                        fclose(fid);
                        n_data_in=length(data_in{1}); % determine the length of vector
                        year=data_in{2};
                        day=data_in{3};
                        time=data_in{4};
                        battvolt=data_in{5};
                        temp=data_in{6};
                        press=data_in{chan_read+6};
                        if CR10
                            year(year<2000)=mod(year(year<2000),2000)+2000; %fix Y2K problem on old loggers
                        end
                    elseif strcmp(log_type,'CR1000')
                        monthlength = cumsum([0 31 28 31 30 31 30 31 31 30 31 30]);
                        monthlength_leap = cumsum([0 31 29 31 30 31 30 31 31 30 31 30]);
                        data_in=textscan(fid, '%s %u %s %s %s %s %s %s %s %s %s %s', 'delimiter', ',','emptyvalue',NaN,'headerlines',4);
                        n_data_in=length(data_in{1});
                        year=zeros(n_data_in,1);
                        day=zeros(n_data_in,1);
                        time=zeros(n_data_in,1);
                        battvolt=zeros(n_data_in,1);
                        temp=zeros(n_data_in,1);
                        press=zeros(n_data_in,1);
                        timestamp_str=data_in{1};
                        battvolt_str=data_in{3};
                        temp_str=data_in{4};
                        press_str=data_in{chan_read+4};
                        for ii=1:n_data_in
                            time_temp=timestamp_str{ii};
                            year(ii)=str2num(time_temp(2:5));
                            month_temp=str2num(time_temp(7:8));
                            day_temp=str2num(time_temp(10:11));
                            if mod(year(ii),4)==0
                                day(ii)=monthlength_leap(month_temp)+day_temp;
                            else
                                day(ii)=monthlength(month_temp)+day_temp;
                            end
                            time(ii)=str2num(time_temp([13:14 16:17]));
                            if strcmp(battvolt_str{ii},'"NAN"')
                                battvolt(ii)=NaN;
                            else
                                battvolt(ii)=str2num(battvolt_str{ii});
                            end
                            if strcmp(temp_str{ii},'"NAN"')
                                temp(ii)=NaN;
                            else
                                temp(ii)=str2num(temp_str{ii});
                            end
                            if strcmp(press_str{ii},'"NAN"')
                                press(ii)=NaN;
                            else
                                press(ii)=str2num(press_str{ii});
                            end
                        end
                    end
                else
                    filename_read
                    if strcmp(log_type,'CR10') || strcmp(log_type,'CR10X')
                        [dummy,year,day,time,battvolt,temp,press1,press2,press3,press4,press5,press6]=...
                            textread(filename_read,'%u %f %f %f %f %f %f %f %f %f %f %f', 'delimiter', ',','emptyvalue',NaN);
                        n_data_in=length(year);
                        if CR10
                            year(year<2000)=mod(year(year<2000),2000)+2000; %fix Y2K problem on old loggers
                        end
                        if length(press6) < n_data_in
                            press2 = [press2; NaN*ones(n_data_in-length(press2),1)];
                            press3 = [press3; NaN*ones(n_data_in-length(press3),1)];
                            press4 = [press4; NaN*ones(n_data_in-length(press4),1)];
                            press5 = [press5; NaN*ones(n_data_in-length(press5),1)];
                            press6 = [press6; NaN*ones(n_data_in-length(press6),1)];
                            %dumb fix for those 2008 files that had fewer than
                            %6 sensors programmed
                        end
                        press=[press1,press2,press3,press4,press5,press6];
                        press=press(:,chan_read);
                    elseif strcmp(log_type,'CR1000')
                        monthlength = cumsum([0 31 28 31 30 31 30 31 31 30 31 30]);
                        monthlength_leap = cumsum([0 31 29 31 30 31 30 31 31 30 31 30]);
                        [timestamp_str,dummy,battvolt_str,temp_str,press1,press2,press3,press4,press5,press6,press7,press8]=...
                            textread(filename_read,'%s %u %s %s %s %s %s %s %s %s %s %s', 'delimiter', ',','emptyvalue',NaN,'headerlines',4);
                        n_data_in=length(timestamp_str)
			if length(press8) < n_data_in && chan_read <= 6
                            press_str=[press1,press2,press3,press4,press5,press6];                        
			    press_str=press_str(:,chan_read);
                            %2011 set-up
                        elseif length(press8) < n_data_in
                            if chan_read == 1, press_str = press1;
                            elseif chan_read == 2, press_str = press2;
                            elseif chan_read == 3, press_str = press3;
                            elseif chan_read == 4, press_str = press4;
                            elseif chan_read == 5, press_str = press5;
                            elseif chan_read == 6, press_str = press6;
                            elseif chan_read == 7, press_str = press7;
                            elseif chan_read == 8, press_str = press8;
                            end
                            %alternative to previous option (should be redundant!) that can accommodate arbitrary numbers of sensors as per the CR10/CR10X code above (for future use)
                        else
                            press_str=[press1,press2,press3,press4,press5,press6,press7,press8];                        
			    press_str=press_str(:,chan_read);
                            %2012 onwards setup
			end
                        year=zeros(n_data_in,1);
                        day=zeros(n_data_in,1);
                        time=zeros(n_data_in,1);
                        battvolt=zeros(n_data_in,1);
                        temp=zeros(n_data_in,1);
                        press=zeros(n_data_in,1);
                        for ii=1:n_data_in
                            time_temp=timestamp_str{ii};
                            year(ii)=str2num(time_temp(2:5));
                            month_temp=str2num(time_temp(7:8));
                            day_temp=str2num(time_temp(10:11));
                            if mod(year(ii),4)==0
                                day(ii)=monthlength_leap(month_temp)+day_temp;
                            else
                                day(ii)=monthlength(month_temp)+day_temp;
                            end
                            time(ii)=str2num(time_temp([13:14 16:17]));
                            if strcmp(battvolt_str{ii},'"NAN"')
                                battvolt(ii)=NaN;
                            else
                                battvolt(ii)=str2num(battvolt_str{ii});
                            end
                            if strcmp(temp_str{ii},'"NAN"')
                                temp(ii)=NaN;
                            else
                                temp(ii)=str2num(temp_str{ii});
                            end
                            if ii > length(press_str) || strcmp(press_str{ii},'"NAN"')
                                press(ii)=NaN;
                            else
                            press(ii)=str2num(press_str{ii});
                            end
                        end
                    end
                end
                minutes = rem(time,100)-offset_minutes;%+offset_minutes;
                hours = fix(time/100)+floor(minutes/60)-offset_hours;%+offset_hours;
                minutes = mod(minutes,60);
                day=day+floor(hours/24)-offset_day;%+offset_day;
                hours = mod(hours,24);
                index=(1:n_data_in)';
                index(year>finish_year|(year==finish_year&day>finish_day)|(year==finish_year&day==finish_day&hours*100+minutes>finish_time)) = [];
                index(year<start_year|(year==start_year&day<start_day)|(year==start_year&day==start_day&hours*100+minutes<start_time)) = [];
                n_data_in=length(index);
                if tseries_break
                    year_out(n_data_out+1:n_data_out+n_data_in+1,1)=[year(index);NaN];
                    day_out(n_data_out+1:n_data_out+n_data_in+1,1)=[day(index);NaN];
                    hours_out(n_data_out+1:n_data_out+n_data_in+1,1)=[hours(index);NaN];
                    minutes_out(n_data_out+1:n_data_out+n_data_in+1,1)=[minutes(index);NaN];
                    rawbatt(n_data_out+1:n_data_out+n_data_in+1,1)=[battvolt(index);NaN];
                    rawtemp(n_data_out+1:n_data_out+n_data_in+1,1)=[temp(index);NaN];
                    rawpress(n_data_out+1:n_data_out+n_data_in+1,1)=[press(index);NaN*ones(1,length(chan_read))];
                 else
                    year_out(n_data_out:n_data_out+n_data_in,1)=year(index);
                    day_out(n_data_out:n_data_out+n_data_in,1)=day(index);
                    hours_out(n_data_out:n_data_out+n_data_in,1)=hours(index);
                    minutes_out(n_data_out:n_data_out+n_data_in,1)=minutes(index);
                    rawbatt(n_data_out:n_data_out+n_data_in,1)=battvolt(index);
                    rawtemp(n_data_out:n_data_out+n_data_in,1)=temp(index);
                    rawpress(n_data_out:n_data_out+n_data_in,1)=press(index);
                end
                n_data_out=length(year_out);
                rawpress(rawpress==-99999) = NaN; %rewrite Campbell NaNs
            end
        end
    end
end

end
