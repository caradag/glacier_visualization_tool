function getFullInfo(source,eventdata,panel,d)
    global data gridList const panels
    type=panels(panel).data(d).type;
    ID=panels(panel).data(d).ID;
    switch type
        case 'sensors'
            Msg={};
            Msg{end+1}=sprintf('Sensor ID: %s',ID(2:end));
            Msg{end+1}=sprintf('Grid ID: %s',data.(ID).grid{1});
            Msg{end+1}=sprintf('Sensors in grid location: %s',strjoin(gridList.(getGridID(data.(ID).grid{1})),', '));            
            holeID=data.(ID).metadata.hole{1}{1};
            Msg{end+1}=sprintf('Hole ID: %s',holeID);
            Msg{end+1}=sprintf('Position: %.3f %.3f %.3f m (GPR derived thickness %.1f m)',data.(ID).position{1}.north, data.(ID).position{1}.east,data.(ID).position{1}.elev,getGPRdepth(data.(ID).position{1}.east,data.(ID).position{1}.north));
            Msg{end+1}=sprintf('Nominal position: %.3f %.3f (GPR derived thickness %.1f m)',data.(ID).position{1}.nominal_north, data.(ID).position{1}.nominal_east,getGPRdepth(data.(ID).position{1}.nominal_east,data.(ID).position{1}.nominal_north));
            Msg{end+1}=sprintf('Sensor depth: %.1f m',data.(ID).position{1}.thickness);
            Msg{end+1}=sprintf('Minimum battery voltage: %.1f v',min(data.(ID).battvolt{1}));
            Msg{end+1}=sprintf('Start date: %s',datestr(min(data.(ID).time.serialtime)));
            Msg{end+1}=sprintf('End date: %s',datestr(max(data.(ID).time.serialtime)));
            Msg{end+1}=sprintf('Epoch count: %d\n',length(data.(ID).time.serialtime));
            nanCount=sum(isnan(data.(ID).pressure{1}));
            Msg{end+1}=sprintf('Number of NaN samples: %d',nanCount);
            if nanCount>0
                fisrtNan=find(isnan(data.(ID).pressure{1}),1,'first');
                Msg{end+1}=sprintf('First NaN sample at: %d (%s)',fisrtNan,datestr(data.(ID).time.serialtime(fisrtNan)));
            end
            Msg{end+1}=sprintf('\n');
            
            nInstallations=size(data.(ID).metadata.installationTime{1},1);
            for ins=1:nInstallations
                insDoyVec=data.(ID).metadata.installationTime{1}(ins,:);
                instTime=datenum([insDoyVec(1) 1 1 fix(insDoyVec(3)/100) mod(insDoyVec(3),100) 0])+insDoyVec(2)-1;
                uninstDoyVec=data.(ID).metadata.uninstallationTime{1}(ins,:)
                uninstTime=datenum([uninstDoyVec(1) 1 1 fix(uninstDoyVec(3)/100) mod(uninstDoyVec(3),100) 0])+uninstDoyVec(2)-1;
                Msg{end+1}=sprintf('Installation on: %s (DOY %d) to %s (DOY %d)',datestr(instTime),insDoyVec(2),datestr(uninstTime),uninstDoyVec(2));
            end
            
            dt=diff(data.(ID).time.serialtime);

            Msg{end+1}=sprintf('\nMean epoch: %.2f minutes',abs(nanmean(dt))*24*60);
            Msg{end+1}=sprintf('Median epoch: %.2f minutes',abs(nanmedian(dt))*24*60);
            Msg{end+1}=sprintf('Min epoch: %.4f minutes',min(dt)*24*60);
            Msg{end+1}=sprintf('Max epoch: %.2f minutes',max(dt)*24*60);
            if all(dt>0)
                Msg{end+1}=sprintf('Time monotonicity check: Ok');
            else
                Msg{end+1}=sprintf('Time monotonicity check: Fail');
            end

            Msg{end+1}=sprintf('Min pressure: %.1f Pa (%.1f psi)',min(data.(ID).pressure{1}),min(data.(ID).pressure{1})*const.psiPerPascal);
            Msg{end+1}=sprintf('Max pressure: %.1f Pa (%.1f psi)',max(data.(ID).pressure{1}),max(data.(ID).pressure{1})*const.psiPerPascal);

            Msg{end+1}=sprintf('Reading at atmospheric pressure CR10X: %.2f psi (11.024 psi = factory default)',data.(ID).metadata.atmosphericReadingCR10X{1}*20);
            Msg{end+1}=sprintf('Reading at atmospheric pressure CR1000: %.2f psi (11.024 psi = factory default)',data.(ID).metadata.atmosphericReadingCR1000{1}*20);
            Msg{end+1}=sprintf('Ice pessure: %.2f Pa (%.1f psi)',data.(ID).icepress{1},data.(ID).icepress{1}*const.psiPerPascal);

            Msg{end+1}=sprintf('\n------CURRENT CURSOR INFO-----');
            [fileName loggerChannel lineNumber line lineTime value]=openRawData([],[],panel,d,'getLine');
            Msg{end+1}=['File: ' fileName ' at line ' num2str(lineNumber) ' channel #' num2str(loggerChannel)];
            Msg{end+1}=sprintf('Current cursor line:');
            Msg{end+1}=line;
            Msg{end+1}=['Line date and time: ' datestr(lineTime)];
            Msg{end+1}=['Value on channel # ' num2str(loggerChannel) ': ' value];
            disp(['<a href="matlab:matlab.desktop.editor.openAndGoToLine(''' const.rawDataFolder fileName ''',' num2str(lineNumber) ')">Open raw file in line ' num2str(lineNumber) ' (look for CH#' num2str(loggerChannel) ')</a>']);
            
            nFlags=length(const.sensorFlags);
            for f=1:nFlags
                flagFileName=[const.MasksFolder ID '_' const.sensorFlags{f} '.txt'];
                if exist(flagFileName,'file');
                    Msg{end+1}=sprintf('\n------%s FLAG-----',upper(const.sensorFlags{f}));
                    % If the flag file exist we dump its content to Msg
                    fid=fopen(flagFileName,'r');
                    tline = fgetl(fid);
                    while ischar(tline)
                        Msg{end+1}=sprintf('%s',tline);
                        tline = fgetl(fid);
                    end
                    fclose(fid);                    
                end
            end
    
            
            Msg{end+1}=sprintf('\n------RAW DATA FILES-----');
            nFiles=length(data.(ID).metadata.files.names{1});
            disp(['List of data files for ' ID ', click to open in editor.']);
            for i=1:nFiles
                rawFileName=data.(ID).metadata.files.names{1}{i};
                [~, rawLineCount]=system(['sed -n ''$='' "' const.rawDataFolder rawFileName '"']);
                logger=data.(ID).metadata.files.logger{1}{i,2};
                channel=data.(ID).metadata.files.logger{1}{i,3};
                Msg{end+1}=sprintf('%s CH#%d %s (%s lines)',logger,channel,rawFileName,strtrim(rawLineCount));
                disp(['<a href="matlab:edit(''' const.rawDataFolder rawFileName ''')">' rawFileName '(CH#' num2str(channel) ', ' strtrim(rawLineCount) ' lines)</a>']);
            end
            
            Msg{end+1}=sprintf('\n------LOG AT glachole.mod-----');

            glachole=fopen([const.AccesoryDataFolder const.glacholeFile],'r');
            tline = fgetl(glachole);
            while ischar(tline)
                if length(tline)>=5 && strcmp(tline(1:5),holeID)
                    Msg{end+1}=sprintf('%s',tline);
                end
                tline = fgetl(glachole);
            end
            fclose(glachole);
            
            Msg{end+1}=sprintf('\n------ Sensor tbl file -----');
            [year, ~, ~]=datevec(data.(ID).time.serialtime(1));
            tblFile=[const.rawDataFolder filesep num2str(year) filesep 'summer' filesep 'sensors' filesep 'tables' filesep 'P' filesep ID(2:end) '.tbl'];
            if exist(tblFile,'file')
                tbl=fopen(tblFile,'r');
                tline = fgetl(glachole);
                while ischar(tline)
                    Msg{end+1}=sprintf('%s',tline);
                    tline = fgetl(tbl);
                end
                fclose(tbl);
            else
                Msg{end+1}=['tbl file not found at ' filesep num2str(year) filesep 'summer' filesep 'sensors' filesep 'tables' filesep 'P' filesep];
            end
            
            fid=fopen('tmp.txt','w');
            for l=1:length(Msg)
                fprintf(fid,[Msg{l} '\r\n']);
            end
            fclose(fid);
            edit('tmp.txt')
    end
end

function gridID=getGridID(grid)
    if any(strcmp(grid(end),{'b','c','d','e','f','g'}))
        grid=grid(1:end-1);
    end

    grid=strrep(grid,'.', '_');

    gridID=grid;
end
