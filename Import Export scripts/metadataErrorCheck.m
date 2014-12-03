function metadataErrorCheck()
    clc

    config;
    filename_info = [AccesoryDataFolder sensorReferenceTableFile];

    [logger_ID,logger_type,channel,sensor_ID,sensor_make,snubber,hole_ID,...%Sensor's ID info
     thickness,sensor_grid,sensor_north,sensor_east,sensor_elev,nominal_north,nominal_east,...%Sensor's position info
     install_year,install_day,install_time,uninstall_year,uninstall_day,uninstall_time,...%Sensor's installation info 
     atpress,atpress_CR1K,multiplier,icepress]...%Sensor's data calibration info
        = textread(filename_info,'%s %s %f %s %s %s %s %f %s %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f','delimiter',',','emptyvalue',NaN,'headerlines',1);

    %%Clean up missing install times
    install_time(isnan(install_time)) = 0;
    installDateTime=install_year*1e7+install_day*1e4+install_time;

    %%Clean up missing uninstall times
    uninstall_time(isnan(uninstall_time)) = 2400;
    uninstallDateTime=uninstall_year*1e7+uninstall_day*1e4+uninstall_time;
    uninstallDateTime(isnan(uninstallDateTime))=Inf;

    % atpress(isnan(atpress)) = 0.5512;
    % atpress_CR1K(isnan(atpress_CR1K)) = atpress(isnan(atpress_CR1K));
    % multiplier(isnan(multiplier)) = 6894.75729*20; 

    nEntries=length(sensor_ID);

    sensorList=unique(sensor_ID);
    if isempty(sensorList{1})
        sensorList=sensorList(2:end);
    end
    nSensors=length(sensorList);
    disp([num2str(nSensors) ' sensors in dataset'])
    loggerList=unique(logger_ID);
    if isempty(loggerList{1})
        loggerList=loggerList(2:end);
    end
    nLoggers=length(loggerList);

    holesList=unique(hole_ID);
    if isempty(holesList{1})
        holesList=holesList(2:end);
    end
    nHoles=length(holesList);
    disp([num2str(nHoles) ' holes in dataset'])

    % Checking all uninstallation times are greater than installation times
    inconsistentTimes=uninstallDateTime<=installDateTime;
    if any(inconsistentTimes)
        disp(['ERROR: Uninstallation time is earlier than installation time in metadata lines ' sprintf('%d,',find(inconsistentTimes)+1)]);
    end
    % Checking loggers have the right ammount of channels
    %CR1000
    cr1000s=strcmp(logger_type,'CR1000');
    if max(channel(cr1000s))>8
        disp(['ERROR: Invalid channel (greater than 8) in metadata lines ' sprintf('%d,',find(channel>8 & cr1000s)+1)]);
    end
    %CR10 and CR10X
    cr10s=strcmp(logger_type,'CR10') | strcmp(logger_type,'CR10X');
    if max(channel(cr10s))>6
        disp(['ERROR: Invalid channel (greater than 6) in metadata lines ' sprintf('%d,',find(channel>6 & cr10s)+1)]);
    end
    if any(channel<1)
        disp(['ERROR: Invalid channel (smaller than 1) in metadata lines ' sprintf('%d,',find(channel<1)+1)]);
    end

    emptyChannels=strcmp(sensor_ID,'');
    for i=1:nLoggers
        % Finding entries for current sensor
        cases=strcmp(loggerList{i},logger_ID)& ~emptyChannels;
        nCases=sum(cases);
        %Checking that there isn't overlaping entries for the same channel
        for chan=1:8
            chEntries=find(cases & channel==chan);
            [installations, order]=sort(installDateTime(chEntries));
            uninstallations=uninstallDateTime(chEntries);
            uninstallations=uninstallations(order);
            for j=2:length(installations)
                if installations(j)<uninstallations(j-1)
                    conflictingLines=[find(cases & channel==chan & installDateTime==installations(j)); find(cases & channel==chan & uninstallDateTime==uninstallations(j-1))]+1;
                    disp(['ERROR: Channel ' num2str(chan) ' on ' loggerList{i} ' have more than one sensor connected at the same time. Metadata lines ' sprintf('%d,',conflictingLines(1)) ' and ' sprintf('%d,',conflictingLines(2))])
                end
            end
        end
    end
    for i=1:nSensors
        if length(sensorList{i})~=5 || sensorList{i}(3)~='P'
            disp(['ERROR: Anomalous sensor name for ' sensorList{i}])
        end
        % Finding entries for current sensor
        cases=find(strcmp(sensorList{i},sensor_ID));
        nCases=length(cases);
        if nCases>1
            %checking all cases of the sensor have info
            if length(unique(sensor_make(cases)))>1
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different sensor maker. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end
            if length(unique(snubber(cases)))>1
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different snnuber flag. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end
            if length(unique(hole_ID(cases)))>1
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different hole ID. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end
            if length(unique(thickness(cases)))>1 && ~all(isnan(thickness(cases)))
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different thickness. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end
            if ~all(isnan(thickness(cases)))
                disp(['WARNING: No thickness for ' sensorList{i} ' at hole ' hole_ID{cases(1)}])
            end
            if length(unique(sensor_grid(cases)))>1
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different grid. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end
            if length(unique(sensor_north(cases)))>1 && ~all(isnan(sensor_north(cases)))
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different northing. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end
            if length(unique(sensor_east(cases)))>1 && ~all(isnan(sensor_east(cases)))
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different easting. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end
            if length(unique(sensor_elev(cases)))>1 && ~all(isnan(sensor_elev(cases)))
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different elevation. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end
            if length(unique(nominal_north(cases)))>1 && ~all(isnan(nominal_north(cases)))
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different nominal northing. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end
            if length(unique(nominal_east(cases)))>1 && ~all(isnan(nominal_east(cases)))
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different nominal easting. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end
            if length(unique(atpress(cases)))>1 && ~all(isnan(atpress(cases)))
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different atmospheric pressure reading for CR10X. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end
            if length(unique(atpress_CR1K(cases)))>1 && ~all(isnan(atpress_CR1K(cases)))
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different atmospheric pressure reading for CR1000. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end
            if length(unique(multiplier(cases)))>1 && ~all(isnan(multiplier(cases)))
                disp(['ERROR: Different entries for sensor ' sensorList{i} ' have different atmospheric pressure multiplier. Metadata lines for this sensor are ' sprintf('%d,',cases) 8])
            end

            %Checking instalation times doesn overlap
            [installations, order]=sort(installDateTime(cases));
            uninstallations=uninstallDateTime(cases(order));
            for j=2:nCases
                if installations(j)<uninstallations(j-1)
                    conflictingLines=[find(strcmp(sensorList{i},sensor_ID) & installDateTime==installations(j)); find(strcmp(sensorList{i},sensor_ID) & uninstallDateTime==uninstallations(j-1))]+1;
                    disp(['ERROR: One installation of ' sensorList{i} ' start before previous uninstallation. Metadata lines ' sprintf('%d,',conflictingLines(1)) ' and ' sprintf('%d,',conflictingLines(2))])
                end
            end
        end

        % Checking if neither real or nominal coordinates exist for a sensor
        bothNaNs=isnan(sensor_north) & isnan(nominal_north) & strcmp(sensorList{i},sensor_ID);
        if any(bothNaNs)
            disp(['ERROR: NaN northing and nominal northing for sensor ' sensorList{i} ' at metadata line ' sprintf('%d,',find(bothNaNs))])
        end
        bothNaNs=isnan(sensor_east) & isnan(nominal_east) & strcmp(sensorList{i},sensor_ID);
        if any(bothNaNs)
            disp(['ERROR: NaN easting and nominal easting for sensor ' sensorList{i} ' at metadata line ' sprintf('%d,',find(bothNaNs))])
        end

        
        for c=cases'            
            if ~isnan(sensor_east(c)) && ~isnan(nominal_east(c))
                %if it has both nominal and measured coordinates we check the distance between both
                pos=[sensor_east(c) sensor_north(c)];
                nominalPos=[nominal_east(c) nominal_north(c)];
                dist=norm(pos-nominalPos);
                if dist > 20
                    year=str2double(hole_ID{c}(1:2))+2000;
                    if year>=2011
                        disp(['WARNING: Measured and nominal coordinates for ' sensorList{i} ' in ' hole_ID{cases(1)} ' ('  sensor_grid{cases(1)} ') are ' sprintf('%.0f',dist) ' meters away (line ' num2str(c+1) ')'])
                    end
                elseif dist > 60
                    disp(['ERROR: Measured and nominal coordinates for ' sensorList{i} ' in ' hole_ID{cases(1)} ' ('  sensor_grid{cases(1)} ') are ' sprintf('%.0f',dist) ' meters away (line ' num2str(c+1) ')'])
                end
            end
            
            validGrid = regexp(sensor_grid{c},'(R[0-9\.]{2}[\.]{0,1}[0-9\.]{0,3}C[0-9\.]{2}[\.]{0,1}[0-9\.]{0,3}.?)','once');
            if isempty(validGrid)
                disp(['ERROR: Invalid grid identifier "' sensor_grid{c} '"for ' sensorList{i} ' at metadata line ' num2str(c+1)])
                continue;
            end

            if ~isnan(sensor_east(c))
                %if it has measured coordinates we check the distance between it and the one computed from grid position
                pos=[sensor_east(c) sensor_north(c)];
                year=str2double(hole_ID{c}(1:2))+2000;
                gridPos=grid2pos(sensor_grid{c},year);
                dist=norm(gridPos-pos);
                if dist > 15
                    if year>=2011
                        disp(['WARNING: Measured coordinates and grid position for ' sensorList{i} ' in ' hole_ID{cases(1)} ' ('  sensor_grid{cases(1)} ') are off by ' sprintf('%.0f',dist) ' meters (line ' num2str(c+1) ')'])
                        [grid dist]=pos2grid(pos,year,0.25);
                        disp(['       Expected grid: ' grid ' (that would be ' sprintf('%.0f',dist) ' m off)'])
                    end
                elseif dist > 30
                    disp(['ERROR: Measured coordinates and grid position for ' sensorList{i} ' in ' hole_ID{cases(1)} ' ('  sensor_grid{cases(1)} ') are off by ' sprintf('%.0f',dist) ' meters (line ' num2str(c+1) ')'])
                    [grid dist]=pos2grid(pos,year,0.25);
                    disp(['       Expected grid: ' grid ' (that would be ' sprintf('%.0f',dist) ' m off)'])
                end
            end

            if ~isnan(nominal_east(c))
                %if it has nominal coordinates we check the distance between it and the one computed from grid position
                nominalPos=[nominal_east(c) nominal_north(c)];
                year=str2double(hole_ID{c}(1:2))+2000;
                gridPos=grid2pos(sensor_grid{c},year);
                dist=norm(gridPos-nominalPos);
                if dist > 5
                    if isnan(sensor_east(c))
                        if year>=2009
                            disp(['ERROR: Nominal coords. and grid position for ' sensorList{i} ' in ' hole_ID{cases(1)} ' ('  sensor_grid{cases(1)} ') off by ' sprintf('%.0f',dist) ' m (line ' num2str(c+1) ')']);
                            disp(['       Expected coords.: ' sprintf('%.3f\t%.3f',gridPos(2),gridPos(1))]);
                            [expectedGrid eGdist]=pos2grid(pos,year,0.25);
                            disp(['       Or expected grid: ' expectedGrid ' (' sprintf('%.0f',eGdist) ' m from nominal position)']);
                        end
                    else
                        if year>=2011
                            disp(['WARNING: Nominal coords. and grid position for ' sensorList{i} ' in ' hole_ID{cases(1)} ' ('  sensor_grid{cases(1)} ') off by ' sprintf('%.0f',dist) ' m. Expected coords.: ' sprintf('%.3f\t%.3f',gridPos(2),gridPos(1)) ' (line ' num2str(c+1) ')']);
                            disp(['       Expected coords.: ' sprintf('%.3f\t%.3f',gridPos(2),gridPos(1))]);
                            [expectedGrid eGdist]=pos2grid(pos,year,0.25);
                            disp(['       Or expected grid: ' expectedGrid ' (' sprintf('%.0f',eGdist) ' m from nominal position)']);
                        end
                    end
                end
            end
        end
        
        % Cheking if no hole was specified for the sensor
        if any(strcmp(hole_ID(cases),''))
            disp(['ERROR: No hole entered for ' sensorList{i} ' at metadata line ' sprintf('%d,',find(strcmp(sensorList{i},sensor_ID) & strcmp(hole_ID(cases),'')))])
        end

        % Checking sensor was installed after it was made
        installations=installDateTime(cases);
        sensorYear=NaN;
        sensorMakeTime=-Inf;
        if ~strcmp(sensorList{i}(1:2),'XX')
            sensorYear=2000+str2double(sensorList{i}(1:2));
            sensorMakeTime=datenum([sensorYear 4 1]);
        end
        if any(installations<sensorMakeTime)
            disp(['ERROR: Sensor ' sensorList{i} ' is shown as installed before it was made. First installed on ' datestr(min(installations))]);
        end

    end

    % Checking sensor was installed in a hole made before the sensor year
    tmp=sensor_ID;
    tmp(strcmp(tmp,''))={'00P00'};
    sensorYear=cat(1,tmp{:});
    sensorYear=sensorYear(:,1:2);
    sensorYear(sensorYear=='X')='0';
    sensorYear=2000+str2num(sensorYear);
    tmp=hole_ID;
    tmp(strcmp(tmp,''))={'00H00'};
    holeYear=cat(1,tmp{:});
    holeYear=holeYear(:,1:2);
    holeYear=2000+str2num(holeYear);

    earlierHole=find(sensorYear>holeYear);
    for i=1:length(earlierHole)
        disp(['ERROR: Sensor ' sensor_ID{earlierHole(i)} ' installed on hole of previous year: ' hole_ID{earlierHole(i)}]);
    end

    % Checking there is no missing holes
    for year=6:14
        maxID=0;
        for i=1:nHoles
            if length(holesList{i})~=5 || holesList{i}(3)~='H'
                disp(['ERROR: Anomalous hole name for ' holesList{i}])
            end

            if strcmp(holesList{i}(1:2),sprintf('%02d',year));
                holeID=str2double(holesList{i}(4:5));
                maxID=max(maxID,holeID);
            end
        end
        noInformation=true(maxID,1);
        for i=1:nHoles
            if strcmp(holesList{i}(1:2),sprintf('%02d',year));
                holeID=str2double(holesList{i}(4:5));
                noInformation(holeID)=false;
            end
        end
        if sum(noInformation)>0
            disp(['WARNING: No information for hole(s) ' sprintf('%02d,',find(noInformation)) 8 ' on year ' num2str(year+2000) ' (year''s holes count: ' num2str(maxID) ')']);
        end
    end
end
    