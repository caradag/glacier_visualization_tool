function output = sensor_read_raw(log_read,log_type,chan_read,start_year,start_day,start_time,finish_year,finish_day,finish_time,tseries_break,use_offset_data,CR10,use_textscan,raw)

filespec.path = '/mnt/fuegia/Additions_2013/DATA/';       %directory containing annual data
filespec.suff_max = 20; %maximum suffix of individual data files

if nargin < 4
    start_year = 2012;
    finish_year = 2020;
    start_day = 0;
    finish_day = 366;
end

if nargin < 10 || isempty(tseries_break)
    tseries_break = true;
end
if nargin < 11 || isempty(use_offset_data)
    use_offset_data = false;%true;
end
if nargin < 12 || isempty(CR10)
    CR10 = true;
end
if nargin < 13 || isempty(use_textscan)
    use_textscan = true;
end
if nargin < 14 || isempty(raw)
    raw = false;
end

n_data_out=0;

disp(['Reading ' log_read ' (' log_type ') channel ' num2str(chan_read) ' from ' num2str(start_day) '/' num2str(start_year) ' to ' num2str(finish_day) '/' num2str(finish_year)]);


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
%                     disp(strcat('really:',num2str(ver(1)),' > 6'))
%                     filename_read
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

output.time.year{1} = year_out;
output.time.day{1} = day_out;
output.time.hours{1} = hours_out;
output.time.minutes{1} =  minutes_out;
output.pressure{1} = rawpress;
output.temperature{1} = rawtemp;
output.battvolt{1} = rawbatt;
                   %Now apply pressure calibration
if ~raw
    %Convert Raw Data into pressure above atmospheric gauge pressure in Pa
    rawpress = (rawpress-0.5512)*6894.75729*20; 
    output.pressure{1} = rawpress;
end

end