function populatePanels(forceRePopulation)
%populatePanels Add time series data to panels structure
%   populatePanels browse trough the panels structure and add actual time
%   series data to the structure

    global data gps sMelt ambientTemp panels metadata const displayStatus

    if nargin<1
        forceRePopulation=0;
    end
    npanels=length(panels);
    toRemove=[];
    
    %######## COMPILING DATA STATISTICS: POSITIONS AND TIME SPANS #########
    for p=1:npanels
        axisLims=struct('time_days',[NaN NaN],'press_kPa',[],'press_mWaterEq',[],'press_PSI',[],'volt_V',[],'temp_C',[],'speed_cmPerDay',[],'deviation_mm',[],'melt_mmPerDay',[]);
        axisLimsClean=struct('time_days',[NaN NaN],'press_kPa',[],'press_mWaterEq',[],'press_PSI',[],'volt_V',[],'temp_C',[],'speed_cmPerDay',[],'deviation_mm',[],'melt_mmPerDay',[]);

        axisLims.time_days=[NaN NaN];
        panelPosSum=[0 0];
        posCount=0;
        nDataFields=length(panels(p).data);
        if nDataFields==0
            disp(['Empty panel removed']);
            toRemove(end+1,1:2)=[p d];
            continue
        end
        nFlags=length(const.sensorFlags);
        for d=1:nDataFields
            type=panels(p).data(d).type;            
            ID=panels(p).data(d).ID;
            tLims=metadata.(type).(ID).tLims;
            pos=metadata.(type).(ID).pos;
            switch type
                case 'sensors'  
                    % If the sensor flag is not selected to be displayed we remove it
                    if ~any(strcmp(metadata.sensors.(ID).flag,const.sensorFlags) & displayStatus.sensorFlags)
                        toRemove(end+1,1:2)=[p d];
                        continue;
                    end
                case 'gps'
                    source=panels(p).data(d).source;            
                    if isempty(tLims)
                        disp(['No data for ' ID ' ' source '. It wont be displayed.']);
                        toRemove(end+1,1:2)=[p d];
                        continue;
                    end
                otherwise
                    continue;
            end
            axisLims=updateLims(axisLims,tLims);
            if ~isempty(pos)
                panelPosSum=panelPosSum+pos;
                posCount=posCount+1;
            end
        end
        panels(p).axisLims=axisLims;
        panels(p).axisLimsClean=axisLimsClean;
        panels(p).meanPos=panelPosSum/posCount;        
    end

    for i=1:size(toRemove,1)
        swapPanels([],[],toRemove(i,1:2),[]);
    end
    npanels=length(panels);
    inUseSensors={};
    for p=1:npanels
        nDataFields=length(panels(p).data);
        sendToBack=[];%list of data series (data index within the panel) to send to the back of the panel
        for d=1:nDataFields
            ID=panels(p).data(d).ID; 
            inUseSensors{end+1}=ID;
            %skip process if entry has been already populated
            if isfield(panels(p).data(d),'yData') && ~isempty(panels(p).data(d).yData) && ~forceRePopulation
                continue;
            end
            
            ID=panels(p).data(d).ID;
            var=panels(p).data(d).variable;
            source=panels(p).data(d).source;
            sections=[];
            cleanTimeLims=[];
            lines=[];
            pos=[];
            yDescription='';
            
            % Y limits normalization info
            if ~isfield(panels(p).data(d),'normMode') || isempty(panels(p).data(d).normMode)
                panels(p).data(d).normMode={'range'};
            end
            % filter info
            if ~isfield(panels(p).data(d),'filter') || isempty(panels(p).data(d).filter)
                panels(p).data(d).filter='none';
            end
            if ~isfield(panels(p).data(d),'selected') || isempty(panels(p).data(d).selected)
                panels(p).data(d).selected=false;
            end
            if ~isfield(panels(p).data(d),'style') || isempty(panels(p).data(d).style)
                panels(p).data(d).style='-   none';
            end            
            
            switch panels(p).data(d).type
                case 'sensors'
                    % loading data if needed
                    if ~isfield(data,ID)
                        tmp=load([const.DataFolder const.sensorDataFile],ID);
                        data.(ID)=tmp.(ID);
                        clear tmp
                    end
                    switch var
                        case 'pressure'
                            %getting data
                            time=data.(ID).time.serialtime(:);
                            nSamples=length(time);
                            yData=data.(ID).pressure{1}(:);
                            yDescription=['Pressure at sensor ' ID ' at position ' data.(ID).grid{1}];
                            %apply shifts if any
                            if isfield(data.(ID),'shift')
                                shift=data.(ID).shift(:);
                                shift(isnan(shift))=0;
                                yData=yData+shift;
                                %compute sections limits (areas with different shifts)
                                sectionIndx=logical([1; diff(shift)~=0]);
                                sections.time=time(sectionIndx);
                                sections.y=[];
                            end

                            % Retrieveing masks information
                            nMasks=length(const.dataMasks);
                            masksOverlay=false(nSamples,1);
                            for m=1:nMasks
                                if exist([const.MasksFolder ID '_' const.dataMasks{m} '.mat'],'file')
                                    mask=load([const.MasksFolder ID '_' const.dataMasks{m} '.mat']);
                                    maskField=fieldnames(mask);
                                    mask=mask.(maskField{1});
                                elseif isfield(data.(ID),const.dataMasks{m})
                                    mask=data.(ID).(const.dataMasks{m});
                                else
                                    % Inicializing masks to default values
                                    switch const.dataMasks{m}
                                        case 'deleted'
                                            mask=isnan(yData);
                                        case 'offset'
                                            mask=zeros(nSamples,1);
                                        otherwise
                                            mask=false(nSamples,1);
                                    end
                                end
                                if ~displayStatus.dataMasks(m) && const.dataMaskIsLogical(m)
                                    masksOverlay(mask)=true;
                                end
                                if displayStatus.dataMasks(m) && strcmp(const.dataMasks{m},'offset')
                                    yData=yData+mask;
                                end
                                panels(p).data(d).(const.dataMasks{m})=mask;
                            end                            
                            cleanTimeLims=[min(time(~masksOverlay)) max(time(~masksOverlay))];
                            
                            nonNanSamples=~isnan(yData);
                            breakes=data.(ID).metadata.files.limits{1};

                            bigGaps=find(abs(diff(time))>(21/1440));
                            for g=1:length(bigGaps)
                                breakes=[breakes; [bigGaps(g)+1 bigGaps(g)]];
                            end                            
                            [nonNanIntervals] = getIntervals(nonNanSamples);
                            inis=false(nSamples,1);
                            inis(breakes(:,1))=true;
                            inis=unique([find(inis & nonNanSamples); [nonNanIntervals.ini]']);
                            ends=false(nSamples,1);
                            ends(breakes(:,2))=true;
                            ends=unique([find(ends & nonNanSamples); [nonNanIntervals.end]']);
                            breakes=[inis ends];

                            % finding positions [east north elev depth]
                            pos.east=metadata.sensors.(ID).pos(1);
                            pos.north=metadata.sensors.(ID).pos(2);
                            pos.elev=data.(ID).position{1}.elev;
                            pos.thickness=data.(ID).position{1}.thickness;
                            extraDesc='';
                            if isnan(pos.thickness)
                                pos.thickness=getGPRdepth(pos.east,pos.north);
                                extraDesc=['WARNING: Depth estimated from GPR data (' num2str(pos.thickness) ' m)'];
                            end
                            
                            %normalizing data and getting transformation functions
                            % DATA IS TRANSFORMED from Pa to kPa
                            [norm2y y2norm yData time]=normalize(yData/1000, time, panels(p).data(d).normMode,masksOverlay,pos.thickness);
                            
                            %finding normalized pressures corresponding a sections limits
                            if ~isempty(sections)
                                for i=1:length(sections.time)
                                    idx=find(time>sections.time(i),1,'first');
                                    sections.y(end+1)=yData(idx);
                                end
                            end
                           
                            
                            %defining reference lines
                            lines(end+1).value=y2norm(pos.thickness*const.iceDensity*const.g/1000);
                            lines(end).description=sprintf('Oberburden presure for %.1f m ice thickness %s', data.(ID).position{1}.thickness,extraDesc);
                            lines(end).color=[255 150 0]/255;
                            lines(end).style='-.';
                            lines(end).thickness=2;

                            lines(end+1).value=y2norm(pos.thickness*const.g);
                            lines(end).description=sprintf('Water filled borehole presure for %.1f m ice thickness %s', data.(ID).position{1}.thickness,extraDesc);
                            lines(end).color=[150 150 0]/255;
                            lines(end).style='-.';
                            lines(end).thickness=2;                            

                            lines(end+1).value=y2norm(0);
                            lines(end).description='Pessure Zero line';
                            lines(end).color=[.5 .5 .5];
                            lines(end).style=':';
                            lines(end).thickness=1;
                            
                            lines(end+1).value=y2norm(const.sensorPressureLimit/1000);
                            lines(end).description='200 psi line, standard sensor range';
                            lines(end).color=[1 0 0];
                            lines(end).style=':';
                            lines(end).thickness=2;

                            lines(end+1).value=y2norm(const.sensorPressureTolerance/1000);
                            lines(end).description='400 psi line, standard sensor tolerance';
                            lines(end).color=[1 0 0];
                            lines(end).style=':';
                            lines(end).thickness=4;

                            axisID='press_kPa';
                            color=[0 0 1];
                        case 'battvolt'
                            %getting data
                            time=data.(ID).time.serialtime(:);
                            nSamples=length(time);
                            breakes=[1 nSamples];
                            [norm2y y2norm yData]=normalize(data.(ID).battvolt{1}(:), time, panels(p).data(d).normMode);
                            yDescription=['Battery voltage for sensor ' ID ' at logger ' strjoin(data.(ID).logger{1},', ')];

                            %defining reference lines
                            lines(end+1).value=y2norm(13);
                            lines(end).description='13 volts -> Fully logger charged battery';
                            lines(end).color=[0 .5 0];
                            lines(end).style=':';
                            lines(end).thickness=1;

                            lines(end+1).value=y2norm(10.5);
                            lines(end).description='10.5 volts -> Logger operational limit';
                            lines(end).color=[.5 0 0];
                            lines(end).style=':';
                            lines(end).thickness=1;

                            axisID='volt_V';
                            color=[0.76 0.87 0.78];
                        case 'temperature'
                            %getting data
                            time=data.(ID).time.serialtime(:);
                            nSamples=length(time);
                            breakes=[1 nSamples];
                            [norm2y y2norm yData]=normalize(data.(ID).temperature{1}(:), time, panels(p).data(d).normMode);
                            yDescription=['Logger temperature for sensor ' ID ' at logger ' strjoin(data.(ID).logger{1},', ')];

                            %defining reference lines
                            lines(end+1).value=y2norm(0);
                            lines(end).description='0°C freezing line';
                            lines(end).color=[1 0.75 0.27];
                            lines(end).style='-';
                            lines(end).thickness=2;

                            axisID='temp_C';
                            color=[1 1 0.4];
                    end
                case 'gps'
                    %stablish units transformation
                    switch panels(p).data(d).variable
                        %getting corresponding time data and defining lines when needed
                        case {'speed','projSpeed'}
                            time=gps.(ID).(source).speedTime(:);                            
                            axisID='speed_cmPerDay';
                            unitsFac=100; % scale transformations for units in cm per day
                        case {'longitudinalDeviation','transversalDeviation','verticalDeviation'}
                            time=gps.(ID).(source).time(:);
                            axisID='deviation_mm';
                            unitsFac=1000; % scale transformations for units in mm
                    end
                    nSamples=length(time);
                    breakes=[1 nSamples];
                    % setting color
                    switch panels(p).data(d).variable
                        case {'speed','projSpeed'}
                            color=[0.4 0 0.4];
                        case 'longitudinalDeviation'
                            color=[0.87 0.49 0];
                        case 'transversalDeviation'
                            color=[1 0 1];
                        case 'verticalDeviation'
                            color=[0 0.75 0.75];
                    end                    
                    %getting , normalizing and getting transformation functions for data
                    [norm2y y2norm yData]=normalize(gps.(ID).(source).(var)(:)*unitsFac, time, panels(p).data(d).normMode);
                    yDescription=[var ' from ' source 'solutions as recorded at GPS ' ID];
                    
                    if any(strcmp(panels(p).data(d).variable,{'longitudinalDeviation','transversalDeviation','verticalDeviation'}))
                        lines(end+1).value=y2norm(0);
                        lines(end).description='Zero deviation -> overal linear trend';                        
                        lines(end).color=[.6 .6 .6];
                        lines(end).style='-';
                        lines(end).thickness=1;                       
                    end

                    %defining sections limits of data portions where different shifts were applied
                    %(ussually as result of GPS towers reset)
                    secTimes=cumsum([min(time); gps.(ID).(source).segmentLengths(:)]);
                    sections.y=[];
                    sections.time=[];
                    for i=1:length(secTimes)
                        idx=find(time>=secTimes(i),1,'first');
                        if ~isempty(idx)
                            sections.time(end+1)=time(idx);
                            sections.y(end+1)=yData(idx);
                        end
                    end

                    % finding positions [east north elev depth]
                    pos.east=mean(gps.(ID).(source).x);
                    pos.north=mean(gps.(ID).(source).y);
                    pos.elev=mean(gps.(ID).(source).y);
                    pos.thickness=NaN;

                case 'meteo'
                    switch var
                        case 'temperature'
                            if nDataFields>1 && all(~isnan(panels(p).axisLims.time_days))%if meteo data is together with other data in the panel, it is subseted to the time frame of the other data
                                [yData time] = timeSubset(panels(p).axisLims.time_days,ambientTemp.time,ambientTemp.temp);
                            else
                                yData=ambientTemp.temp;
                                time=ambientTemp.time;
                            end
                            [norm2y y2norm yData]=normalize(yData, time,panels(p).data(d).normMode);
                            
                            lines(end+1).value=y2norm(0);
                            lines(end).description='0°C freezing line';                        
                            lines(end).color=[1 0.75 0.27];
                            lines(end).style='-';
                            lines(end).thickness=2;

                            axisID='temp_C';

                            
                            color=[1 1 0.4];
                        case 'melt'
                            north= panels(p).meanPos(2);
                            if isempty(north) || isnan(north) || north==0
                                display(['Invalid mean northing for panel(' num2str(north) ') using default value (aprox. pos. of central GPS tower) to compute upstream melt.']);
                                north=6744200;%approx. northing of centra GPS tower
                            end
                            [~, northIdx]=min(abs(sMelt.northing-north));
                            if nDataFields>1 && all(~isnan(panels(p).axisLims.time_days)) %if meteo data is together with other data in the panel, it is subseted to the time frame of the other data
                                [yData time] = timeSubset(panels(p).axisLims.time_days,sMelt.time,sMelt.melt(:,northIdx)*24);
                            else
                                yData=sMelt.melt(:,northIdx)*24;
                                time=sMelt.time;
                            end
                            [norm2y y2norm yData]=normalize(yData, time, panels(p).data(d).normMode);
                            axisID='melt_mmPerDay';
                            color=[0 1 1];
                    end
                    nSamples=length(time);
                    breakes=[1 nSamples];
                    sendToBack=[sendToBack; d];
            end
            panels(p).data(d).time=time;
            panels(p).data(d).breakes=breakes;
            %restrigting data to [0 1]
            yData(yData>1)=1;
            yData(yData<0)=0;
            panels(p).data(d).yData=yData;
            panels(p).data(d).sections=sections;
            panels(p).data(d).norm2y=norm2y;
            panels(p).data(d).y2norm=y2norm;
            panels(p).data(d).lines=lines;
            panels(p).data(d).pos=pos; 
            panels(p).data(d).axisID=axisID;
            panels(p).data(d).description=yDescription;
            panels(p).data(d).selection=[];
            
            if isempty(cleanTimeLims)
                panels(p).data(d).cleanTimeLims=[min(time) max(time)];
            else
                panels(p).data(d).cleanTimeLims=cleanTimeLims; 
            end
            
            if ~isfield(panels(p).data(d),'color') || isempty(panels(p).data(d).color)
                % if there is no color information already we assign the default value
                panels(p).data(d).color=color;
            end           
        end
        % Once the panel is complete we rearange the data field to send to 
        % the back the data sets in sendToBack. Specially useful to put
        % meteorological data behind pressure or GPS time series
        for i=1:length(sendToBack)
            swapPanels([],[],[p sendToBack(i)],[p 1]);
        end
    end
    % Removing unused data from data structure
    sensorsInData=fieldnames(data);
    nSensorsInData=length(sensorsInData);
    for s=1:nSensorsInData
        if ~any(strcmp(sensorsInData{s},inUseSensors))
            data=rmfield(data,sensorsInData{s});
        end
    end
    
    
    for p=1:npanels
        nDataFields=length(panels(p).data);
        for d=1:nDataFields
            axisID=panels(p).data(d).axisID;
            % Updating limits of each axis
            panels(p).axisLims=updateLims(panels(p).axisLims,[],panels(p).data(d).norm2y,axisID);
            panels(p).axisLimsClean=updateLims(panels(p).axisLimsClean,panels(p).data(d).cleanTimeLims);
            % Updating the water equivalent pressure axis
            if any(strcmp(axisID,{'press_kPa','press_PSI'}))
                panels(p).axisLims=updateLims(panels(p).axisLims,[],@(x)panels(p).data(d).norm2y(x)/9.8,'press_mWaterEq');
                panels(p).axisLims=updateLims(panels(p).axisLims,[],@(x)panels(p).data(d).norm2y(x)*const.psiPerPascal*1000,'press_PSI');
            end
        end 
    end
    
end
function [n2y y2n nyAll nxAll ny nx]=normalize(y, x, normMode, deletedMask, thickness)
    % returns a normalized version of the values in x
    % and the handle to two functions:
    %   x2n Converts original values to normalized ones
    %   n2x Converts normalized values back into originals
    global displayStatus const
    if nargin<4 || isempty(deletedMask)
        deletedMask=false(length(y),1);
    end
    if isempty(normMode) || isempty(normMode{1})
        normMode={'range'};
    end
    if strcmp(normMode{1},'window')
        if any(isnan(displayStatus.tLims))
            normMode={'range'};
        else
            subsetY = timeSubset(displayStatus.tLims,x(~deletedMask),y(~deletedMask));
            if isempty(subsetY)
                normMode={'range'};
            end
        end
        
    end
    switch normMode{1}
        case 'range'
            miny=min(y(~deletedMask));
            maxy=max(y(~deletedMask));
        case 'rawRange'
            miny=min(y);
            maxy=max(y);
        case {'manual','cursor'}
            miny=min(normMode{2});
            maxy=max(normMode{2});
        case 'window'
            miny=min(subsetY);
            maxy=max(subsetY);
        case 'waterColumn'
            miny=0;
            maxy=thickness*const.g;
        case 'Zero2Max'
            miny=0;
            maxy=max(y(~deletedMask));
        case 'waterColumnOrMax'
            miny=0;
            maxy=max(thickness*const.g,max(y(~deletedMask)));
    end
    
    margin=(maxy-miny)*0.01;
    miny=miny-margin;
    maxy=maxy+margin;
    range=maxy-miny;
    
    n2y=@(v)v*range+miny;
    y2n=@(v)(v-miny)/range;
    
    ny=y2n(y(~deletedMask));
    nx=x(~deletedMask);
    nyAll=y2n(y);
    nyAll(nyAll>1)=1;
    nyAll(nyAll<0)=0;
    nxAll=x;
end
function [intervals intervalCount] = getIntervals(indices,x,y)
    %getIntervals Separates intervals of data
    %   If incices has several but independent continous sections of ones and zeross
    %   getIntervals find, count and separate all the "ones" intervals and return
    %   an structure with the x, and y data for each interval, the start and end indexes
    %   and the number of elements of each interval
    indices=indices(:);
    inis=find((indices-[0;indices(1:end-1)])==1);
    ends=find((indices-[indices(2:end); 0])==1);
    intervals=[];
    intervalCount=length(inis);
    for i=1:intervalCount
        intervals(i).ini=inis(i);
        intervals(i).end=ends(i);
        intervals(i).n=ends(i)-inis(i)+1;
        if nargin>1
            intervals(i).x=x(inis(i):ends(i));
        end
        if nargin>2
            intervals(i).y=y(inis(i):ends(i));
        end
    end
end
function axisLims=updateLims(axisLims,time,norm2y,unit)
    % update time and Y limits of current axis
    if nargin==4
        % if a transformation function norm2y (from normalized units to real
        % scale y units) and a unit is given, we update y values
        if isempty(axisLims.(unit))
            axisLims.(unit)=[NaN NaN];
        end
        minY=norm2y(0);
        if ~isempty(minY)
            axisLims.(unit)(1)=min(axisLims.(unit)(1),minY);
        end
        maxY=norm2y(1);
        if ~isempty(maxY)
            axisLims.(unit)(2)=max(axisLims.(unit)(2),maxY);
        end
    end
    if ~isempty(time)
        axisLims.time_days(1)=min(axisLims.time_days(1),min(time));
        axisLims.time_days(2)=max(axisLims.time_days(2),max(time));
    end
end