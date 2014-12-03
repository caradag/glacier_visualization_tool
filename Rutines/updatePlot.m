function updatePlot(source,eventdata,jump,forceRePopulation)
global data panels fHandles displayStatus const metadata
global historyRecallPointer displayHistory
persistent oldTimeRange oldTimeLength
persistent tickList tickLabels tickScale

if nargin<3
    jump=0;
end
% ######################## Handling history ###############################
historyLength=length(displayHistory);
saveHistoryAfterPlot=true;
if jump && historyLength>0
    % If a jump is specified we move on the history
    newPointer=historyRecallPointer+jump;
    % If the new pointer is inside the historic record we reload display status
    if newPointer>=1 && newPointer<=historyLength
        historyRecallPointer=newPointer;
        displayStatus=displayHistory(historyRecallPointer);
        panels=displayStatus.panels;
        displayStatus=rmfield(displayStatus,'panels');
        saveHistoryAfterPlot=false;
    else
        return
    end
end
% #########################################################################

if nargin<4
    forceRePopulation=0;
end
axes(fHandles.axis);
cla;
hold on

if isempty(panels)
    addData();
end


populatePanels(forceRePopulation);
npanels=length(panels);
tic

%computing overall time range
tLims=nan(npanels,2);
for i=1:npanels
    tLims(npanels,1:2)=panels(i).axisLimsClean.time_days;%produces an with all the time limits [min max] of each panel in a row
end
% Setting the time limits to include all panels and +- 6 hours to see properly
% data at the start and the end
trange=[min(tLims(:))-0.5, max(tLims(:))+0.5];
displayStatus.tRange=trange;
displayStatus.nPanels=npanels;

updatePos('updatePlot');

% Creating time axis labels and ticks depending on length of currently 
% displayed time window
timelength=diff(displayStatus.tLims);
if isempty(oldTimeRange) || ~isequal(oldTimeRange,trange) || isempty(oldTimeLength) || ~isequal(oldTimeLength,timelength)
    [tickList tickLabels tickScale]=getTimeTicks(trange,timelength);
    oldTimeRange=trange;
    oldTimeLength=timelength;
    disp(['Time axis: ' num2str(toc)]); tic;
end

%%%%%%%%%%%%%%%% PLOTING PANELS %%%%%%%%%%%%%%%%%%%%%%
cmenu=[];
pcmenu=[];
delcmenu=[];
markersmenu=[];
refLineMenu=[];
sensorVoltPlotHandle=[];
sensorTempPlotHandle=[];

%##################### AXIS LABELS AND TICKS ##########################
%creating Y axis labels and ticks
yAxis();

for i=1:npanels
    nDataFields=length(panels(i).data);
    %##################### BACKGROUNDS ####################################
    % Ploting background colors to differnciate diferent panels and out of scale ranges
    pcmenu(i) = uicontextmenu; %creating right-click contextual menu

    %defining background color for current panel
    pColor=[1 1 1];
    if mod(i,2)==0
        pColor=[0.9 0.9 0.9];
    end

    % drawing main panel patch background
    patch(trange([1 1 2 2]),[i-1 i i i-1],pColor,'EdgeColor','none','UIContextMenu', pcmenu(i),'ButtonDownFcn',@figureKeyPress);

    % if any of the data series in the panel correspond to a pressure sensor we plot colored bacjground to show
    % ranges out of scale (i.e. out of nominal sensor pressure range and tolerance)
    if any(strcmp({panels(i).data.type},'sensor'))
        % If pressure data go above sensorPressureLimit (maximum rated pressure for the sensor, usually 200 psi for barksdales) the background color changes to a reddish value
        normSensorPLimit=panels(i).data.y2norm(const.sensorPressureLimit);
        if normSensorPLimit<1
            patch(trange([1 1 2 2]),[normSensorPLimit 1 1 normSensorPLimit]+i-1,pColor+[0 -0.05 -0.05],'EdgeColor','none','UIContextMenu', pcmenu(i),'ButtonDownFcn',@figureKeyPress);
        end
        % If pressure data go above sensorPressureTolerance (factoru defined parameter, usualy twice sensorPressureLimit) the background color changes to a even redder value
        normSensorPTolerance=panels(i).data.y2norm(const.sensorPressureTolerance);
        if normSensorPTolerance<1
            patch(trange([1 1 2 2]),[normSensorPTolerance 1 1 normSensorPTolerance]+i-1,pColor+[0 -0.15 -0.15],'EdgeColor','none','UIContextMenu', pcmenu(i),'ButtonDownFcn',@figureKeyPress);
        end
    end

    % Configuring right-click contextual menu
    uimenu(pcmenu(i), 'Label', ['Data source IDs: ' strjoin({panels(i).data.ID},', ')]);
    uimenu(pcmenu(i), 'Label', 'Move to top', 'Callback', {@swapPanels,i,npanels});
    uimenu(pcmenu(i), 'Label', 'Move to bottom', 'Callback', {@swapPanels,i,1});
    uimenu(pcmenu(i), 'Label', 'Remove', 'Callback', {@swapPanels,i,[]});
    uimenu(pcmenu(i), 'Label', 'Add data', 'Callback', {@addData,i});


    %##################### VERTICAL TIME LINES ############################
    %year vertical lines
    selTicks=tickScale=='y';
    plot(repmat(tickList(selTicks)',2,1),repmat([i-1; i],1,sum(selTicks)),':','Color',[1    0    0],'UIContextMenu', pcmenu(i),'ButtonDownFcn',@figureKeyPress);
    %month vertical lines
    selTicks=tickScale=='m';
    plot(repmat(tickList(selTicks)',2,1),repmat([i-1; i],1,sum(selTicks)),':','Color',[0.6 0.6 0.6],'UIContextMenu', pcmenu(i),'ButtonDownFcn',@figureKeyPress);
    %day vertical lines
    selTicks=tickScale=='d';
    plot(repmat(tickList(selTicks)',2,1),repmat([i-1; i],1,sum(selTicks)),'-','Color',[0.8 0.8 0.8],'UIContextMenu', pcmenu(i),'ButtonDownFcn',@figureKeyPress);
    %hours vertical lines
    selTicks=tickScale=='h';
    plot(repmat(tickList(selTicks)',2,1),repmat([i-1; i],1,sum(selTicks)),':','Color',[0.5 0.9 0.5],'UIContextMenu', pcmenu(i),'ButtonDownFcn',@figureKeyPress);
    %##################### TIME SERIES ####################################
    for d=1:nDataFields
        ID=panels(i).data(d).ID;
        time=panels(i).data(d).time;
        yData=panels(i).data(d).yData;
        nData=length(time);
        if isempty(yData)
            disp(['Skkiping ' ID])
            continue;
        end
        %##################### REFERENCE LINES ############################
        % (i.e. Oberburden pressure, freezing point, critical voltages, etc.)
        if nDataFields==1 || panels(i).data(d).selected
            for k=1:length(panels(i).data(d).lines)
                refLineMenu(end+1) = uicontextmenu;
                plot(trange,[1 1]*(panels(i).data(d).lines(k).value+i-1),panels(i).data(d).lines(k).style,'LineWidth',panels(i).data(d).lines(k).thickness,'Color',panels(i).data(d).lines(k).color,'UIContextMenu', refLineMenu(end),'ButtonDownFcn',@figureKeyPress);
                uimenu(refLineMenu(end), 'Label', panels(i).data(d).lines(k).description);
            end        
        end
        %##### MASKED POINTS (deletes, questionable, etc.) AND OFFSETS ####
        % Plotting deleted points if requested
            
        % At the same time we build an integrated mask to be used later for data plotting
        nMasks=length(const.dataMasks);
        integratedMask=false(nData,1);
        selection=panels(i).data(d).selection;        
        for m=1:nMasks
            if isfield(panels(i).data(d),const.dataMasks{m}) && ~isempty(panels(i).data(d).(const.dataMasks{m}))
                % Dealing with logical masks i.e. deleted, questionable, etc...
                if const.dataMaskIsLogical(m)
                    integratedMask(panels(i).data(d).(const.dataMasks{m}))=true;
                    if displayStatus.dataMasks(m)
                        plot(time(panels(i).data(d).(const.dataMasks{m})),yData(panels(i).data(d).(const.dataMasks{m}))+i-1,'x','Color',const.dataMasksColor{m},'MarkerSize',4);
                        if ~isempty(selection)
                            plot(time(panels(i).data(d).(const.dataMasks{m}) & selection),yData(panels(i).data(d).(const.dataMasks{m}) & selection)+i-1,'og');
                        end
                    end
                % Dealing with double masks i.e. offset
                elseif ~displayStatus.dataMasks(m)
                    switch const.dataMasks{m}
                        case 'offset'
                            % If offsets should not be displayed we substract them
                            %yData=yData-((panels(i).data(d).offset/1000)/diff(panels(i).data(d).norm2y([0 1])));
                        otherwise
                            disp('Unknown double mask type')
                    end
                end
            end
        end
        %##################### SECTIONS DELIMITERS ########################
        if ~isempty(panels(i).data(d).sections)
            plot(panels(i).data(d).sections.time,panels(i).data(d).sections.y+i-1,'r*','MarkerSize',4,'ButtonDownFcn',@figureKeyPress);
        end
        %##################### TIME SERIE Y DATA ##########################
        % Plotting main datarange
        breakes=panels(i).data(d).breakes;
        nSegments=size(breakes,1);
        panels(i).data(d).lineHandle=[];

        if nSegments>100 || ~panels(i).data(d).selected
            % If there is too many segments we plot them all at once, but first
            % insert NaN in between them so they won't be connected by any line when plotting
            if panels(i).data(d).selected
                warning(['Too many segments (' num2str(nSegments) '), detailed plotting deactivated']);
            end
            brokenIdex=zeros(nData+nSegments-1,1);
            toSetNan=zeros(nSegments,1);
            for segment=1:nSegments
                brokenIdex((breakes(segment,1):breakes(segment,2))+segment-1)=breakes(segment,1):breakes(segment,2);
            end
            toSetNan=(brokenIdex==0);
            brokenIdex(toSetNan)=1;
            yData=yData(brokenIdex);
            time=time(brokenIdex);
            if ~isempty(selection)
                selection=selection(brokenIdex);
                selection(toSetNan(1:end-1))=false;
            end
            integratedMask=integratedMask(brokenIdex);
            integratedMask(toSetNan(1:end-1))=true;
            nData=nData+nSegments-1;
            nSegments=1;
            breakes=[1 nData];
        elseif nSegments>50
            warning(['Too many segments (' num2str(nSegments) '), plotting will be slow']);
        end
        for segment=1:nSegments
            panels(i).data(d).lineHandle(segment)=NaN;
            % Inicializing logical index of points to plot
            toPlot=false(nData,1);
            % Setting toPlot true for elements in current segment
            toPlot(breakes(segment,1):breakes(segment,2))=true;
                        
            if ~any(toPlot & ~integratedMask)
                continue
            end
            yData(toPlot & integratedMask)=NaN;
            color=panels(i).data(d).color;
            isSelected=~isempty(selection) && all(selection(toPlot));
            if isSelected
                color=[0 1 0];
            end 
            % Define the context menu
            cmenu(i,d) = uicontextmenu;
            lineWidth=double(panels(i).data(d).selected)+1;
            style=panels(i).data(d).style;
            % Plotting data
            panels(i).data(d).lineHandle(segment)=plot(time(toPlot),yData(toPlot)+i-1,'Color',color,'LineWidth',lineWidth,'LineStyle',style(1:4),'Marker',style(5:8),'MarkerSize',3,'MarkerEdgeColor',color,'MarkerFaceColor',color,'UIContextMenu', cmenu(i,d),'ButtonDownFcn',{@figureKeyPress,i,[d segment]},'Tag','Data serie');
            % Ploting green circles around selected points that don't belong to any fully selected segment
            if ~isempty(selection) && ~all(selection(toPlot)) && any(selection(toPlot))
                toPlot=toPlot & selection;
                plot(time(toPlot),yData(toPlot)+i-1,'go');
            end 

            % Define the context menu items
            switch panels(i).data(d).type
                case 'sensors'
                    sensorMake=upper(data.(ID).metadata.sensorMake{1}{1});
                    sensorSnubber=upper(data.(ID).metadata.snubber{1}{1});
                    if isempty(sensorMake)
                        sensorMake='Unknown';
                    end
                    if isempty(sensorSnubber)
                        sensorSnubber='no';
                    end
                    uimenu(cmenu(i,d), 'Label', ['Sensor: ' ID(2:end) ' @ ' data.(ID).grid{1}],'Callback',['clipboard(''copy'',''' ID(2:end) ' @ ' char(data.(ID).grid) ''')']);
                    % Info menu group
                    infoMenu=uimenu(cmenu(i,d), 'Label', 'Sensor info');
                    uimenu(infoMenu, 'Label', ['Flag: ' upper(metadata.sensors.(ID).flag)]);
                    uimenu(infoMenu, 'Label', ['Depth: ' num2str(data.(ID).position{1}.thickness) ' m']);
                    uimenu(infoMenu, 'Label', ['Overburden: ' sprintf('%.0f',data.(ID).position{1}.thickness*9.8*916) ' kPa / ' sprintf('%.1f',data.(ID).position{1}.thickness*9.8*916*const.psiPerPascal) ' psi / ' sprintf('%.1f',data.(ID).position{1}.thickness*0.916) ' m']);
                    uimenu(infoMenu, 'Label', ['Grid: ' data.(ID).grid{1}]);
                    uimenu(infoMenu, 'Label', ['Hole: ' data.(ID).metadata.hole{1}{1}]);
                    uimenu(infoMenu, 'Label', ['Type: ' sensorMake ' Snubber: ' sensorSnubber]);
                    uimenu(infoMenu, 'Label', ['Logger(s): ' sprintf('%s, ',data.(ID).logger{1}{:})]);
                    uimenu(infoMenu, 'Label', 'Open raw file at this point', 'Callback', {@openRawData,i,d});
                    uimenu(infoMenu, 'Label', 'Full sensor info', 'Callback', {@getFullInfo,i,d});
                    %uimenu(cmenu(i,d), 'Label', 'View/Edit comments', 'Callback', ['selSensor=''' ID '''; editComments;']);
                    %uimenu(cmenu(i,d), 'Label', 'Zoom to this sensor', 'Callback', ['selSensor=''' ID '''; zoomPressTo;']);
                    %uimenu(cmenu(i,d), 'Label', 'Zoom time to this sensor', 'Callback', ['selSensor=''' ID ''';selID=' num2str(i) '; zoomTo;']);
                    % Selection menu group
                    selectionMenu=uimenu(cmenu(i,d), 'Label', 'Data selection');
                    if isSelected
                        uimenu(selectionMenu, 'Label', 'Unselect this segment', 'Callback',{@doSelect,0,[i d],'segment',segment});
                    else
                        uimenu(selectionMenu, 'Label', 'Select this segment', 'Callback',{@doSelect,1,[i d],'segment',segment});
                    end
                    uimenu(selectionMenu, 'Label', 'Select this point', 'Callback', {@doSelect,1,[i d],'point'});
                    uimenu(selectionMenu, 'Label', 'Select all after this point', 'Callback', {@doSelect,1,[i d],'after_point'});
                    uimenu(selectionMenu, 'Label', 'Select all from this segment', 'Callback',{@doSelect,1,[i d],'segment_and_after',segment});
                    uimenu(selectionMenu, 'Label', 'Select all', 'Callback',{@doSelect,1,[i d],'all'});
                    uimenu(selectionMenu, 'Label', 'Unselect all', 'Callback',{@doSelect,0,[i d],'all'});
                    
                    uimenu(cmenu(i,d), 'Label', 'Flag sensor','Callback',{@doFlag,ID},'Separator','on');
                    
                case 'gps'
                    uimenu(cmenu(i,d), 'Label', [panels(i).data(d).variable ' at station: ' ID ' from ' panels(i).data(d).source ' data'],'Callback',['clipboard(''copy'',''' ID ''')']);
                    uimenu(cmenu(i,d), 'Label', 'Explore GPS data','Callback',{@launchGPSexplorer,i,d});

                case 'meteo'
                    uimenu(cmenu(i,d), 'Label', [upper(panels(i).data(d).variable(1)) panels(i).data(d).variable(2:end) ' record from ' panels(i).data(d).source]);
            end
            if d<nDataFields
                uimenu(cmenu(i,d), 'Label', 'Send to the front of the panel', 'Callback',{@swapPanels,[i d],[i nDataFields]});
            end
            if d>1
                uimenu(cmenu(i,d), 'Label', 'Send to the back of the panel', 'Callback',{@swapPanels,[i d],[i 1]});
            end
            if panels(i).data(d).selected
                uimenu(cmenu(i,d), 'Label', 'Unselect timeseries', 'Callback',{@selectedSensor,[]});
            end
            uimenu(cmenu(i,d), 'Label', 'Supress jump on selection', 'Callback',{@supressJump,i,d});
            
            uiStyle=uimenu(cmenu(i,d), 'Label', 'Style','Separator','on');
            uimenu(uiStyle, 'Label', 'Change color', 'Callback',{@changeDataField,[i d],'color'});
            uimenu(uiStyle, 'Label', 'Change style', 'Callback',{@changeDataField,[i d],'style'});
            uimenu(uiStyle, 'Label', 'Switch to markers', 'Callback',{@changeDataField,[i d],'style','none.   '});
            uimenu(uiStyle, 'Label', 'Switch to line', 'Callback',{@changeDataField,[i d],'style','-   none'});
            
            uiNormalization=uimenu(cmenu(i,d), 'Label', 'Vertical limits');
            for nm=1:length(const.normModes)
                sel='    ';
                if strcmp(panels(i).data(d).normMode{1},const.normModes{nm})
                    sel='→ ';
                end
                uimenu(uiNormalization, 'Label', [sel const.normModesTexts{nm}], 'Callback',{@changeDataField,[i d],'normalization',const.normModes{nm}});
            end

            uimenu(cmenu(i,d), 'Label', 'Apply normalization mode to all', 'Callback',{@changeDataField,[i d],'verticalLimitsToAll'});
            %uimenu(cmenu(i,d), 'Label', 'Apply filter', 'Callback',{@changeDataField,[i d],'filter'});
            uimenu(cmenu(i,d), 'Label', 'Remove sensor plot', 'Callback', {@swapPanels,[i d],[]});
        end
        %##################### SPECIAL OVERLAY DATA ##########################
        % Plotting file limits and installation times for pressure sensors
        if (panels(i).data(d).selected || (npanels==1 && nDataFields==1)) && strcmp(panels(i).data(d).type,'sensors') && strcmp(panels(i).data(d).variable,'pressure')
            % Plotting installation times
            instTimes=data.(ID).metadata.installationTime{1};
            nInstTimes=size(instTimes,1);
            instTimes=datenum([instTimes(:,1) ones(nInstTimes,2) fix(instTimes(:,3)/100) mod(instTimes(:,3),100) zeros(nInstTimes,1)])-1+instTimes(:,2);
            for fc=1:nInstTimes
                markersmenu(end+1) = uicontextmenu;
                plot([1 1]*instTimes(fc),[i-1,i],'r','UIContextMenu', markersmenu(end));
                [year,~,~]=datevec(instTimes(fc));
                DOY=floor(instTimes(fc)-datenum([year 1 1])+1);
                uimenu(markersmenu(end), 'Label',['Sensor installed/reinstaled on: ' datestr(instTimes(fc)) ' (DOY ' num2str(DOY) ')']);
            end
            % PLoting file starts
            fileStartsTimes=data.(ID).time.serialtime(data.(ID).metadata.files.limits{1}(:,1));
            nfiles=length(fileStartsTimes);
            for fc=1:nfiles
                [~, startPoint]=min(abs(time-fileStartsTimes(fc)));
                markersmenu(end+1) = uicontextmenu;
                plot(fileStartsTimes(fc),panels(i).data(d).y2norm((data.(ID).pressure{1}(startPoint)+panels(i).data(d).offset(startPoint))/1000)+i-1,'r>','UIContextMenu', markersmenu(end));
                uimenu(markersmenu(end), 'Label',['File: ' data.(ID).metadata.files.names{1}{fc}]);
                uimenu(markersmenu(end), 'Label',['Start on : ' datestr(fileStartsTimes(fc))]);
                uimenu(markersmenu(end), 'Label','Open', 'Callback',['edit ' const.rawDataFolder data.(ID).metadata.files.names{1}{fc}]);
            end
            % Ploting offset changes
            offsetDiffs=diff(panels(i).data(d).offset);
            offsetChanges=find(offsetDiffs~=0);
            nChanges=length(offsetChanges);
            for fc=1:nChanges
                style='k^';
                if offsetDiffs(offsetChanges(fc))<0
                    style='kv';
                end
                markersmenu(end+1) = uicontextmenu;
                pt=find(time>=time(offsetChanges(fc)) & ~isnan(yData),1,'first');
                plot(time(pt),yData(pt)+i-1,style,'UIContextMenu', markersmenu(end));
                uimenu(markersmenu(end), 'Label',sprintf('Offset change of %+.1f kPa',offsetDiffs(offsetChanges(fc))/1000));
            end
            
        end
    end
end
[selPanel selIdx] = selectedSensor();
infoMsg=['Displaying ' num2str(npanels) ' panels with data from ' datestr(trange(1)) ' to ' datestr(trange(2))];
if ~isempty(selPanel) && ~isempty(selIdx)
    ID=panels(selPanel).data(selIdx).ID;
    infoMsg=[infoMsg ', Selected: ' ID];
    if strcmp(panels(selPanel).data(selIdx).type,'sensors')
        infoMsg=[infoMsg ' (' upper(metadata.sensors.(ID).flag(1)) ')'];
    end
end
set(fHandles.cursorInfo,'String',infoMsg);

disp(['Data plotting: ' num2str(toc)]); tic;

%loading tick labels
set(fHandles.axis,'XTick',tickList,'XTickLabel',tickLabels);
%setting vertical axis
setYAxis();
plotTimeSel();

disp(['Setting axes: ' num2str(toc)]); tic;

% ######################## Saving history ###############################
if saveHistoryAfterPlot
    saveHistory();
end
% #########################################################################

displayMap();
% % set focus to main figure
% set(findobj(fHandles.browsefig, 'Type', 'uicontrol'), 'Enable', 'off');
% drawnow;
% set(findobj(fHandles.browsefig, 'Type', 'uicontrol'), 'Enable', 'on');
end

%%%%%%%%%%%%%%%%%%%%%% TIME AXIS TICKS AND LABELS %%%%%%%%%%%%%%%%%%%%%%%%%
function [tickList tickLabels tickScale]=getTimeTicks(trange,timelength)
    % Creating time axis labels and ticks depending on length of currently 
    % displayed time window
    % 
    % Returned values are:
    % tickList -> Position of tick marks
    % tickLabels -> Labels corresponding to each tick mark
    % tickScale -> time scale associated wich each tick mark (days, month, year)

    if timelength<1 %timelength less than 1 day produces tick marks every 3 hours
        [tickList tickLabels tickScale] = smartDateTick(trange(1),trange(2),'3h','6h');
    elseif timelength<2 %timelength less than 2 days produces tick marks every 6 hours
        [tickList tickLabels tickScale] = smartDateTick(trange(1),trange(2),'6h','12h');
    elseif timelength<5 %timelength less than 5 days produces tick marks every 12 hours
        [tickList tickLabels tickScale] = smartDateTick(trange(1),trange(2),'12h','d');
    elseif timelength<20  %if timelength less than 20 days labels will be on every tick mark (daily)
        [tickList tickLabels tickScale] = smartDateTick(trange(1),trange(2),'d','d');
    elseif timelength<30  %if timelength is between 20 and 30 days, labels will be every 2 tick marks (every two days)
        [tickList tickLabels tickScale] = smartDateTick(trange(1),trange(2),'d','2d');
    elseif timelength<100 %if timelength is between 30 and 100 days, labels will be every 4 tick marks (every four days)
        [tickList tickLabels tickScale] = smartDateTick(trange(1),trange(2),'d','4d');
    elseif timelength<150 %if timelength is between 100 and 150 days, labels will be every 7 tick marks (weekly)
        [tickList tickLabels tickScale] = smartDateTick(trange(1),trange(2),'d','-7d');
    elseif timelength<200 %if timelength is between 150 and 200 days, labels will be every 15 tick marks (every 15 days)
        [tickList tickLabels tickScale] = smartDateTick(trange(1),trange(2),'5d','-15d');
    elseif timelength<600  %timelength less than 600 days produces tick marks every month
        [tickList tickLabels tickScale] = smartDateTick(trange(1),trange(2),'15d','m');
    elseif timelength<1460 %timelength less than 4 years produces tick marks every two month
        [tickList tickLabels tickScale] = smartDateTick(trange(1),trange(2),'m','2m');
    else %if timelength is more vthan 4 years, labels will be every 6 month
        [tickList tickLabels tickScale] = smartDateTick(trange(1),trange(2),'m','6m');
    end
end


            