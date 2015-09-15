function output = sensor_read_2014_v3(type,sensor_list,start,finish,raw,tseries_break,use_offset_data,CR10,use_textscan)
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
%max_time_adjust: Maximum amount in minutes that the start of a file is allowed
%       to overlap with the privious file. This is to automatically handle
%       cases were the clock is adjusted backwards in the logger.
%       In this cases the last entries of the prevoius files will be deleted
%       to avoid overlap.
%       If the overlap is bigger than max_time_adjust, a warning will be released
%
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

config;

filename_info = [AccesoryDataFolder sensorReferenceTableFile];
filename_metadata = [AccesoryDataFolder rawFilesMetadata];
filespec.path = rawDataFolder;       %directory containing annual data
filespec.suff_max = 120; %maximum suffix of individual data files

filespec.timeTolerance=0.1/86400; % Tolerate time differences of 0.1 seconds

%Thicknes and ice pressure may change over time (advection, surface mass balance) - do we want a way of including that as
%well? Do any sensors survive long enough to worry about that?
[inst.logger_ID,inst.logger_type,inst.channel,inst.sensor_ID,inst.sensor_make,inst.snubber,inst.hole_ID,inst.thickness,...
        inst.sensor_grid,inst.sensor_north,inst.sensor_east,inst.sensor_elev,inst.nominal_north,inst.nominal_east,inst.install_year,...
        inst.install_day,inst.install_time,inst.uninstall_year,inst.uninstall_day,inst.uninstall_time,...
        inst.atpress,inst.atpress_CR1K,inst.multiplier,inst.icepress]...
    = textread(filename_info,'%s %s %f %s %s %s %s %f %s %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f','delimiter',',',...
    'emptyvalue',NaN,'headerlines',1);
%%Clean up missing install / uninstall times
inst.install_time(isnan(inst.install_time)) = 0;
inst.uninstall_time(isnan(inst.uninstall_time)) = 2400;
inst.atpress(isnan(inst.atpress)) = 0.5512;
inst.atpress_CR1K(isnan(inst.atpress_CR1K)) = inst.atpress(isnan(inst.atpress_CR1K));
inst.multiplier(isnan(inst.multiplier)) = 6894.75729*20; 
%Converts Raw Data into Effective Pressure
%First calculate Water Pressure = Raw Data-Atmospheric Pressure.
%Second conversion of pressure data from PSI to Pa: 1psi=6894.75729
%Pa, full range (reading of 10) = 200 psi.

% Loading metadata for raw files
metadata=struct;
[metadata.pathName,metadata.ignoreFlag,startOffsetDays,startOffsetHours,startOffsetMinutes,endOffsetDays,endOffsetHours,endOffsetMinutes,metadata.firstValid,metadata.lastValid]...
= textread(filename_metadata,'%s %d %f %f %f %f %f %f %d %s','delimiter',',','headerlines',6,'commentstyle','matlab');
metadata.startOffsetDays=startOffsetDays+startOffsetHours/24+startOffsetMinutes/1440;
metadata.endOffsetDays=endOffsetDays+endOffsetHours/24+endOffsetMinutes/1440;

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
    tseries_break = false;
end
if nargin < 7 || isempty(use_offset_data)
    use_offset_data = true;
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
output.time.seconds = cell(1,n_sensor);
output.pressure = cell(1,n_sensor);
output.temperature = cell(1,n_sensor);
output.battvolt = cell(1,n_sensor);
output.sourceLine = cell(1,n_sensor);
output.metadata.files.names= cell(1,n_sensor);
output.metadata.files.limits= cell(1,n_sensor);
output.metadata.files.timeshifts= cell(1,n_sensor);
output.metadata.files.inFileDiscontinuities= cell(1,n_sensor);
output.metadata.files.samplingStep= cell(1,n_sensor);
output.metadata.files.logger= cell(1,n_sensor);
output.metadata.installationTime= cell(1,n_sensor);
output.metadata.uninstallationTime= cell(1,n_sensor);

for ii=1:n_sensor
    disp(['  sensorRead -> processing ' sensor_list{ii}]);
    [log_read,log_type,chan_read,date_start,date_finish,sensor_ID,grid,position,atpress,atpress_CR1K,multiplier,icepress, sensorMake, snubber, hole]  = identify(type,sensor_list{ii},inst,start, finish);
    % outputs vector of logger ids and channels and structures date_start, 
    % date_finish giving the corresponding start and end dates for
    % measurement with fields year and day (Julian day), falling in bracket
    % given by start and finish
    [~,date_order] = sort(date_start.year*1e7 + date_start.day*1e4 +  date_start.time);
    log_read = log_read(date_order);
    log_type = log_type(date_order);
    chan_read = chan_read(date_order);
    date_start.year = date_start.year(date_order);
    date_start.day = date_start.day(date_order);
    date_start.time = date_start.time(date_order);
    date_finish.year = date_finish.year(date_order);
    date_finish.day = date_finish.day(date_order);
    date_finish.time = date_finish.time(date_order);
    % sort dates in ascending order
    % Now read in:
    year = cell(length(log_read),1);
    day = cell(length(log_read),1);
    hours = cell(length(log_read),1);
    minutes = cell(length(log_read),1);
    seconds = cell(length(log_read),1);
    rawpress = cell(length(log_read),1);
    rawtemp = cell(length(log_read),1);
    rawbatt = cell(length(log_read),1);
    sourceLine = cell(length(log_read),1);
    filenames = cell(length(log_read),1);
    filelimits = cell(length(log_read),1);
    filetimeshift = cell(length(log_read),1);
    samplingStep = cell(length(log_read),1);
    inFileDiscontinuities = cell(length(log_read),1);
    loggerInfo = cell(length(log_read),1);
    % Now we loop trough all the logger/channel combinations that store the requested data
    for jj=1:length(log_read)
        [year{jj},day{jj},hours{jj},minutes{jj},seconds{jj},rawpress{jj},rawtemp{jj},rawbatt{jj},sourceLine{jj},filenames{jj},filelimits{jj},filetimeshift{jj},samplingStep{jj},inFileDiscontinuities{jj},loggerInfo{jj}] = logger_read(log_read{jj},log_type{jj},chan_read(jj),date_start.year(jj),date_start.day(jj),date_start.time(jj),date_finish.year(jj),date_finish.day(jj),date_finish.time(jj),tseries_break,use_offset_data,CR10,use_textscan,filespec,metadata);
        %read data - outputs column vectors containing year and day of
        %measurement, raw measurement and raw temperature reading
        
        hookUpTimeStamp=datenum([date_start.year(jj) 1 1 fix(date_start.time(jj)/100) mod(date_start.time(jj),100) 0])-1+date_start.day(jj);
        firstNonNanPress=find(~isnan(rawpress{jj}),1,'first');
        firstNonNanTime=datenum([year{jj}(firstNonNanPress) 1 1 hours{jj}(firstNonNanPress) minutes{jj}(firstNonNanPress) 0])-1+day{jj}(firstNonNanPress);
        if ~isempty(rawpress{jj}) && (isnan(rawpress{jj}(1)) || (firstNonNanTime-(hookUpTimeStamp+samplingStep{jj}(1)))>filespec.timeTolerance)
            warning('SENSOR_READ:Missing_data_after_hookup',['First non-NaN data happen after hook-up for ' sensor_list{ii} ' (hook up at ' num2str(date_start.year(jj)) ',' num2str(date_start.day(jj)) ',' num2str(date_start.time(jj)) ' and first non-NaN at ' num2str(year{jj}(firstNonNanPress)) ',' num2str(day{jj}(firstNonNanPress)) ',' num2str(hours{jj}(firstNonNanPress)*1e2+minutes{jj}(firstNonNanPress)) ')'])
            disp(['File:' filespec.path filenames{jj}{1}]);
        end
    end
    %Splice different loggers:
    for jj=1:length(log_read)
        output.time.year{ii} = [output.time.year{ii}; year{jj}];
        output.time.day{ii} = [output.time.day{ii}; day{jj}];
        output.time.hours{ii} = [output.time.hours{ii}; hours{jj}];
        output.time.minutes{ii} =  [output.time.minutes{ii}; minutes{jj}];
        output.time.seconds{ii} =  [output.time.seconds{ii}; seconds{jj}];
        output.temperature{ii} = [output.temperature{ii}; rawtemp{jj}];
        output.battvolt{ii} = [output.battvolt{ii}; rawbatt{jj}];
        output.sourceLine{ii} = [output.sourceLine{ii}; sourceLine{jj}];
        output.metadata.files.names{ii}= [output.metadata.files.names{ii}; filenames{jj}];
        output.metadata.files.timeshifts{ii}= [output.metadata.files.timeshifts{ii}; filetimeshift{jj}];
        output.metadata.installationTime{ii}=[output.metadata.installationTime{ii}; [date_start.year(jj),date_start.day(jj),date_start.time(jj)]];
        output.metadata.uninstallationTime{ii}=[output.metadata.uninstallationTime{ii}; [date_finish.year(jj),date_finish.day(jj),date_finish.time(jj)]];
        output.metadata.files.logger{ii}= [output.metadata.files.logger{ii}; loggerInfo{jj}];
        output.metadata.files.samplingStep{ii}= [output.metadata.files.samplingStep{ii}; samplingStep{jj}];

        if jj>1
            % Adjusting the indexes to the indexing space of the spliced array
            if ~isempty(filelimits{jj-1})
                filelimits{jj}=filelimits{jj}+filelimits{jj-1}(end,end);
            end
            if ~isempty(inFileDiscontinuities{jj}) && ~isempty(filelimits{jj-1})
                inFileDiscontinuities{jj}(:,1) = inFileDiscontinuities{jj}(:,1)+filelimits{jj-1}(end,end);
            end
        end
        output.metadata.files.limits{ii}= [output.metadata.files.limits{ii}; filelimits{jj}];
        output.metadata.files.inFileDiscontinuities{ii}= [output.metadata.files.inFileDiscontinuities{ii}; inFileDiscontinuities{jj}];

        %Now apply pressure calibration
        if ~raw
        %Convert Raw Data into pressure above atmospheric gauge pressure in Pa
            switch log_type{jj}
                case {'CR1000','CR1000MUX'}
                    output.pressure{ii} = [output.pressure{ii}; (rawpress{jj}-atpress_CR1K)*multiplier];
                otherwise
                    output.pressure{ii} = [output.pressure{ii}; (rawpress{jj}-atpress)*multiplier];                    
            end
        end
    end    
    if ~raw
        %Third calculate Effective Pressure = Ice Pressure - Water Pressure.
        output.effpress{ii} = icepress - output.pressure{ii};
    end
    
    fulltimestamp=int64((output.time.year{ii}*1e9)+(output.time.day{ii}*1e6)+(output.time.hours{ii}*1e4)+(output.time.minutes{ii}*1e2)+round(output.time.seconds{ii}));
    if ~issorted(fulltimestamp)
        warning('SENSOR_READ:Not_sorted',['Data for ' sensor_list{ii} ' is not properly sorted, might contain overlapind data series.']);
    end
    [uniqueTime, ~]=unique(fulltimestamp);
    repeatedCount=length(fulltimestamp)-length(uniqueTime);        
    if repeatedCount>0
        warning('SENSOR_READ:Repeated_timestamps',['Data for ' sensor_list{ii} ' contain repeated timestamps.']);
    end

    %complete output
    output.sensor{ii} = sensor_ID;
    output.grid{ii} = grid;
    output.position{ii} = position;
    output.icepress{ii} = icepress;
    output.logger{ii} = log_read;
    
    output.metadata.sensorMake{ii}=sensorMake;
    output.metadata.snubber{ii}=snubber;
    output.metadata.atmosphericReadingCR10X{ii}=atpress;
    output.metadata.atmosphericReadingCR1000{ii}=atpress_CR1K;
    output.metadata.multiplier{ii}=multiplier;
    output.metadata.hole{ii}=hole;
end
        
end
%% Subfunctions identify to get metadata
function [log_read,log_type,chan_read,date_start,date_finish,sensor_ID,grid,position,atpress,atpress_CR1K,multiplier,icepress, sensorMake, snubber, hole]  = identify(type,sensor,inst,start,finish)

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
        log_type{log_count} = inst.logger_type{ii};
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
            atpress_CR1K = inst.atpress_CR1K(ii);
            multiplier = inst.multiplier(ii);
            sensorMake = inst.sensor_make(ii);
            snubber = inst.snubber(ii);
            hole = inst.hole_ID(ii);            
            icepress = inst.icepress(ii);
            if isnan(icepress), icepress = inst.thickness(ii)*9.8*916; end
            %use rho*g*h if not already in spreadsheet
        end
        log_count = log_count+1;
    end
end

end

%% Subfuntion logger read to get data
function [year_out,day_out,hours_out,minutes_out,seconds_out,rawpress,rawtemp,rawbatt,rawSourceLine,filenames,filelimits,filetimeshift,filetimestep,filediscontinuities,loggerInfo] = logger_read(log_read,log_type,chan_read,start_year,start_day,start_time,finish_year,finish_day,finish_time,tseries_break,use_offset_data,CR10,use_textscan,filespec,metadata)

n_data_out=0;

% Full serial time stamp of sensor start and end
startTime=datenum([start_year 1 1])+(start_day-1)+fix(start_time/100)/24+rem(start_time,100)/1440;
endTime=datenum([finish_year 1 1])+(finish_day-1)+fix(finish_time/100)/24+rem(finish_time,100)/1440;

disp(['    Reading logger ' log_read '(' log_type ') CH#' num2str(chan_read) ', From ' datestr(startTime) ' (DOY ' num2str(start_day) ') To ' datestr(endTime) ' (DOY ' num2str(finish_day) ')']);

%initialize in case data files indicated by metadata file filename_info are
%missing
year_out = []; day_out = []; hours_out = []; minutes_out = []; seconds_out=[]; rawpress = []; rawtemp = []; rawbatt = [];
rawSourceLine=[]; filenames={}; filelimits=[]; filetimeshift=[]; filetimestep=[]; filediscontinuities=[]; loggerInfo={};

ver = version;      %use textscan if available
ver = str2double(ver(1));
ver = ver(1);
season_names = {'winter' 'summer'};        
for year_nominal=start_year:finish_year+1
    for ii = 1:2
        for suffix=0:filespec.suff_max;
            filename_read=['/' num2str(year_nominal) '/' season_names{ii} '/loggers/raw' '/' log_read '.' sprintf('%03d',suffix)];
            fileInfo=dir([filespec.path filename_read]);
            if ~isempty(fileInfo)
                if fileInfo.bytes==0
                    disp(['      Skkiping ' filename_read ', file is EMPTY.']);
                    continue
                end
                startOffset_days = 0;
                endOffset_days = 0;
                firstValid = 1;
                lastValid = 'end';
                metadataIndex=find(strcmp(filename_read,metadata.pathName));
                metadataEntries=length(metadataIndex);
                doSkip=false;
                for me=1:metadataEntries
                    firstValid=metadata.firstValid(metadataIndex(me));
                    lastValid=metadata.lastValid{metadataIndex(me)};
                    % Skkiping blacklisted files
                    if metadata.ignoreFlag(metadataIndex(me)) && firstValid==1 && strcmp(lastValid,'end')
                        disp(['NOTICE: ' filename_read ' ignored as flagged in raw files metadata... skkiping.']);
                        doSkip=true;
                    end
                    if use_offset_data
                        if firstValid==1
                            startOffset_days=metadata.startOffsetDays(metadataIndex(me));
                        end
                        if strcmp(lastValid,'end')
                            endOffset_days=metadata.endOffsetDays(metadataIndex(me));
                        end
                    end
                end
                if doSkip
                    continue
                end
                % We check the file contain data for the current sensor
                % retreiving files start and end dates
                extraColumns=0;
                if ver > 6 && use_textscan
                    % Retreiving end time
                    % We use linux system function tail to quickly get the last line of the file
                    % As is some extrange cases it returns a wrong output, we do it twice and make sure both
                    % outputs are the same 
                    lastLine='a';
                    lastLine2='b';
                    attempts=0;
                    while ~strcmp(lastLine,lastLine2) || isempty(lastLine)
                       [~, lastLine]=system(['tail -n 1 "' filespec.path filename_read '"']);
                       [~, lastLine2]=system(['tail -n 1 "' filespec.path filename_read '"']);
                       if(attempts>30)
                           disp('Warning: More than 30 attempts to retrive last line using:');
                           disp(['tail -n 1 "' filespec.path filename_read '"']);
                           break
                       end
                       attempts=attempts+1;
                    end
                    if isempty(lastLine)
                       error(['Error retreiving last line of ' filename_read ]) 
                    end
                    lastFieldCount=sum(lastLine==',')+1;
                    %Both CR10(X) and CR1000 loggers have 12 data fields,
                    %extraColumns account for extra fields
                    %due to bugs in the probram of some old CR10 or due to
                    %multiplexers
                    if lastFieldCount>12
                        extraColumns=lastFieldCount-12;
                    end
                        
                    switch log_type
                        case {'CR10','CR10X'}
                            fileEndTime=textscan(lastLine, ['%*u %f %f %f %f %f %f %f %f %f %f %f' repmat(' %*f',1,extraColumns) ], 'delimiter', ',','emptyvalue',NaN);
                            fileEndTime=datenum([fileEndTime{1} 1 1])+(fileEndTime{2}-1)+fix(fileEndTime{3}/100)/24+rem(fileEndTime{3},100)/1440;
                            headerLines=0;
                        case {'CR1000','CR1000MUX'}                        
                            fileEndTime=textscan(lastLine,['"%4f-%2f-%2f %2f:%2f:%f" %*u %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f' repmat(' %*f',1,extraColumns) ],'delimiter',',','emptyvalue',NaN,'TreatAsEmpty','"NAN"');
                            fileEndTime=datenum([fileEndTime{:}]);
                            headerLines=4;
                    end
                    fileEndTime=fileEndTime+startOffset_days;
                    % Case file too old
                    if isempty(fileEndTime)
                        [~, rawLineCount]=system(['sed -n ''$='' "' filespec.path filename_read '"']);
                        rawLineCount=str2double(rawLineCount);
                        if rawLineCount<=headerLines
                            disp(['      Skkiping ' filename_read ', file seem to be empty, total lines on file: ' num2str(rawLineCount) ', logger type: ' log_type]);
                            disp(['        Last line in file: ' strtrim(lastLine)]);
                            continue
                        else
                            error(['Couldn''t retrive time from last line of ' filename_read])
                        end
                    end
                    if startTime>fileEndTime
                        disp(['      Skkiping ' filename_read ', file ends before sensor started logging (' datestr(fileEndTime) ')']);
                        continue
                    end
                    
                    % Retreivong file's start time
                    % As is some extrange cases it returns a wrong output, we do it twice and make sure both
                    % outputs are the same 
                    firstLine='a';
                    firstLine2='b';
                    attempts=0;
                    while ~strcmp(firstLine,firstLine2) || isempty(firstLine)
                        if headerLines==0
                            % Using linux command head to quickly get fisrt line
                           [~, firstLine]=system(['head -n 1 "' filespec.path filename_read '"']);
                           [~, firstLine2]=system(['head -n 1 "' filespec.path filename_read '"']);
                        else
                            % Using linux command head combined with tail to quickly get the 5th line (fisrt 4 are header lines)
                            [~, firstLine]=system(['head -n ' num2str(headerLines+1) ' "' filespec.path filename_read '" | tail -n 1']);
                            [~, firstLine2]=system(['head -n ' num2str(headerLines+1) ' "' filespec.path filename_read '" | tail -n 1']);
                        end  
                        if(attempts>30)
                           disp('Warning: More than 30 attempts to retrive first line');
                           break
                        end
                       attempts=attempts+1;
                    end
                    firstFieldCount=sum(firstLine==',')+1;
                    switch log_type
                        case {'CR10','CR10X'}
                            fileStartTime=textscan(firstLine,['%*u %f %f %f %f %f %f %f %f %f %f %f' repmat(' %*f',1,extraColumns) ], 'delimiter', ',','emptyvalue',NaN);
                            fileStartTime=datenum([fileStartTime{1} 1 1])+(fileStartTime{2}-1)+fix(fileStartTime{3}/100)/24+rem(fileStartTime{3},100)/1440;
                        case {'CR1000','CR1000MUX'}
                            fileStartTime=textscan(firstLine,['"%4f-%2f-%2f %2f:%2f:%f" %*u %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f' repmat(' %*f',1,extraColumns) ],'delimiter',',','emptyvalue',NaN,'TreatAsEmpty','"NAN"');
                            fileStartTime=datenum([fileStartTime{:}]);
                    end
                    fileStartTime=fileStartTime+startOffset_days;
                    % Case file too new
                    if endTime<fileStartTime
                        disp(['      Skkiping ' filename_read ', file starts after sensor finished logging (' datestr(fileStartTime) ')']);
                        continue
                    end         
                else
                    disp('Skkiping of files with no relevant data has not being implemented without textscan');
                end                  

                if firstFieldCount~=lastFieldCount
                    disp(['ATTENTION: ' filename_read ' has a different amount of comma separated fields in first and last lines (' num2str(firstFieldCount) ' and ' num2str(lastFieldCount) '). Logger type: ' log_type]);
                    disp(['First line:' strtrim(firstLine)]);
                    disp(['Last  line:' strtrim(lastLine)]);
                end
                if lastFieldCount~=12
                    disp(['ATTENTION: ' filename_read ' has ' num2str(lastFieldCount) ' comma separated fields instead of 12. Logger type: ' log_type]);
                end
                if fileStartTime<datenum([2008 1 1]) || fileEndTime<datenum([2008 1 1])
                    warning('SENSOR_READ:Invalid_time',['Invalid time in ' filename_read ' (last or first lines)']);
                end
                % We count the number of lines in the file to make sure textread/textscan readed the whole file
                [~, rawLineCount]=system(['sed -n ''$='' "' filespec.path filename_read '"']);
                rawLineCount=str2double(rawLineCount);
                
                if ver > 6 && use_textscan
                    %disp(['     loggerRead -> Matlab version: ' num2str(ver(1)) ' > 6'])
                    fid=fopen([filespec.path filename_read]);
                    if strcmp(log_type,'CR10') || strcmp(log_type,'CR10X')
                        data_in=textscan(fid, ['%*u %f %f %f %f %f %f %f %f %f %f %f' repmat(' %*f',1,extraColumns) ], 'delimiter', ',','emptyvalue',NaN);
                        fclose(fid);
                        n_data_in=length(data_in{1}); % determine the length of vector                            data_in=textscan(fid,'"%4f-%2f-%2f %2f:%2f:%f" %*u %f %f %f %f %f %f %f %f','delimiter',',','emptyvalue',NaN,'TreatAsEmpty','"NAN"','headerlines',4);

                        % Double check n_in_data length is consistent with the number of lines in the data file
                        if rawLineCount>n_data_in
                            warning('SENSOR_READ:Line_count_mismatch',[num2str(n_data_in) ' data entries readed from a file with ' num2str(rawLineCount) ' lines.']);
                        end
                        year=data_in{1};
                        day=data_in{2};
                        hours=fix(data_in{3}/100);
                        minutes=rem(data_in{3},100);
                        seconds=zeros(n_data_in,1);
                        battvolt=data_in{4};
                        temp=data_in{5};
                        press=data_in{chan_read+5};
                        press(press==-99999) = NaN; %rewrite Campbell NaNs
                        if CR10
                            year(year<2000)=mod(year(year<2000),2000)+2000; %fix Y2K problem on old loggers
                        end
                    elseif strcmp(log_type,'CR1000') || strcmp(log_type,'CR1000MUX')
                        monthlength = cumsum([0 31 28 31 30 31 30 31 31 30 31 30])';
                        monthlength_leap = cumsum([0 31 29 31 30 31 30 31 31 30 31 30])';
                        data_in=textscan(fid,['"%4f-%2f-%2f %2f:%2f:%f" %*u %f %f %f %f %f %f %f %f %f %f' repmat(' %f',1,extraColumns) ],'delimiter',',','emptyvalue',NaN,'TreatAsEmpty','"NAN"','headerlines',4);                            
                        n_data_in=length(data_in{1});
                        % Double check n_in_data length is consistent with the number of lines in the data file
                        if rawLineCount>n_data_in+4
                            warning('SENSOR_READ:Line_count_mismatch',[num2str(n_data_in) ' data entries readed from a file with ' num2str(rawLineCount) ' lines.']);
                        end
                        
                        year=data_in{1};
                        month_temp=data_in{2};
                        day_temp=data_in{3};
                        hours=data_in{4};
                        minutes=data_in{5};
                        seconds=data_in{6};
                        battvolt=data_in{7};
                        temp=data_in{8};
                        press=data_in{chan_read+8};
                        %clear data_in
                        % Computing day of year
                        leap_years=mod(year,4)==0;
                        day=monthlength(month_temp)+day_temp;
                        day_leap=monthlength_leap(month_temp)+day_temp;
                        day(leap_years)=day_leap(leap_years);
                        
                    end
                else
                    if strcmp(log_type,'CR10') || strcmp(log_type,'CR10X')
                        [~,year,day,time,battvolt,temp,press1,press2,press3,press4,press5,press6]=...
                            textread([filespec.path filename_read],'%u %f %f %f %f %f %f %f %f %f %f %f', 'delimiter', ',','emptyvalue',NaN);
                        n_data_in=length(year);
                        % Double check n_in_data length is consistent with the number of lines in the data file
                        if rawLineCount>n_data_in
                            warning('SENSOR_READ:Line_count_mismatch',[num2str(n_data_in) ' data entries readed from a file with ' num2str(rawLineCount) ' lines.']);
                        end
                        if CR10
                            year(year<2000)=mod(year(year<2000),2000)+2000; %fix Y2K problem on old loggers
                        end
                        hours=fix(time/100);
                        minutes=rem(time,100);
                        seconds=zeros(n_data_in,1);

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
                        press(press==-99999) = NaN; %rewrite Campbell NaNs                        
                    elseif strcmp(log_type,'CR1000') || strcmp(log_type,'CR1000MUX')
                        monthlength = cumsum([0 31 28 31 30 31 30 31 31 30 31 30]);
                        monthlength_leap = cumsum([0 31 29 31 30 31 30 31 31 30 31 30]);
                        [timestamp_str,~,battvolt_str,temp_str,press1,press2,press3,press4,press5,press6,press7,press8]=...
                            textread([filespec.path filename_read],'%s %u %s %s %s %s %s %s %s %s %s %s', 'delimiter', ',','emptyvalue',NaN,'headerlines',4);
                        n_data_in=length(timestamp_str);
                        % Double check n_in_data length is consistent with the number of lines in the data file
                        if rawLineCount>n_data_in+4
                            warning('SENSOR_READ:Line_count_mismatch',[num2str(n_data_in) ' data entries readed from a file with ' num2str(rawLineCount) ' lines.']);
                        end
                        %disp(['     loggerRead -> n_data_in: ' num2str(n_data_in)]);
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
                        clear press1 press2 press3 press4 press5 press6 press7 press8
                        year=zeros(n_data_in,1);
                        day=zeros(n_data_in,1);
                        hours=zeros(n_data_in,1);
                        minutes=zeros(n_data_in,1);
                        seconds=zeros(n_data_in,1);
                        battvolt=zeros(n_data_in,1);
                        temp=zeros(n_data_in,1);
                        press=zeros(n_data_in,1);
                        for datai=1:n_data_in
                            time_temp=timestamp_str{datai};
                            year(datai)=str2double(time_temp(2:5));
                            month_temp=str2double(time_temp(7:8));
                            day_temp=str2double(time_temp(10:11));
                            if mod(year(datai),4)==0
                                day(datai)=monthlength_leap(month_temp)+day_temp;
                            else
                                day(datai)=monthlength(month_temp)+day_temp;
                            end
                            hours(datai)=str2double(time_temp(13:14));
                            minutes(datai)=str2double(time_temp(16:17));
                            seconds(datai)=str2double(time_temp(19:20));
                            if strcmp(battvolt_str{datai},'"NAN"')
                                battvolt(datai)=NaN;
                            else
                                battvolt(datai)=str2double(battvolt_str{datai});
                            end
                            if strcmp(temp_str{datai},'"NAN"')
                                temp(datai)=NaN;
                            else
                                temp(datai)=str2double(temp_str{datai});
                            end
                            if datai > length(press_str) || strcmp(press_str{datai},'"NAN"') || strcmp(press_str{datai},'')
                                press(datai)=NaN;
                            else
                            press(datai)=str2double(press_str{datai});
                            end
                        end
                    end
                end
                
                %Simple full timestamp by aggregating year day hour and minute
                %keyboard
                serialDateTime=datenum([year, ones(n_data_in,1), ones(n_data_in,1), hours, minutes, seconds])+day-1;
                n_data_in=length(serialDateTime);
                                
                sourceLine=1:n_data_in;
                
                % Removing data flagged to be ignored
                indexesToRemove=false(n_data_in,1);
                for me=1:metadataEntries
                    firstValid=metadata.firstValid(metadataIndex(me));
                    lastValid=metadata.lastValid{metadataIndex(me)};
                    if strcmp(lastValid,'end')
                        lastValid=n_data_in;
                    else
                        lastValid=str2double(lastValid);
                    end
                    if metadata.ignoreFlag(metadataIndex(me))
                        indexesToRemove(firstValid:lastValid)=true;
                        disp(['NOTICE: ' filename_read ' ignored from entry ' num2str(firstValid) ' to ' num2str(lastValid) '(total entries = ' num2str(n_data_in) ')']);
                    end
                end                
                
                % Now we make sure there is no repeated timestamps, and if there are, we average them
                if any(diff(serialDateTime(~indexesToRemove))==0) % if in any of the timestamps is equal to the next
                    serialMinutes=floor(serialDateTime*1440);
                    [~, uniqueTime]=unique(serialMinutes);%Finding indices of unique timestapm
                    nonUnique=true(n_data_in,1);% Inizalization of variable to hold repeated timestamps
                    nonUnique(uniqueTime)=false;% Indices of all repeated timestamps
                    nonUnique(indexesToRemove)=false;% Ignoring data that will be removed
                    repeatedTimes=unique(serialMinutes(nonUnique));% List of all repeated timestamps, but only one of each found in the repeated set
                    repeatedCount=length(repeatedTimes); % Count of repeated timestamps
                    disp(['NOTICE: ' filename_read ' has ' num2str(repeatedCount) ' timestamps with multiple associated data values, entries belonging to the same minute will be averaged.'])
                    for nui=1:repeatedCount
                        allInMinute=find(serialMinutes==repeatedTimes(nui) & ~indexesToRemove);% Indices of all entries corresponding to current repeated timestamp
                        % Finding contiguous intervals of repeated data
                        intervalStarts=[0 find(diff(allInMinute)~=1)]+allInMinute(1);
                        intervalEnds=[intervalStarts(2:end)-1, allInMinute(end)];
                        longerThanOneIntervals=intervalStarts~=intervalEnds;
                        intervalStarts=intervalStarts(longerThanOneIntervals);
                        intervalEnds=intervalEnds(longerThanOneIntervals);
                        for interval=1:length(intervalStarts)
                            range=intervalStarts:intervalEnds;
                            % Assigning mean values to the first entry with current repeated timestamp
                            press(range(1))=nanmean(press(range));
                            battvolt(range(1))=nanmean(battvolt(range));
                            temp(range(1))=nanmean(temp(range));
                            % Removing all entries with repeated timestamps but the one we have used to store the mean of the minute                    
                            indexesToRemove(range(2:end))=true;% Storing indices of entries to be removed
                            %disp(['       ' num2str(length(range)-1) ' Repeated timestamps for ' datestr(repeatedTimes(nui)/1440) ' were removed. Entries ' sprintf('%d,',range) ' mean stored in #' num2str(range(1))])
                        end
                    end
                end
                
                % Applying time offsets from metadata
                doUpdateTime=false;
                if use_offset_data
                    for me=1:metadataEntries
                        firstValid=metadata.firstValid(metadataIndex(me));
                        lastValid=metadata.lastValid{metadataIndex(me)};
                        if strcmp(lastValid,'end')
                            lastValid=n_data_in;
                        else
                            lastValid=str2double(lastValid);
                        end
                        range=firstValid:lastValid;
                        if metadata.startOffsetDays(metadataIndex(me))~=0
                            serialDateTime(range)=serialDateTime(range)+metadata.startOffsetDays(metadataIndex(me));
                            disp(['NOTICE: ' filename_read ' -> Non-zero initial time offset of ' num2str(startOffset_days) ' days found. from #' num2str(firstValid) ' to ' num2str(lastValid)]);
                            doUpdateTime=true;
                        end
                        if metadata.endOffsetDays(metadataIndex(me))~=0 
                            % If there is an end of file offset (usually found when the datalloger is serviced for first time at the begin of summer)
                            % We stretch the time scale of the file to account for that offset
                            %
                            % relativeSetialtime contains times relative to the start of the file
                            relativeSerialtime=serialDateTime(range)-serialDateTime(range(1));
                            % Calculate the multiplication factor for the previous file time scale
                            factor=(relativeSerialtime(end)+metadata.endOffsetDays(metadataIndex(me)))/relativeSerialtime(end);
                            relativeSerialtime=relativeSerialtime*factor;
                            % Now we put together the corrected time scale
                            serialDateTime(range)=relativeSerialtime+serialDateTime(range(1));
                            disp(['NOTICE: ' filename_read ' -> Non-zero final time offset of ' num2str(startOffset_days) ' days found. from #' num2str(firstValid) ' to ' num2str(lastValid)]);
                            doUpdateTime=true;
                        end
                    end
                end
                if doUpdateTime
                    % Recomputing time variables
                    [year, ~, ~, hours, minutes, seconds]=datevec(serialDateTime);
                    day=floor(serialDateTime-datenum([year, ones(n_data_in,1), ones(n_data_in,1)])+1);
                end

                raw_n_data_in=n_data_in;
                % Removing indexes out of bounds or declared as invalid in metadata
                indexesToRemove= indexesToRemove | (serialDateTime<(startTime-filespec.timeTolerance) | (serialDateTime>(endTime+filespec.timeTolerance)));
                
                if n_data_in>1
                    % Checking data in file is sorted
                    dt=diff(serialDateTime);
                    if ~issorted(serialDateTime(~indexesToRemove))
                        warning('SENSOR_READ:Not_sorted',['Data on file ' filename_read ' is NOT sorted.'])
                        unsorted=find(dt<0 & ~indexesToRemove(1:end-1));
                        n_unsorted=length(unsorted);
                        if n_unsorted>0
                            disp([num2str(n_unsorted) ' unsorted entries, being the first one #' num2str(unsorted(1))]);
                            if n_unsorted>1
                                andMore='';
                                if n_unsorted>20
                                    andMore='...';
                                end
                                disp(['Other unsorted entries are: ' sprintf('%d,',unsorted(2:min(n_unsorted,20))) andMore]);
                            end
                        else
                            disp('Unsorted elements could not be identified');
                        end
                    end

                    % Checking data in file uses a regular time step                
                    tipicalTimeStep=median(dt(dt~=0 & ~indexesToRemove(1:end-1)));
                    inFileDiscontinuities=abs(dt-tipicalTimeStep)>(1/86400) & dt~=0 & ~indexesToRemove(1:end-1);
                    n_akwardJumps=sum(inFileDiscontinuities);
                    if n_akwardJumps>0
                        disp(['NOTICE: ' filename_read ' -> data contain ' num2str(n_akwardJumps) ' non regular time jumps (typical time step ' num2str(tipicalTimeStep*1440) ' minutes).'])
                        jumpsizes=unique(dt(inFileDiscontinuities));
                        for js=1:length(jumpsizes)
                            jumpIndexes=find(dt==jumpsizes(js) & ~indexesToRemove(1:end-1));
                            if length(jumpIndexes)>1
                                disp(['        ' filename_read '-> Jump of ' num2str(jumpsizes(js)*1440) ' minutes at entries: ' sprintf('%d,',jumpIndexes)]);
                            else
                                disp(['        ' filename_read '-> Jump of ' num2str(jumpsizes(js)*1440) ' minutes at entry: ' num2str(jumpIndexes) ', voltage change: ' num2str(battvolt(jumpIndexes)) ' -> ' num2str(battvolt(jumpIndexes+1)) 'v']);
                            end
                        end
                    end
                else
                    tipicalTimeStep=NaN;
                end
                
                press(indexesToRemove)=[];
                battvolt(indexesToRemove)=[];
                temp(indexesToRemove)=[];

                year(indexesToRemove)=[];
                day(indexesToRemove)=[];
                hours(indexesToRemove)=[];
                minutes(indexesToRemove)=[];
                seconds(indexesToRemove)=[];
                
                sourceLine(indexesToRemove)=[];
                
                inFileDiscontinuities(indexesToRemove(1:end-1))=[];
                inFileDiscontinuities=find(inFileDiscontinuities);
                dt(indexesToRemove(1:end-1))=[];
                
                serialDateTime(indexesToRemove)=[];
                n_data_in=length(serialDateTime);

                disp(['      > ' filename_read ' readed -> Samples: ' num2str(raw_n_data_in) ' In-bounds valid samples: ' num2str(n_data_in) ' NaN samples: ' num2str(sum(isnan(press)))]);
                
                if n_data_in>0
                    filelimits(end+1,1:2)=[n_data_out+1,n_data_out+n_data_in];
                    filetimeshift(end+1,1:2)=[startOffset_days, endOffset_days];
                    filenames=cat(1,filenames,filename_read);% Concatenating filenames as a vertcal cell vector
                    loggerInfo=cat(1,loggerInfo,{log_read,log_type,chan_read});% Concatenating logger info as a vertcal cell vector
                    if ~isempty(inFileDiscontinuities)
                        filediscontinuities=[filediscontinuities ; [inFileDiscontinuities(:), dt(inFileDiscontinuities)]];
                    end
                    filetimestep(end+1,1)=tipicalTimeStep;
                    
                    if tseries_break
                        year_out(n_data_out+1:n_data_out+n_data_in+1,1)=[year;NaN];
                        day_out(n_data_out+1:n_data_out+n_data_in+1,1)=[day;NaN];
                        hours_out(n_data_out+1:n_data_out+n_data_in+1,1)=[hours;NaN];
                        minutes_out(n_data_out+1:n_data_out+n_data_in+1,1)=[minutes;NaN];
                        seconds_out(n_data_out+1:n_data_out+n_data_in+1,1)=[seconds;NaN];
                        rawbatt(n_data_out+1:n_data_out+n_data_in+1,1)=[battvolt;NaN];
                        rawtemp(n_data_out+1:n_data_out+n_data_in+1,1)=[temp;NaN];
                        rawpress(n_data_out+1:n_data_out+n_data_in+1,1)=[press;NaN*ones(1,length(chan_read))];
                        rawSourceLine(n_data_out+1:n_data_out+n_data_in+1,1)=[sourceLine; NaN*ones(1,length(chan_read))];
                     else
                        year_out(n_data_out+1:n_data_out+n_data_in,1)=year;
                        day_out(n_data_out+1:n_data_out+n_data_in,1)=day;
                        hours_out(n_data_out+1:n_data_out+n_data_in,1)=hours;
                        minutes_out(n_data_out+1:n_data_out+n_data_in,1)=minutes;
                        seconds_out(n_data_out+1:n_data_out+n_data_in,1)=seconds;
                        rawbatt(n_data_out+1:n_data_out+n_data_in,1)=battvolt;
                        rawtemp(n_data_out+1:n_data_out+n_data_in,1)=temp;
                        rawpress(n_data_out+1:n_data_out+n_data_in,1)=press;
                        rawSourceLine(n_data_out+1:n_data_out+n_data_in,1)=sourceLine;
                    end
                    
                end
                n_data_out=length(year_out);
            end
        end
    end
end
end
    