function output = loggerRead(loggerID,use_offset_data)
%loggerRead(loggerID,use_offset_data)
%Reads the complete time serie of temperature and voltage associated to one
%or more dataloggers.
%
%Input parameters:
%   loggerID: a single or cell array of strings (or integer numbers) 
%        containing identifiers of loggers (e.g. '2379') for which
%        data is to be extracted.
%   use_offset_data: Boolean that specifies whether time offset data contained
%        in raw files metadata. Default is true.
%
%Output format: output structure has fields
%   time:   Matlab serial time stamp
%   temperature: temperature of logger
%   battvolt: voltage of logger
%   loggerType: data logger model (i.e. CR1000, CR10X, CR10, etc..)
%   ...

config;

filename_info = [AccesoryDataFolder sensorReferenceTableFile];
filename_metadata = [AccesoryDataFolder rawFilesMetadata];
filespec.path = rawDataFolder;       %directory containing annual data
filespec.suff_max = 120; %maximum suffix of individual data files

filespec.timeTolerance=0.1/86400; % Tolerate time differences of 0.1 seconds

% Loading metadata
[logger_IDs,logger_types]= textread(filename_info,'%s %s %*f %*s %*s %*s %*s %*f %*s %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f','delimiter',',','emptyvalue',NaN,'headerlines',1);

if nargin<1
    error('loggerRead:No_logger_ID_specified','No logger ID specified, you must specify one or more logger IDs');
end
if strcmp(loggerID,'all')
    loggerID=unique(logger_IDs);
end
if ~iscell(loggerID)
    loggerID={loggerID};
end

% Loading metadata for raw files
metadata=struct;
[metadata.pathName,metadata.ignoreFlag,startOffsetDays,startOffsetHours,startOffsetMinutes,endOffsetDays,endOffsetHours,endOffsetMinutes,metadata.firstValid,metadata.lastValid]...
= textread(filename_metadata,'%s %d %f %f %f %f %f %f %d %s','delimiter',',','headerlines',6,'commentstyle','matlab');
metadata.startOffsetDays=startOffsetDays+startOffsetHours/24+startOffsetMinutes/1440;
metadata.endOffsetDays=endOffsetDays+endOffsetHours/24+endOffsetMinutes/1440;

%Set to defaults for missing inputs
if nargin < 2 || isempty(use_offset_data)
    use_offset_data = true;
end

n_loggers = length(loggerID);

output.time = cell(1,n_loggers);
output.temperature = cell(1,n_loggers);
output.battvolt = cell(1,n_loggers);
output.sourceLine = cell(1,n_loggers);
output.fileNames= cell(1,n_loggers);
output.fileLimits= cell(1,n_loggers);
output.timeShifts= cell(1,n_loggers);
output.inFileDiscontinuities= cell(1,n_loggers);
output.filesSamplingStep= cell(1,n_loggers);
output.loggerType= cell(1,n_loggers);
output.loggerID= cell(1,n_loggers);

for i=1:n_loggers
    disp(['  loggerRead -> processing ' loggerID{i}]);
    output.loggerID{i}= loggerID{i};
    metaID=find(strcmp(loggerID{i},logger_IDs),1,'first');
    if isempty(metaID)
        warning('loggerRead:Logger_ID_not_found','Logger ID not found in metadata, skipping...');
        continue;
    end
    output.loggerType{i}=logger_types{metaID};
    [output.time{i},output.temperature{i},output.battvolt{i},output.sourceLine{i},output.fileNames{i},output.fileLimits{i},output.timeShifts{i},output.filesSamplingStep{i},output.inFileDiscontinuities{i}] = logger_read(loggerID{i},logger_types{metaID},use_offset_data,filespec,metadata);
    %read data - outputs column vectors containing time, temperature, voltage, and accesory data

end
        
end

%% Subfuntion logger read to get data
function [time_out,rawtemp,rawbatt,rawSourceLine,filenames,filelimits,filetimeshift,filetimestep,filediscontinuities] = logger_read(log_read,log_type,use_offset_data,filespec,metadata)

start_year=2008;
[finish_year,~,~]=datevec(now);
n_data_out=0;

disp(['    Reading logger ' log_read '(' log_type ')']);

%initialize in case data files indicated by metadata file filename_info are
%missing
time_out = []; rawtemp = []; rawbatt = [];
rawSourceLine=[]; filenames={}; filelimits=[]; filetimeshift=[]; filetimestep=[]; filediscontinuities=[];

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

                % Retreiving end time
                % We use linux system function tail to quickly get the last line of the file
                % As is some extrange cases it returns a wrong output, we do it twice and make sure both
                % outputs are the same 
                lastLine='a';
                lastLine2='b';
                while ~strcmp(lastLine,lastLine2)
                   [~, lastLine]=system(['tail -n 1 "' filespec.path filename_read '"']);
                   [~, lastLine2]=system(['tail -n 1 "' filespec.path filename_read '"']);
                end
                if isempty(lastLine)
                   error(['Error retreiving last line of ' filename_read ]) 
                end
                lastFieldCount=sum(lastLine==',')+1;
                if lastFieldCount>12
                    extraColumns=lastFieldCount-12;
                end

                switch log_type
                    case {'CR10','CR10X'}
                        fileEndTime=textscan(lastLine, ['%*u %f %f %f %f %f %f %f %f %f %f %f' repmat(' %*f',1,extraColumns) ], 'delimiter', ',','emptyvalue',NaN);
                        fileEndTime=datenum([fileEndTime{1} 1 1])+(fileEndTime{2}-1)+fix(fileEndTime{3}/100)/24+rem(fileEndTime{3},100)/1440;
                        headerLines=0;
                    case 'CR1000'                            
                        fileEndTime=textscan(lastLine,'"%4f-%2f-%2f %2f:%2f:%f" %*u %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f','delimiter',',','emptyvalue',NaN,'TreatAsEmpty','"NAN"');
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

                % Retreiving file's start time
                % As is some extrange cases it returns a wrong output, we do it twice and make sure both
                % outputs are the same 
                firstLine='a';
                firstLine2='b';
                while ~strcmp(firstLine,firstLine2)
                    if headerLines==0
                        % Using linux command head to quickly get fisrt line
                       [~, firstLine]=system(['head -n 1 "' filespec.path filename_read '"']);
                       [~, firstLine2]=system(['head -n 1 "' filespec.path filename_read '"']);
                    else
                        % Using linux command head combined with tail to quickly get the 5th line (fisrt 4 are header lines)
                        [~, firstLine]=system(['head -n ' num2str(headerLines+1) ' "' filespec.path filename_read '" | tail -n 1']);
                        [~, firstLine2]=system(['head -n ' num2str(headerLines+1) ' "' filespec.path filename_read '" | tail -n 1']);
                    end                            
                end
                firstFieldCount=sum(firstLine==',')+1;
                switch log_type
                    case {'CR10','CR10X'}
                        fileStartTime=textscan(firstLine,['%*u %f %f %f %f %f %f %f %f %f %f %f' repmat(' %*f',1,extraColumns) ], 'delimiter', ',','emptyvalue',NaN);
                        fileStartTime=datenum([fileStartTime{1} 1 1])+(fileStartTime{2}-1)+fix(fileStartTime{3}/100)/24+rem(fileStartTime{3},100)/1440;
                    case 'CR1000'
                        fileStartTime=textscan(firstLine,'"%4f-%2f-%2f %2f:%2f:%f" %*u %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f','delimiter',',','emptyvalue',NaN,'TreatAsEmpty','"NAN"');
                        fileStartTime=datenum([fileStartTime{:}]);
                end
                fileStartTime=fileStartTime+startOffset_days;        
             

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
                
                fid=fopen([filespec.path filename_read]);
                if strcmp(log_type,'CR10') || strcmp(log_type,'CR10X')
                    data_in=textscan(fid, ['%*u %f %f %f %f %f %f %f %f %f %f %f' repmat(' %*f',1,extraColumns) ], 'delimiter', ',','emptyvalue',NaN);
                    n_data_in=length(data_in{1}); % determine the length of vector                            

                    % Double check n_in_data length is consistent with the number of lines in the data file
                    if rawLineCount>n_data_in
                        warning('SENSOR_READ:Line_count_mismatch',[num2str(n_data_in) ' data entries readed from a file with ' num2str(rawLineCount) ' lines.']);
                    end
                    year=data_in{1};
                    year(year<2000)=mod(year(year<2000),2000)+2000; %fix Y2K problem on old loggers
                    
                    serialDateTime=datenum(year, 1, 1, fix(data_in{3}/100), rem(data_in{3},100), 0)+data_in{2}-1;
                    
                    battvolt=data_in{4};
                    temp=data_in{5};
                    
                elseif strcmp(log_type,'CR1000')
                    data_in=textscan(fid,'"%4f-%2f-%2f %2f:%2f:%f" %*u %f %f %f %f %f %f %f %f %f %f','delimiter',',','emptyvalue',NaN,'TreatAsEmpty','"NAN"','headerlines',4);                            
                    n_data_in=length(data_in{1});
                    % Double check n_in_data length is consistent with the number of lines in the data file
                    if rawLineCount>n_data_in+4
                        warning('SENSOR_READ:Line_count_mismatch',[num2str(n_data_in) ' data entries readed from a file with ' num2str(rawLineCount) ' lines.']);
                    end
                    
                    serialDateTime=datenum(data_in{1:6});
                    battvolt=data_in{7};
                    temp=data_in{8};

                end
                fclose(fid);                
                
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
                            battvolt(range(1))=nanmean(battvolt(range));
                            temp(range(1))=nanmean(temp(range));
                            % Removing all entries with repeated timestamps but the one we have used to store the mean of the minute                    
                            indexesToRemove(range(2:end))=true;% Storing indices of entries to be removed
                            %disp(['       ' num2str(length(range)-1) ' Repeated timestamps for ' datestr(repeatedTimes(nui)/1440) ' were removed. Entries ' sprintf('%d,',range) ' mean stored in #' num2str(range(1))])
                        end
                    end
                end
                
                % Applying time offsets from metadata
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
                        end
                    end
                end

                raw_n_data_in=n_data_in;
                
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
                
                battvolt(indexesToRemove)=[];
                temp(indexesToRemove)=[];
                
                sourceLine(indexesToRemove)=[];
                
                inFileDiscontinuities(indexesToRemove(1:end-1))=[];
                inFileDiscontinuities=find(inFileDiscontinuities);
                dt(indexesToRemove(1:end-1))=[];
                
                serialDateTime(indexesToRemove)=[];
                n_data_in=length(serialDateTime);

                disp(['      > ' filename_read ' readed -> Samples: ' num2str(raw_n_data_in)]);
                
                if n_data_in>0
                    filelimits(end+1,1:2)=[n_data_out+1,n_data_out+n_data_in];
                    filetimeshift(end+1,1:2)=[startOffset_days, endOffset_days];
                    filenames=cat(1,filenames,filename_read);% Concatenating filenames as a vertcal cell vector
                    if ~isempty(inFileDiscontinuities)
                        filediscontinuities=[filediscontinuities ; [inFileDiscontinuities(:), dt(inFileDiscontinuities)]];
                    end
                    filetimestep(end+1,1)=tipicalTimeStep;                    

                    time_out(n_data_out+1:n_data_out+n_data_in,1)=serialDateTime;
                    rawbatt(n_data_out+1:n_data_out+n_data_in,1)=battvolt;
                    rawtemp(n_data_out+1:n_data_out+n_data_in,1)=temp;
                    rawSourceLine(n_data_out+1:n_data_out+n_data_in,1)=sourceLine;
                    
                end
                n_data_out=length(time_out);
            end
        end
    end
end
end
    