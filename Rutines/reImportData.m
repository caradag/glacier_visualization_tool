function reImportData(source,eventdata)
%path(path,'Rutines');
global data const

if ~isempty(data)
    disp('Previous data found in workspace.');
    importMode = questdlg('Do you want to keep deleted and shift masks?','Data import','Discard','Keep','Cancel','Keep');
else
    disp('Previous data NOT found in workspace.');
    importMode = 'Discard';
end

if isempty(const)
    const=loadConfiguration();
end

doDiagnostic=true;

if strcmp(importMode,'Cancel')
    disp('Data import cancelled by user.');
    return
end

%retiving full list of existing sensors
sensor_ID=textread([const.AccesoryDataFolder filesep const.sensorReferenceTableFile],'%*s %*s %*f %s %*s %*s %*s %*f %*s %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f %*f','delimiter',',','emptyvalue',NaN,'headerlines',1);
emptyLines = cellfun(@isempty, sensor_ID);
sensor_ID=unique(sensor_ID(~emptyLines));
path(path,'Import Export scripts');

%Opening importing log
fid=fopen('importLog.txt','w');

%creating data structure container
%data=[];
metadata=struct;
sensors={};
sensorCount=length(sensor_ID);
allwaysPlot=0;
for i=1:sensorCount
%         if ~strcmp(sensor_ID{i},'10P20')
%             continue
%         end
        anomalousData=false;
        sensorcode=['S' sensor_ID{i}];
        sensors{end+1}=sensorcode;
        %importing data for current sensor##############################
        % IF SENSOR READ FUNCTION HAS BEEIN UPDATED, USE THE NEWER VERSION HERE
        disp(['########################### ' sensor_ID{i} ' (' num2str(i) ' of ' num2str(sensorCount) ') #################################']);
        switch sensor_ID{i}(3)
            case 'P'
                %continue;
                sdata=rmfield(sensor_read_2014_v3('sensor',sensor_ID(i)), 'sensor');
                
                %computing serial timestamps
                timelen=length(sdata.time.year{:});
                serialyear=datenum([double(sdata.time.year{:}) repmat([1 1 0 0 0],timelen,1)])-1;
                serialday=double(sdata.time.day{:});
                serialhours=double(sdata.time.hours{:})/24;
                serialminutes=double(sdata.time.minutes{:})/(24*60);
                serialseconds=double(sdata.time.seconds{:})/(24*60*60);
                if ~isempty(serialyear)
                    sdata.time.serialtime=serialyear+serialday+serialhours+serialminutes+serialseconds;        
                else
                    sdata.time.serialtime=[];
                end
                
                % removing unnecesary or deprecated fields
                if isfield(sdata, 'effpress')
                    sdata=rmfield(sdata, 'effpress');
                end   
                sdata.time = rmfield(sdata.time, 'year');
                sdata.time = rmfield(sdata.time, 'day');
                sdata.time = rmfield(sdata.time, 'hours');
                sdata.time = rmfield(sdata.time, 'minutes');
                sdata.time = rmfield(sdata.time, 'seconds');  

            case {'D','C','L'}
                sdata=sensor_read_digital(sensor_ID{i});
            otherwise
                warning(['Unrecognized type of sensor ' sensor_ID{i}]);
                continue;
        end
        


        fprintf(fid,'####### Sensor %s ########\n',sensor_ID{i});
        fprintf(fid,'%d samples from %s to %s\n',length(sdata.time.serialtime), datestr(min(sdata.time.serialtime)),datestr(max(sdata.time.serialtime)));
        
        validData=~isnan(sdata.time.serialtime);
        nanTimestamps=sum(~validData);
        nanPos=find(~validData);
        if nanTimestamps>0
            anomalousData=true;
            fprintf(1,'%d NaN timestamps removed\n',nanTimestamps);
            fprintf(fid,'%d NaN timestamps removed\n',nanTimestamps);
            for n=1:length(nanPos)
                fprintf(1,'%d -> NaN',nanPos(n));
                fprintf(fid,'%d -> NaN',nanPos(n));
                prevNonNan=nanPos(n);
                postNonNan=nanPos(n);
                while prevNonNan>0 && isnan(sdata.time.serialtime(prevNonNan))
                    prevNonNan=prevNonNan-1;
                end
                if prevNonNan>0
                    fprintf(1,' after %s (DOY %d)',datestr(sdata.time.serialtime(prevNonNan)),DOY(sdata.time.serialtime(prevNonNan)));
                    fprintf(fid,' after %s (DOY %d)',datestr(sdata.time.serialtime(prevNonNan)),DOY(sdata.time.serialtime(prevNonNan)));
                end
                while postNonNan<=timelen && isnan(sdata.time.serialtime(postNonNan))
                    postNonNan=postNonNan+1;
                end
                if postNonNan<=timelen
                    fprintf(1,' and before %s (DOY %d)',datestr(sdata.time.serialtime(postNonNan)),DOY(sdata.time.serialtime(postNonNan)));
                    fprintf(fid,' and before %s (DOY %d)',datestr(sdata.time.serialtime(postNonNan)),DOY(sdata.time.serialtime(postNonNan)));
                end
                fprintf(1,'\n',nanPos(n));
                fprintf(fid,'\n',nanPos(n));
            end  
        end

        % Changing data types to optimize memory and getiting rid of NaN
        % timestamps
        sdata.time.serialtime=sdata.time.serialtime(validData);
        sdata.pressure={single(sdata.pressure{1}(validData))};
        sdata.temperature={single(sdata.temperature{1}(validData))};
        sdata.battvolt={single(sdata.battvolt{1}(validData))};        
        sdata.sourceLine={uint32(sdata.sourceLine{1}(validData))};      

        % Saving a copy of the original data
        originalData.time.serialtime=sdata.time.serialtime;
        originalData.pressure={single(sdata.pressure{1})};
        originalData.temperature={single(sdata.temperature{1})};
        %originalData.battvolt={single(sdata.battvolt{1})};
        

        uRec=length(sdata.time.serialtime);
        sortIdx=1:uRec;
        [uniqueTime, uniqueIdx]=unique(sdata.time.serialtime);
        repeatedCount=uRec-length(uniqueTime);
        if repeatedCount~=0
            anomalousData=true;
            fprintf(1,'!!! %d Repeated time stamps found\n',repeatedCount);
            fprintf(fid,'!!! %d Repeated time stamps found\n',repeatedCount);
            sortIdx=uniqueIdx;
        end
        if ~issorted(sdata.time.serialtime)
            anomalousData=true;
            fprintf(1,'!!! Data NOT sorted\n');
            fprintf(fid,'!!! Data NOT sorted\n');
            sortIdx=uniqueIdx;
        end
        
        % If data anomalies were found and the diagnostic flag is true we
        % plot data
        if (anomalousData && doDiagnostic) || allwaysPlot
           cmenu = [];
           figure('Name',[sensorcode ' #' num2str(i)]);
           % Ploting a red line along repeated timestamps
           minp=min(sdata.pressure{1});
           maxp=max(sdata.pressure{1});
           mint=min(sdata.temperature{1});
           maxt=max(sdata.temperature{1});
           repeatedIdx=true(uRec,1);
           repeatedIdx(uniqueIdx)=false;
           repeatedTimes=unique(sdata.time.serialtime(repeatedIdx));
           repeatedCount=length(repeatedTimes);
           plotCount=2;
           if repeatedCount==0
               plotCount=3;
           end
           if repeatedCount>0
               linesToPlot=1:repeatedCount;
               if repeatedCount>200
                   linesToPlot=[1:100, repeatedCount-100:repeatedCount];
               end
               for fi=linesToPlot
                   subplot(plotCount,1,1);
                   hold on
                   box on
                   cmenu(end+1) = uicontextmenu;
                   plot([1 1]*repeatedTimes(fi),[minp maxp],'-r','UIContextMenu', cmenu(end));
                   uimenu(cmenu(end), 'Label', ['Time: ' datestr(repeatedTimes(fi)) ' (' datestr(repeatedTimes(fi),'yyyy') ',' num2str(DOY(repeatedTimes(fi))) ',' datestr(repeatedTimes(fi),'HH:MM') ')']);
                   indexesForThisTime=find(sdata.time.serialtime==repeatedTimes(fi));
                   for iftt=1:length(indexesForThisTime)
                       fileIndex=find(sdata.metadata.files.limits{1}(:,1)<=indexesForThisTime(iftt) & sdata.metadata.files.limits{1}(:,2)>=indexesForThisTime(iftt));
                       uimenu(cmenu(end), 'Label', ['Value: ' num2str(sdata.pressure{1}(indexesForThisTime(iftt))) ' on ' sdata.metadata.files.names{1}{fileIndex} '(' num2str(diff(sdata.metadata.files.limits{1}(fileIndex,:))+1) ' records)'],'Callback',['clipboard(''copy'',''' sdata.metadata.files.names{1}{fileIndex} ''')']);
                   end

                   subplot(plotCount,1,2);
                   hold on
                   box on
                   cmenu(end+1) = uicontextmenu;
                   plot([1 1]*repeatedTimes(fi),[mint maxt],'-r','UIContextMenu', cmenu(end));
                   uimenu(cmenu(end), 'Label', ['Time: ' datestr(repeatedTimes(fi)) ' (' datestr(repeatedTimes(fi),'yyyy') ' ' num2str(DOY(repeatedTimes(fi))) ' ' datestr(repeatedTimes(fi),'HH:MM') ')']);
                   for iftt=1:length(indexesForThisTime)
                       fileIndex=find(sdata.metadata.files.limits{1}(:,1)<=indexesForThisTime(iftt) & sdata.metadata.files.limits{1}(:,2)>=indexesForThisTime(iftt));
                       uimenu(cmenu(end), 'Label', ['Value: ' num2str(sdata.temperature{1}(indexesForThisTime(iftt))) ' on ' sdata.metadata.files.names{1}{fileIndex} '(' num2str(diff(sdata.metadata.files.limits{1}(fileIndex,:))+1) ' records)'],'Callback',['clipboard(''copy'',''' sdata.metadata.files.names{1}{fileIndex} ''')']);
                   end
               end
               if repeatedCount>200
                   subplot(plotCount,1,1);
                   plot([repeatedTimes(100) repeatedTimes(end-100)],[maxp minp],'-r');
                   plot([repeatedTimes(100) repeatedTimes(end-100)],[minp maxp],'-r');
                   subplot(plotCount,1,2);
                   plot([repeatedTimes(100) repeatedTimes(end-100)],[maxt mint],'-r');
                   plot([repeatedTimes(100) repeatedTimes(end-100)],[mint maxt],'-r');
               end
           end
           % Ploting data
           markers='x+';
           for fi=1:size(sdata.metadata.files.limits{1},1)
               fileRange=sdata.metadata.files.limits{1}(fi,1):sdata.metadata.files.limits{1}(fi,2);
               % Plotting pressure
               subplot(plotCount,1,1);
               hold on
               box on
               title([sensorcode ' diagnostic plot. ' num2str(repeatedCount) ' epochs with multiple data values.']);
               colors='bg';
               cmenu(end+1) = uicontextmenu;
               plot(sdata.time.serialtime(fileRange),sdata.pressure{1}(fileRange),[markers(mod(fi,2)+1) '-' colors(mod(fi,2)+1)],'UIContextMenu', cmenu(end));
               uimenu(cmenu(end), 'Label', ['Pressure from file: ' sdata.metadata.files.names{1}{fi}],'Callback',['clipboard(''copy'',''' sdata.metadata.files.names{1}{fi} ''')']);
               % Plotting temperature
               subplot(plotCount,1,2);
               hold on
               box on
               colors='ym';
               cmenu(end+1) = uicontextmenu;
               plot(sdata.time.serialtime(fileRange),sdata.temperature{1}(fileRange),[markers(mod(fi,2)+1) '-' colors(mod(fi,2)+1)],'UIContextMenu', cmenu(end));
               uimenu(cmenu(end), 'Label', ['Temperature from file: ' sdata.metadata.files.names{1}{fi}],'Callback',['clipboard(''copy'',''' sdata.metadata.files.names{1}{fi} ''')']);
               if plotCount==3
                   %Plotting time
                   subplot(plotCount,1,3);
                   hold on
                   box on                   
                   colors='kr';
                   cmenu(end+1) = uicontextmenu;
                   plot(sdata.time.serialtime(fileRange),fileRange,[markers(mod(fi,2)+1) '-' colors(mod(fi,2)+1)],'UIContextMenu', cmenu(end));
                   uimenu(cmenu(end), 'Label', ['Timestamp from file: ' sdata.metadata.files.names{1}{fi}],'Callback',['clipboard(''copy'',''' sdata.metadata.files.names{1}{fi} ''')']);
               end
           end
           if plotCount==3
               % To make easier to identify the unsorted items we put a red line in all the ones greater than the folowing
               unsorted=find(diff(sdata.time.serialtime)<0);
               dataLength=length(sdata.time.serialtime);
               for us=1:length(unsorted)
                   cmenu(end+1) = uicontextmenu;
                   plot([1 1]*sdata.time.serialtime(unsorted(us)),[1 dataLength],'-r','UIContextMenu', cmenu(end));
                   uimenu(cmenu(end), 'Label', ['Time: ' datestr(sdata.time.serialtime(unsorted(us))) ' (' datestr(sdata.time.serialtime(unsorted(us)),'yyyy') ' ' num2str(DOY(sdata.time.serialtime(unsorted(us)))) ' ' datestr(sdata.time.serialtime(unsorted(us)),'HH:MM:SS') ')']);
                   fileIndex=find(sdata.metadata.files.limits{1}(:,1)<=unsorted(us) & sdata.metadata.files.limits{1}(:,2)>=unsorted(us));
                   uimenu(cmenu(end), 'Label', ['On file ' sdata.metadata.files.names{1}{fileIndex} '(' num2str(diff(sdata.metadata.files.limits{1}(fileIndex,:))+1) ' records)'],'Callback',['clipboard(''copy'',''' sdata.metadata.files.names{1}{fileIndex} ''')']);
                   if unsorted(us)+1<=dataLength
                       uimenu(cmenu(end), 'Label', ['Next time: ' datestr(sdata.time.serialtime(unsorted(us)+1)) ' (' datestr(sdata.time.serialtime(unsorted(us)+1),'yyyy') ' ' num2str(DOY(sdata.time.serialtime(unsorted(us)+1))) ' ' datestr(sdata.time.serialtime(unsorted(us)+1),'HH:MM:SS') ')']);
                       fileIndex=find(sdata.metadata.files.limits{1}(:,1)<=unsorted(us)+1 & sdata.metadata.files.limits{1}(:,2)>=unsorted(us)+1);
                       uimenu(cmenu(end), 'Label', ['Next time file ' sdata.metadata.files.names{1}{fileIndex} '(' num2str(diff(sdata.metadata.files.limits{1}(fileIndex,:))+1) ' records)'],'Callback',['clipboard(''copy'',''' sdata.metadata.files.names{1}{fileIndex} ''')']);
                   end
                   if unsorted(us)>1
                       uimenu(cmenu(end), 'Label', ['Prev time: ' datestr(sdata.time.serialtime(unsorted(us)-1)) ' (' datestr(sdata.time.serialtime(unsorted(us)-1),'yyyy') ' ' num2str(DOY(sdata.time.serialtime(unsorted(us)-1))) ' ' datestr(sdata.time.serialtime(unsorted(us)-1),'HH:MM:SS') ')']);
                       fileIndex=find(sdata.metadata.files.limits{1}(:,1)<=unsorted(us)-1 & sdata.metadata.files.limits{1}(:,2)>=unsorted(us)-1);
                       uimenu(cmenu(end), 'Label', ['Prev time file ' sdata.metadata.files.names{1}{fileIndex} '(' num2str(diff(sdata.metadata.files.limits{1}(fileIndex,:))+1) ' records)'],'Callback',['clipboard(''copy'',''' sdata.metadata.files.names{1}{fileIndex} ''')']);
                   end
               end
           end
           for pc=1:plotCount
               subplot(plotCount,1,pc);
               datetick(gca);
           end
        end
        %sorting data
        sdata.time.serialtime=sdata.time.serialtime(sortIdx);
        sdata.pressure={sdata.pressure{1}(sortIdx)};
        sdata.temperature={sdata.temperature{1}(sortIdx)};
        sdata.battvolt={sdata.battvolt{1}(sortIdx)};  
        
        %############ METADATA AND QUALITY CHECK #################
        if isfield(data, sensorcode)
            % START TIME
            oStart=min(data.(sensorcode).time.serialtime);
            uStart=min(sdata.time.serialtime);
            oEnd=max(data.(sensorcode).time.serialtime);
            uEnd=max(sdata.time.serialtime);
            oRec=sum(~isnan(data.(sensorcode).time.serialtime));
            uRec=length(sdata.time.serialtime);
            fprintf(fid,'Previous data found: %d samples from %s to %s\n',oRec, datestr(oStart),datestr(oEnd));

            if abs(uStart-oStart) > (1/86400)
                if uStart > oStart
                    disp(['    !!Later start time for ' sensorcode ': ' datestr(uStart) ' v/s ' datestr(oStart)]);
                    fprintf(fid,['!!Later start time for ' sensorcode ': ' datestr(uStart) ' v/s ' datestr(oStart) '\n']);
                else
                    disp(['    !!Earlier start time for ' sensorcode ': ' datestr(uStart) ' v/s ' datestr(oStart)]);
                    fprintf(fid,['!!Earlier start time for ' sensorcode ': ' datestr(uStart) ' v/s ' datestr(oStart) '\n']);
                end
            end
            % END TIME
            if isempty(uEnd) || isempty(oEnd)
                disp(['    Empty start time for ' sensorcode]);
                fprintf(fid,['!!Empty start time for ' sensorcode '\n']);
            elseif abs(uEnd-oEnd) > (1/86400) && uEnd < oEnd
                disp(['    !!Earlier end time for ' sensorcode ': ' datestr(uEnd) ' v/s ' datestr(oEnd)]);
                fprintf(fid,['!!Earlier end time for ' sensorcode ': ' datestr(uEnd) ' v/s ' datestr(oEnd) '\n']);
            end
            % RECORDS COUNT
            if uRec < oRec
                disp(['    !!Updated data has less records than old data for ' sensorcode ': ' num2str(uRec) ' v/s ' num2str(oRec)]);
                fprintf(fid,['!!Updated data has less records than old data for ' sensorcode ': ' num2str(uRec) ' v/s ' num2str(oRec) '\n']);
            elseif (uRec > oRec) && (uEnd==oEnd) && (uStart==oStart)
                disp(['    !!Updated data has more records but the same time span ' sensorcode ': ' num2str(uRec) ' v/s ' num2str(oRec)]);
                fprintf(fid,['!!Updated data has more records but the same time span ' sensorcode ': ' num2str(uRec) ' v/s ' num2str(oRec) '\n']);
                [newElements, newIndexes]=setdiff(sdata.time.serialtime,data.(sensorcode).time.serialtime);
                for element=1:length(newElements)
                    if isnan(newElements(element))
                        disp([num2str(newIndexes(element)) ' -> NaN']);
                    else
                        if isempty(find(abs(sdata.time.serialtime-newElements(element))<(0.1/86400)))
                            disp([num2str(newIndexes(element)) ' -> ' datestr(sdata.time.serialtime(newIndexes(element)))]);
                        end
                    end
                end
            end
        
            % GRID POSITION
            if ~strcmp(sdata.grid{1},data.(sensorcode).grid{1})
                disp(['    !!Grid position changed for ' sensorcode ': ' sdata.grid{1} ' v/s ' data.(sensorcode).grid{1}]);
                fprintf(fid,['!!Grid position changed for ' sensorcode ': ' sdata.grid{1} ' v/s ' data.(sensorcode).grid{1} '\n']);
            end

            % POSITION
            if (~isnan(sdata.position{1}.north) && (sdata.position{1}.north ~= data.(sensorcode).position{1}.north)) ||...
               (~isnan(sdata.position{1}.east) && (sdata.position{1}.east ~= data.(sensorcode).position{1}.east)) ||...     
               (~isnan(sdata.position{1}.elev) && (sdata.position{1}.elev ~= data.(sensorcode).position{1}.elev)) ||...
               (~isnan(sdata.position{1}.thickness) && (sdata.position{1}.thickness ~= data.(sensorcode).position{1}.thickness)) ||...
               (~isnan(sdata.position{1}.nominal_north) && (sdata.position{1}.nominal_north ~= data.(sensorcode).position{1}.nominal_north)) ||...
               (~isnan(sdata.position{1}.nominal_east) && (sdata.position{1}.nominal_east ~= data.(sensorcode).position{1}.nominal_east))

                disp(['    !!Position changed']);
                disp(['      Old position: E ' num2str(data.(sensorcode).position{1}.east) ', N ' num2str(data.(sensorcode).position{1}.north) ', Elev. ' num2str(data.(sensorcode).position{1}.elev) ', Depth. ' num2str(data.(sensorcode).position{1}.thickness)]);
                disp(['      New position: E ' num2str(sdata.position{1}.east) ', N ' num2str(sdata.position{1}.north) ', Elev. ' num2str(sdata.position{1}.elev) ', Depth. ' num2str(sdata.position{1}.thickness)]);
                disp(['      Old nominal position: E ' num2str(data.(sensorcode).position{1}.nominal_east) ', N ' num2str(data.(sensorcode).position{1}.nominal_north)]);
                disp(['      New nominal position: E ' num2str(sdata.position{1}.nominal_east) ', N ' num2str(sdata.position{1}.nominal_north)]);
                fprintf(fid,'!!Position changed\n');
                fprintf(fid,['   Old position: E ' num2str(data.(sensorcode).position{1}.east) ', N ' num2str(data.(sensorcode).position{1}.north) ', Elev. ' num2str(data.(sensorcode).position{1}.elev) ', Depth. ' num2str(data.(sensorcode).position{1}.thickness) '\n']);
                fprintf(fid,['   New position: E ' num2str(sdata.position{1}.east) ', N ' num2str(sdata.position{1}.north) ', Elev. ' num2str(sdata.position{1}.elev) ', Depth. ' num2str(sdata.position{1}.thickness) '\n']);
                fprintf(fid,['   Old nominal position: E ' num2str(data.(sensorcode).position{1}.nominal_east) ', N ' num2str(data.(sensorcode).position{1}.nominal_north) '\n']);
                fprintf(fid,['   New nominal position: E ' num2str(sdata.position{1}.nominal_east) ', N ' num2str(sdata.position{1}.nominal_north) '\n']);
            end
        end        

        if isfield(data, sensorcode) && strcmp(importMode,'Keep')
            newRecords=length(sdata.time.serialtime)-length(data.(sensorcode).time.serialtime);
            if newRecords>0
                disp(['Appending ' num2str(newRecords) ' new records to ' sensorcode]);
                fprintf(fid,['Appending ' num2str(newRecords) ' new records to ' sensorcode '\n']);
                validOld=~isnan(data.(sensorcode).time.serialtime);
                %storing & padding masks
                if isfield(data.(sensorcode), 'deleted')
                    % Old versions of the data files stored the deleted mask as a double array with NaNs for deleted values
                    % New version store a logical array with true for deleted values
                    % So we do the conversion if necesary
                    if ~islogical(data.(sensorcode).deleted)
                        deletedMask=isnan(data.(sensorcode).deleted(validOld));
                    else
                        deletedMask=data.(sensorcode).deleted(validOld);
                    end
                    sdata.deleted=[deletedMask ; false(newRecords,1)];
                    fprintf(fid,'Deleted mask found, updated and copied\n');
                end
                if isfield(data.(sensorcode), 'shift')
                    shiftMask=single(data.(sensorcode).shift(validOld));
                    sdata.shift=[shiftMask ; zeros(newRecords,1,'single')];
                    fprintf(fid,'Shift mask found, updated and copied\n');
                end
            else
                disp(['No new data to append to ' sensorcode ', copying masks']);
                fprintf(fid,['No new data to append to ' sensorcode ', copying masks\n']);
                % Copying old masks to the new structure
                if isfield(data.(sensorcode), 'deleted')
                    % Old versions of the data files stored the deleted mask as a double array with NaNs for deleted values
                    % New version store a logical array with true for deleted values
                    % So we do the conversion if necesary
                    if ~islogical(data.(sensorcode).deleted)
                        sdata.deleted=isnan(data.(sensorcode).deleted);
                    else
                        sdata.deleted=data.(sensorcode).deleted;
                    end
                    fprintf(fid,'Deleted mask found and copied\n');
                end
                if isfield(data.(sensorcode), 'shift')
                    sdata.shift=single(data.(sensorcode).shift);
                    fprintf(fid,'Shift mask found and copied\n');
                end
            end
        end
        if ~isempty(sdata.time.serialtime)
            %Storing data 
            data = setfield(data, sensorcode, sdata);
            % Storing metadata
            east=sdata.position{1}.east;
            north=sdata.position{1}.north;
            if isnan(north) || isnan(east)
                east=sdata.position{1}.nominal_east;
                north=sdata.position{1}.nominal_north;
            end
            if isnan(north) || isnan(east)
                disp(['WARNING: No coordinates in metadata for ' sensorcode '. Nominal coordinates derived from grid position were used.']);

                holeYear=str2double(sdata.metadata.hole{1}{1}(1:2))+2000;
                [east, north]=grid2pos(sdata.grid{1},holeYear);
            end
            metadata.(sensorcode).tLims=[min(sdata.time.serialtime) max(sdata.time.serialtime)];
            metadata.(sensorcode).pLims=[min(sdata.pressure{1}) max(sdata.pressure{1})];
            metadata.(sensorcode).nonNaNtLims=[min(sdata.time.serialtime(~isnan(sdata.pressure{1}))) max(sdata.time.serialtime(~isnan(sdata.pressure{1})))];
            metadata.(sensorcode).pos=[east north];        
            metadata.(sensorcode).grid=sdata.grid{1};      
            metadata.(sensorcode).hole=sdata.metadata.hole{1}{1};
        else
            warning(['No data for sensor ' sensorcode(2:end) ', it was not stored on data structure.']);
        end
end

[newDataFile, newDataPath]=uiputfile('*.mat','Choose a name for the new data file','../Borehole data/');            
if newDataFile
    disp('Saving data...');
    [~, fileName, ext] = fileparts(newDataFile);
    save([newDataPath newDataFile],'-struct','data');
    save([newDataPath fileName '_metadata' ext],'-struct','metadata');
    disp('DONE');
end
end
function doy=DOY(datetime)
    [year,~,~]=datevec(datetime);
    doy=floor(datetime-datenum([year 1 1])+1);
end
function out = nanunique(A)
    %// Get unique rows with in-built "unique" that considers NaN as distinct
    unq1 = unique(A,'rows');

    %// Detect nans
    unq1_nans = isnan(unq1);

    %// Find nan equalities across rows
    unq1_nans_roweq = bsxfun(@plus,unq1_nans,permute(unq1_nans,[3 2 1]))==2;

    %// Find non-nan equalities across rows
    unq1_nonans_roweq = bsxfun(@eq,unq1,permute(unq1,[3 2 1]));

    %// Find "universal" (nan or non-nan) equalities across rows
    unq1_univ_roweq = unq1_nans_roweq | unq1_nonans_roweq;

    %// Remove non-unique rows except the first non-unique match as with 
    %// the default functionality of MATLAB's in-built unique function
    out = unq1(~any(triu(squeeze(sum(unq1_univ_roweq,2)==size(A,2)),1),1),:);
end
