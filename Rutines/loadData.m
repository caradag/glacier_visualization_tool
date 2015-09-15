function loadData()
    global data gps sMelt ambientTemp gridList metadata const

    data=struct;
    % ########## LOADING SENSOR PRESSURE DATA #######################
    % It is loaded on demand, so only the sensors on use are stored on the memory

    % ########## LOADING TEMPERATURE DATA #######################
    ambientTemp=struct('temp',[],'time',[]);
    [Y M D H MIN SEC temp]=textread([const.AccesoryDataFolder const.temperatureTimeserieFile],'%4d-%2d-%2d %2d:%2d:%2d %f','emptyvalue',NaN,'headerlines',1);
    ambientTemp.temp=temp;
    ambientTemp.time=datenum([Y M D H MIN SEC]);

    % ########## LOADING GPS DATA #######################
    load([const.AccesoryDataFolder const.gpsFile]);

    % ########## LOADING MELT DATA #######################
    sMelt=load([const.AccesoryDataFolder const.meltFile]);

    % #####################################################################
    % ###################### CREATING METADATA ############################
    % #####################################################################


    % ----------- SENSORS --------------------
    % Sensor metadata is just imported
    % If data file in config is not a valid one of is empty we request a file
    if isempty(const.sensorDataFile) && ~exist([const.DataFolder const.sensorDataFile],'file')
        [const.sensorDataFile const.DataFolder]=uigetfile([const.DataFolder '*.mat'],'Select data file');
    end
    
    if ischar(const.DataFolder) && ischar(const.sensorDataFile) && exist([const.DataFolder const.sensorDataFile],'file')
        % Metadata structure contain time range and position related
        % to every available data source
        metadata=struct;        
        [~, fileName, ext] = fileparts(const.sensorDataFile);
        metadataFileName=[const.DataFolder fileName '_metadata' ext];
        if exist(metadataFileName,'file')
            metadata.sensors=load(metadataFileName);
        else
            error(['Sensor data file ' const.DataFolder const.sensorDataFile ' does NOT have an associated metadata file.']);
        end
    else
        error('Invalid data file');
    end

    % Adding flags to sensors
    sensors = fieldnames(metadata.sensors);
    nFlags=length(const.sensorFlags);
    for s=1:length(sensors)
        for f=1:nFlags
            if exist([const.MasksFolder sensors{s} '_' const.sensorFlags{f} '.txt'],'file');
                metadata.sensors.(sensors{s}).flag=const.sensorFlags{f};
                break;
            end
        end
        if ~isfield(metadata.sensors.(sensors{s}),'flag')
            metadata.sensors.(sensors{s}).flag='good';
        end
    end
    % ----------- BOREHOLES --------------------
    metadata.boreholes=[];
    for s=1:length(sensors)
        hole=['H' metadata.sensors.(sensors{s}).hole];
        if isfield(metadata.boreholes,hole)
            metadata.boreholes.(hole).sensors{end+1}=sensors{s};
            metadata.boreholes.(hole).flags=metadata.boreholes.(hole).flags | strcmp(metadata.sensors.(sensors{s}).flag,const.sensorFlags);
            
            mint=min(metadata.boreholes.(hole).tLims(1), metadata.sensors.(sensors{s}).tLims(1));
            maxt=max(metadata.boreholes.(hole).tLims(2), metadata.sensors.(sensors{s}).tLims(2));
            metadata.boreholes.(hole).tLims=[mint maxt];
            
            mint=min(metadata.boreholes.(hole).nonNaNtLims(1), metadata.sensors.(sensors{s}).nonNaNtLims(1));
            maxt=max(metadata.boreholes.(hole).nonNaNtLims(2), metadata.sensors.(sensors{s}).nonNaNtLims(2));
            metadata.boreholes.(hole).nonNaNtLims=[mint maxt];
        else
            metadata.boreholes.(hole).pos=metadata.sensors.(sensors{s}).pos;
            metadata.boreholes.(hole).sensors=sensors(s);
            metadata.boreholes.(hole).tLims=metadata.sensors.(sensors{s}).tLims;
            metadata.boreholes.(hole).nonNaNtLims=metadata.sensors.(sensors{s}).nonNaNtLims;
            metadata.boreholes.(hole).grid=metadata.sensors.(sensors{s}).grid;
            metadata.boreholes.(hole).flags=strcmp(metadata.sensors.(sensors{s}).flag,const.sensorFlags);
        end
    end
    
    % ----------- GRIDS --------------------
    % making grid list and building related variables
    gridList=makeGridList(metadata.sensors); % makeGridList is a subfunction in this file
    list=fieldnames(gridList);
    for j=1:length(list)
        sensors=gridList.(list{j});
        tLim=[];
        nSensors=length(sensors);
        eastSum=0;
        northSum=0;
        posList=[];
        for k=1:nSensors
            sensor=['S' sensors{k}];
            metadata.sensors.(sensor).grid=list{j};
            tLim=updateLims(metadata.sensors.(sensor).tLims,tLim);
            % finding positions [east north elev depth]
            east=metadata.sensors.(sensor).pos(1);
            north=metadata.sensors.(sensor).pos(2);
            eastSum=eastSum+east;
            northSum=northSum+north;
            posList(end+1,1:2)=[east north];
        end
        posList=unique(posList,'rows');
        metadata.grids.(list{j}).tLims=tLim;
        metadata.grids.(list{j}).pos=[eastSum northSum]/nSensors;
        idx=[];
        if size(posList,1)>2
            idx= convhull(posList);
        elseif size(posList,1)==2
            idx=1:2;
        end
        metadata.grids.(list{j}).convexHull=posList(idx,:);
    end
    % ----------- GPS --------------------
    list = fieldnames(gps);
    for j=1:length(list)
        for k=1:length(const.gps.sources)
        metadata.gps.(list{j}).(const.gps.sources{k}).pos=[mean(gps.(list{j}).(const.gps.sources{k}).x) mean(gps.(list{j}).(const.gps.sources{k}).y)];
        metadata.gps.(list{j}).(const.gps.sources{k}).tLims=updateLims(gps.(list{j}).(const.gps.sources{k}).time(:));
        end
    end
    % ----------- meteo --------------------
    metadata.meteo.melt.tLims=updateLims(sMelt.time);
    metadata.meteo.melt.pos=[];
    metadata.meteo.temp.tLims=updateLims(ambientTemp.time);
    metadata.meteo.temp.pos=[];
end

function lims=updateLims(time,tLim)
% Function to update limits given previous limits and a new data set
    if nargin==1
        tLim=[];
    end
    lims=[min([time(:); tLim(:)]) max([time(:); tLim(:)])];
end


function gridList=makeGridList(data)
% function to create a list of grid positions with cell arrays containing
% the IDs of all the sensors on that position
    gridList=struct;
    sensorsInData = fieldnames(data);
    for i=1:length(sensorsInData)
        sensor=sensorsInData{i};  
        grid=data.(sensor).grid;

        if any(strcmp(grid(end),{'b','c','d','e','f','g'}))
            grid=grid(1:end-1);
        end
        % as field names can't include periods, wq replace them by _
        
        grid=strtrim(strrep(grid,'.', '_'));

        if ~isfield(gridList,grid)
            gridList.(grid)={};
        end   
        gridList.(grid)=[gridList.(grid), sensor(2:end)];
    end
end