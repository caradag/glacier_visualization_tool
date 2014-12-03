function addData(source,eventdata,currentPanel)
    global gps gridList panels displayStatus const metadata
    if isempty(panels)
        panels=struct('data',{});
    end
    if nargin<3
        currentPanel=[];
    end
	if isfield(displayStatus,'tLims')
        timeWindow=displayStatus.tLims;
    elseif isfield(displayStatus,'tRange')
        timeWindow=displayStatus.tRange;
    else
        timeWindow=[-Inf Inf];
    end
    % ############## CREATING LISTS #######################
    % GPS station
    gpss = sort(fieldnames(gps));
    % Sensors station
    sensors = sort(fieldnames(metadata.sensors));
    nSensors=length(sensors);
    for s=1:nSensors
        if any(strcmp(metadata.sensors.(sensors{s}).flag,const.sensorFlags) & displayStatus.sensorFlags)
            sensors{s}=[sensors{s}(2:end) ' (' metadata.sensors.(sensors{s}).flag(1) ')'];
        else
            sensors{s}='';
        end
    end
    sensors(strcmp(sensors,''))=[];
    
    % Grids positions
    grids = sort(fieldnames(gridList));
    nGrids=length(grids);
    for g=1:nGrids
        grids{g}=strrep(grids{g},'_', '.');
    end
    % Meteo data
    meteos={'Temperature','Melt'};
    
    % ############## CREATING GUI #######################
    % SETING DEFAULTS
    gpsSources={'Relative'};
    gpsVariables={'speed'};
    transducerVariables={'pressure'};
    
    enableValues={'off','on'};
    W=700;
    H=530;
    dlg = figure('Name','Select data serie to add to the workspace','Position',[200 154 W H],'MenuBar','none','NumberTitle','off');
    colWith=150;
    baseX=10;
    %%%%%%%%%%%%%% GRID LOCATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    h=20; Y=H-h-5;
    uicontrol(dlg,'Style', 'text','String','Grid location','Position', [baseX Y colWith h],'FontSize',14);

    h=22; Y=Y-h-5; 
    radioGroupGrid=uibuttongroup('Units','pixels','Position', [baseX Y colWith h]);
    uicontrol(dlg,'Style', 'text','String','By','Position', [2 2 20 h-6],'parent',radioGroupGrid);
    uicontrol(dlg,'Style', 'radiobutton','String','Row','Position', [25 2 50 h-6],'parent',radioGroupGrid);
    uicontrol(dlg,'Style', 'radiobutton','String','Column','Position', [75 2 70 h-6],'parent',radioGroupGrid);
    
    h=H-65; Y=Y-h-5; 
    gridsList=uicontrol(dlg,'Style', 'listbox','String',grids,'Position', [baseX Y colWith h],'HorizontalAlignment','left','Max',length(grids),'Value',[]);
    set(radioGroupGrid,'SelectionChangeFcn',{@selcbk, gridsList},'Visible','on');

    %%%%%%%%%%%%%% SENSOR %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    baseX=baseX+colWith+10;
    h=20; Y=H-h-5;
    uicontrol(dlg,'Style', 'text','String','Pressure sensor','Position', [baseX Y colWith h],'FontSize',14);

    h=H-65; Y=Y-h-5-22-5; 
    sensorList=uicontrol(dlg,'Style', 'listbox','String',sensors,'Position', [baseX Y colWith h],'HorizontalAlignment','left','Max',length(sensors),'Value',[]);
    
    %%%%%%%%%%%%%% GPS %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    baseX=baseX+colWith+10;
    h=20; Y=H-h-5;
    uicontrol(dlg,'Style', 'text','String','GPS station','Position', [baseX Y colWith h],'FontSize',14);
    
    h=22; Y=Y-h-5; 
    radioGroupGPS=uibuttongroup('Units','pixels','Position', [baseX Y colWith h]);
    uicontrol(dlg,'Style', 'text','String','By','Position', [2 2 20 h-6],'parent',radioGroupGPS);
    uicontrol(dlg,'Style', 'radiobutton','String','Row','Position', [25 2 50 h-6],'parent',radioGroupGPS);
    uicontrol(dlg,'Style', 'radiobutton','String','Column','Position', [75 2 70 h-6],'parent',radioGroupGPS);
    
    h=H-180-65; Y=Y-h-5; 
    gpsList=uicontrol(dlg,'Style', 'listbox','String',gpss,'Position', [baseX Y colWith h],'HorizontalAlignment','left','Max',length(gpss),'Value',[]);
    set(radioGroupGPS,'SelectionChangeFcn',{@selcbk, gpsList},'Visible','on');

    %%%%%%%%%%%%%% METEO %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    h=20; Y=Y-h-5; 
    uicontrol(dlg,'Style', 'text','String','Meteo data','Position', [baseX Y colWith h],'FontSize',14);
    
    h=Y-10-5; Y=Y-h-5; 
    meteoList=uicontrol(dlg,'Style', 'listbox','String',meteos,'Position', [baseX Y colWith h],'HorizontalAlignment','left','Max',length(meteos),'Value',[]);

    %%%%%%%%%%%%%% CONFIGURATIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    baseX=baseX+colWith+10;
    colWith=200;
    
    h=32; Y=H-h-5; 
    onlyOnWindow=uicontrol(dlg,'Style', 'checkbox','Position', [baseX Y 20 h],'Callback',@listDataInTimeWindow);
    uicontrol(dlg,'Style', 'text','String',{'Only show data in current','time window              '},'Position', [baseX+25 Y colWith-25 h],'FontSize',10,'HorizontalAlignment','left');

    h=6*23; Y=Y-h-5; 
    radioDisplayMode=uibuttongroup('Units','pixels','Position', [baseX Y colWith h]);iY=h-25;
    uicontrol(dlg,'Style', 'text','String','Display mode','Position', [2 iY colWith-4 20],'parent',radioDisplayMode,'FontSize',12);iY=iY-20;
    uicontrol(dlg,'Style', 'radiobutton','String',' One panel per instrument','Position', [2 iY colWith-4 20],'parent',radioDisplayMode);iY=iY-22;
    uicontrol(dlg,'Style', 'radiobutton','String',' One panel per variable','Position', [2 iY colWith-4 20],'parent',radioDisplayMode);iY=iY-22;
    uicontrol(dlg,'Style', 'radiobutton','String',' Together in a new panel','Position', [2 iY colWith-4 20],'parent',radioDisplayMode);iY=iY-22;
    uicontrol(dlg,'Style', 'radiobutton','String',' As overlay in current panel','Position', [2 iY colWith-4 20],'parent',radioDisplayMode,'Enable',enableValues{~isempty(currentPanel)+1});iY=iY-22;
    uicontrol(dlg,'Style', 'radiobutton','String',' As overlay in all panels','Position', [2 iY colWith-4 20],'parent',radioDisplayMode,'Enable',enableValues{~isempty(panels)+1});
    set(radioDisplayMode,'Visible','on');

    h=3*23; Y=Y-h-5; 
    radioGPSSource=uibuttongroup('Units','pixels','Position', [baseX Y colWith h]);iY=h-25;
    uicontrol(dlg,'Style', 'text','String','GPS sources','Position', [2 iY colWith-4 20],'parent',radioGPSSource,'FontSize',12);iY=iY-20;
    uicontrol(dlg,'Style', 'checkbox','String',' Relative','Position', [2 iY colWith/2-4 20],'parent',radioGPSSource,'Min',0,'Max',1,'Value',1,'Callback',{@setGpsSource,'Relative'});
    uicontrol(dlg,'Style', 'checkbox','String',' PPP','Position', [colWith/2 iY colWith/2-4 20],'parent',radioGPSSource,'Min',0,'Max',1,'Callback',{@setGpsSource,'PPP'});iY=iY-22;
    uicontrol(dlg,'Style', 'checkbox','String',' SCOUT','Position', [2 iY colWith/2-4 20],'parent',radioGPSSource,'Min',0,'Max',1,'Callback',{@setGpsSource,'SCOUT'});
    uicontrol(dlg,'Style', 'checkbox','String',' Lucas','Position', [colWith/2 iY colWith/2-4 20],'parent',radioGPSSource,'Min',0,'Max',1,'Callback',{@setGpsSource,'Lucas'});
    set(radioGPSSource,'Visible','on');

    h=6*23; Y=Y-h-5; 
    radioGPSMode=uibuttongroup('Units','pixels','Position', [baseX Y colWith h]);iY=h-25;
    uicontrol(dlg,'Style', 'text','String','GPS variables','Position', [2 iY colWith-4 20],'parent',radioGPSMode,'FontSize',12);iY=iY-20;
    uicontrol(dlg,'Style', 'checkbox','String',' Speed','Position', [2 iY colWith-4 20],'parent',radioGPSMode,'Min',0,'Max',1,'Value',1,'Callback',{@setGpsVariable,'speed'});iY=iY-22;
    uicontrol(dlg,'Style', 'checkbox','String',' Projected speed','Position', [2 iY colWith-4 20],'parent',radioGPSMode,'Min',0,'Max',1,'Callback',{@setGpsVariable,'projSpeed'});iY=iY-22;
    uicontrol(dlg,'Style', 'checkbox','String',' Longitudinal deviation','Position', [2 iY colWith-4 20],'parent',radioGPSMode,'Min',0,'Max',1,'Callback',{@setGpsVariable,'longitudinalDeviation'});iY=iY-22;
    uicontrol(dlg,'Style', 'checkbox','String',' Transversal deviation','Position', [2 iY colWith-4 20],'parent',radioGPSMode,'Min',0,'Max',1,'Callback',{@setGpsVariable,'transversalDeviation'});iY=iY-22;
    uicontrol(dlg,'Style', 'checkbox','String',' Vertical deviation','Position', [2 iY colWith-4 20],'parent',radioGPSMode,'Min',0,'Max',1,'Callback',{@setGpsVariable,'verticalDeviation'});iY=iY-22;
    set(radioGPSMode,'Visible','on');

    h=4*23; Y=Y-h-5; 
    radioTransducerVars=uibuttongroup('Units','pixels','Position', [baseX Y colWith h]);iY=h-25;
    uicontrol(dlg,'Style', 'text','String','Transducer variables','Position', [2 iY colWith-4 20],'parent',radioTransducerVars,'FontSize',12);iY=iY-20;
    uicontrol(dlg,'Style', 'checkbox','String',' Pressure','Position', [2 iY colWith-4 20],'parent',radioTransducerVars,'Min',0,'Max',1,'Value',1,'Callback',{@setTransducerVariable,'pressure'});iY=iY-22;
    uicontrol(dlg,'Style', 'checkbox','String',' Logger temperature','Position', [2 iY colWith-4 20],'parent',radioTransducerVars,'Min',0,'Max',1,'Callback',{@setTransducerVariable,'temperature'});iY=iY-22;
    uicontrol(dlg,'Style', 'checkbox','String',' Battery voltage','Position', [2 iY colWith-4 20],'parent',radioTransducerVars,'Min',0,'Max',1,'Callback',{@setTransducerVariable,'battvolt'});iY=iY-22;
    set(radioTransducerVars,'Visible','on');
    
    h=25; Y=Y-h-5; 
    uicontrol('Style', 'pushbutton','String','Map','Position', [baseX Y (colWith/2-5) h],'Callback',@switchToMap);
    uicontrol('Style', 'pushbutton','String','Apply','Position', [baseX+colWith/2 Y colWith/2 h],'Callback',@generatePanels);
    uiwait(dlg);
    updatePlot();
    %######################################################################
    %######################## NESTED FUNCTIONS ############################
    %######################################################################

    %#################### GENERATING panels STRUCTURE #####################
    function generatePanels(source,eventdata)
        % Function that reads the status of the GUI and modify the panels
        % structure to add selected data series
        dataGroups=struct('data',{});
        %GRIDS
        list=get(gridsList,'String');
        values=get(gridsList,'Value');
        for j=1:length(transducerVariables)
            for i=1:length(values)
                selSensors=gridList.(strrep(list{values(i)},'.', '_'));
                dataGroups(end+1).data=[];
                for k=1:length(selSensors)
                    dataGroups(end).data(end+1).type='sensors';
                    dataGroups(end).data(end).variable=transducerVariables{j};
                    dataGroups(end).data(end).source='final';
                    dataGroups(end).data(end).ID=['S' selSensors{k}];
                end
            end
        end
        %sensors
        list=get(sensorList,'String');
        values=get(sensorList,'Value');
        for i=1:length(values)
            for j=1:length(transducerVariables)
                dataGroups(end+1).data=[];
                dataGroups(end).data(end+1).type='sensors';
                dataGroups(end).data(end).variable=transducerVariables{j};
                dataGroups(end).data(end).source='final';
                dataGroups(end).data(end).ID=['S' list{values(i)}(1:end-4)];
            end
        end
        %GPS
        list=get(gpsList,'String');
        values=get(gpsList,'Value');
        for i=1:length(values)
            for j=1:length(gpsSources)
                for k=1:length(gpsVariables)
                    dataGroups(end+1).data=[];
                    dataGroups(end).data(end+1).type='gps';
                    dataGroups(end).data(end).variable=gpsVariables{k};
                    dataGroups(end).data(end).source=gpsSources{j};
                    dataGroups(end).data(end).ID=list{values(i)};
                end
            end
        end
        %meteo
        list=get(meteoList,'String');
        values=get(meteoList,'Value');
        for i=1:length(values)
            dataGroups(end+1).data=[];
            dataGroups(end).data(end+1).type='meteo';
            dataGroups(end).data(end).variable=lower(list{values(i)});
            dataGroups(end).data(end).source='MidMet AWS';
            dataGroups(end).data(end).ID=lower(list{values(i)}(1:4));
        end
        
        
        dispMode=get(get(radioDisplayMode,'SelectedObject'),'String');
        if strcmp(dispMode,' One panel per variable')
            for i=1:length(dataGroups)
                panels(end+1).data=dataGroups(i).data;
            end
            delete(dlg);
            return
        end
        
        if strcmp(dispMode,' One panel per instrument')
            IDs={};
            for p=1:length(dataGroups)
                for d=1:length(dataGroups(p).data)
                    IDs{end+1}=dataGroups(p).data(d).ID;
                end
            end
            IDs=unique(IDs);
            nPanels=length(panels);
            for i=1:length(IDs)
                for p=1:length(dataGroups)
                    for d=1:length(dataGroups(i).data)
                        if strcmp(dataGroups(p).data(d).ID,IDs{i})
                            if length(panels)<nPanels+i
                                panels(nPanels+i).data=dataGroups(p).data(d);
                            else
                                panels(nPanels+i).data(end+1)=dataGroups(p).data(d);
                            end
                        end
                    end
                end
            end
            delete(dlg);
            return
        end
        
        %consolidate all data in a single panel     
        for i=2:length(dataGroups)
            for k=1:length(dataGroups(i).data)
                dataGroups(1).data(end+1)=dataGroups(i).data(k);
            end
        end
        dataGroups(2:end)=[];
        
        if strcmp(dispMode,' Together in a new panel')
            panels(end+1).data=dataGroups(1).data;
            delete(dlg);
            return
        end
        if strcmp(dispMode,' As overlay in current panel')
            for k=1:length(dataGroups(1).data)
                panels(currentPanel).data(end+1).type=dataGroups(1).data(k).type;
                panels(currentPanel).data(end).variable=dataGroups(1).data(k).variable;
                panels(currentPanel).data(end).source=dataGroups(1).data(k).source;
                panels(currentPanel).data(end).ID=dataGroups(1).data(k).ID; 
            end
        end
        if strcmp(dispMode,' As overlay in all panels')
            for i=1:length(panels)
                for k=1:length(dataGroups(1).data)
                    panels(i).data(end+1).type=dataGroups(1).data(k).type;
                    panels(i).data(end).variable=dataGroups(1).data(k).variable;
                    panels(i).data(end).source=dataGroups(1).data(k).source;
                    panels(i).data(end).ID=dataGroups(1).data(k).ID; 
                end
            end
        end
        delete(dlg);
    end
    %################# CONTROL OF GPS SOURCES CHECK BOXES #################
    function setGpsSource(source,eventdata,gpsSource)
        % funtion that sets the names of the selected GPS data sources in the
        % gpsSources cell array
        if ~any(strcmp(gpsSources,gpsSource)) && get(source,'Value')
            gpsSources{end+1}=gpsSource;
        end
        if any(strcmp(gpsSources,gpsSource)) && ~get(source,'Value')
            if length(gpsSources)>=2
                gpsSources(find(strcmp(gpsSources,gpsSource)))=[];
            else
                set(source,'Value',1);
            end
        end
    end
    %################ CONTROL OF GPS VARIABLES CHECK BOXES ################
    function setGpsVariable(source,eventdata,gpsVariable)
        % funtion that sets the names of the selected GPS variables in the
        % gpsVariables cell array
        if ~any(strcmp(gpsVariables,gpsVariable)) && get(source,'Value')
            gpsVariables{end+1}=gpsVariable;
        end
        if any(strcmp(gpsVariables,gpsVariable)) && ~get(source,'Value')
            if length(gpsVariables)>=2
                gpsVariables(find(strcmp(gpsVariables,gpsVariable)))=[];
            else
                set(source,'Value',1);
            end
        end
    end
    %############## CONTROL OF TRANSDUCER VARIABLES CHECK BOXES ###########
    function setTransducerVariable(source,eventdata,transducerVariable)
        % funtion that sets the names of the selected transducers variables in the
        % transducerVariables cell array
        if ~any(strcmp(transducerVariables,transducerVariable)) && get(source,'Value')
            transducerVariables{end+1}=transducerVariable;
        end
        if any(strcmp(transducerVariables,transducerVariable)) && ~get(source,'Value')
            if length(transducerVariables)>=2
                transducerVariables(find(strcmp(transducerVariables,transducerVariable)))=[];
            else
                set(source,'Value',1);
            end
        end
    end
    %######### UPDATING LIST TO SHOW DATA AVAILABLE IN timeWindow #########
    function listDataInTimeWindow(source,eventdata)
        get(source,'Value')
        if get(source,'Value')==1
            % GRIDS --------------
            nGrids=length(grids);
            inWinIdx=false(nGrids,1);
            for j=1:nGrids
                inWinIdx(j)=isInWindow(timeWindow, metadata.grids.(grids{j}).tLims);
            end
            set(gridsList,'String',grids(inWinIdx));
            % ----------- SENSORS --------------------
            nSensors=length(sensors);
            inWinIdx=false(nSensors,1);
            for j=1:nSensors
                inWinIdx(j)=isInWindow(timeWindow, metadata.sensors.(['S' sensors{j}]).tLims);
            end
            set(sensorList,'String',sensors(inWinIdx));
            % ----------- GPS --------------------
            nGPS=length(gpss);
            inWinIdx=false(nGPS,1);
            for j=1:nGPS
                for k=1:length(const.gps.sources)
                inWinIdx(j)=any([inWinIdx(j) isInWindow(timeWindow, metadata.gps.(gpss{j}).(const.gps.sources{k}).tLims)]);
                end
            end
            set(gpsList,'String',gpss(inWinIdx));
            % ----------- meteo --------------------
            nMeteos=length(meteos);
            inWinIdx=false(nMeteos,1);
            for j=1:nMeteos
                meteoID=lower(meteos{j}(1:4));
                inWinIdx(j)=isInWindow(timeWindow, metadata.meteo.(meteoID).tLims);
            end
            set(meteoList,'String',meteos(inWinIdx));
        else
            set(gridsList,'String',grids);
            set(sensorList,'String',sensors);
            set(gpsList,'String',gpss);
            set(meteoList,'String',meteos);
        end
    end

    function switchToMap(source, eventdata)
        delete(dlg);
        displayMap([],[],'create');
    end

end
%##########################################################################
%############################ SUB FUNCTIONS ###############################
%##########################################################################
function selcbk(source,eventdata,listContainer)
    list=get(listContainer,'String');
    switch get(eventdata.NewValue,'String')
        case 'Row'
            disp('Sorting by row')
            set(listContainer,'String',sort(list));
        case 'Column'
            disp('Sorting by colum')
            columnList={};
            for i=1:length(list)
                columnList{i}=list{i}(find(list{i}=='C'):end);
            end
            [~,order]=sort(columnList);
            set(listContainer,'String',list(order));
    end
end

function v=isInWindow(win, range)
    % check if the range of values defined by range, overlaps with the values en win
    % win and range are two element vectors with min and max values (in that order)
    cases=[];
    % we chech the cases for which there is NO overlap
    %case range is out to the right of win
    cases(1)=all(range>win(2));
    %case range is out to the left of win
    cases(2)=all(range<win(1));
    
    % v is zero is any of the cases is true
    v=~any(cases);
end


