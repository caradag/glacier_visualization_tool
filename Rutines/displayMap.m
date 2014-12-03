function displayMap(source, eventdata, option)
    global panels fHandles metadata const displayStatus data
    global instruments % STRUCTURE TO HOLD THE INFORMATION OF ALL THE INSTRUMENTS DISPLAYED IN THE MAP
    persistent baseInstruments
    
    if nargin<3
        option='none';
    end
    % We exit if the option is not 'create' and the map doesn't already exist
    if ~strcmp(option,'create') && (~isfield(fHandles,'mapFigure') || (isfield(fHandles,'mapFigure') && ~ishandle(fHandles.mapFigure)))
        return
    end
    % CREATING STYLES FOR PLOT
    styles=struct;
    styles.boreholes.marker='o';
    styles.boreholes.color='g';
    styles.boreholes.size=6;
    styles.gps.marker='o';
    styles.gps.color='b';
    styles.gps.size=10;
    styles.selectedColor='r';
    styles.unselectedColor='w';
    styles.preselectedColor='y';

    % CREATING A BASE LIST TO HOLD THE INFORMATION OF ALL THE INSTRUMENTS
    % TO BE DISPLAYED ON THE MAP
    if isempty(baseInstruments)
        baseInstruments=createInstrumentsStructure();
    end
    
    % CREATING THE MAP FIGURE IF NEEDED
    % IT RETURN THE INSTRUMENTS ARRAY FILLED WITH THE GRAPHIC AND MENU HANDLES
    % FOR EACH INSTRUMENT ON THE PLOT
    if ~isfield(fHandles,'mapFigure') || ~ishandle(fHandles.mapFigure)
        instruments=createMap(baseInstruments,styles);
    end
    
    % reseting instruments status (if is or not in panels) and selected
    instruments= resetInstrumentsStructure(instruments);
    
    % reseting status (if is or not in panels) and selected
    % UPDATING INSTRUMENTS STRUCTURE, THIS IS:
    %   WHICH ONES ARE CURRENTLY ON THE PANELS
    %   WHICH ONE IS SELECTED IF ANY
    for p=1:length(panels)
        for d=1:length(panels(p).data)
            type=panels(p).data(d).type;
            switch type
                case 'gps'
                    ID=panels(p).data(d).ID;
                case 'sensors'
                    type='boreholes';
                    ID=['H' data.(panels(p).data(d).ID).metadata.hole{1}{1}];
            end
            instruments.(type).(ID).status=true;
            instruments.(type).(ID).panel=p;
            instruments.(type).(ID).idx=d;
            instruments.(type).(ID).selected=panels(p).data(d).selected | instruments.(type).(ID).selected;
            instruments.(type).(ID).preSelect=false;
        end
    end    
    
    
    % UPDATING PLOTTING STYLES AND MENUES
    for i=1:length(const.locationsTypes)
        type=const.locationsTypes{i};
        list=fieldnames(instruments.(type));
        for j=1:length(list)
            ID=list{j};       
            % If the instrument is already being plotted
            if instruments.(type).(ID).status
                switch type
                    case 'boreholes'
                        nSensors=length(instruments.(type).(ID).sensorIDs);
                        if nSensors>1
                            for sn=1:nSensors
                                set(instruments.(type).(ID).menu(sn), 'Label', ['Remove transducer ' instruments.(type).(ID).sensorIDs{sn}(2:end) ' (' ID(2:end) ') from all panels'],'Callback', {@removeData,'sensors',instruments.(type).(ID).sensorIDs{sn},type,ID});
                            end
                            set(instruments.(type).(ID).menu(sn+1), 'Label', ['Remove all sensors in ' ID(2:end) ' from all panels'],'Callback', {@removeData,'sensors',instruments.(type).(ID).sensorIDs,type,ID});
                            set(instruments.(type).(ID).menu(sn+2), 'Visible', 'off');
                        else
                            set(instruments.(type).(ID).menu, 'Label', ['Remove transducer ' instruments.(type).(ID).sensorIDs{1}(2:end) ' (' ID(2:end) ') from all panels'],'Callback', {@removeData,'sensors',instruments.(type).(ID).sensorIDs{1},type,ID});
                        end
                    case 'gps'
                        set(instruments.(type).(ID).menu, 'Label', ['Remove GPS data for ' ID ' from all panels'],'Callback', {@removeData,type,ID,type,ID});
                end
                % Changing the simbol to a star for the selected instrument
                if instruments.(type).(ID).selected
                    set(instruments.(type).(ID).handle,'Marker','*','MarkerFaceColor',styles.selectedColor,'MarkerEdgeColor',styles.selectedColor,'MarkerSize',styles.(type).size*2,'ButtonDownFcn',{@addPanel,type,ID,'togleSelect'});
                else
                    set(instruments.(type).(ID).handle,'Marker',styles.(type).marker,'MarkerFaceColor',styles.selectedColor,'MarkerEdgeColor',styles.(type).color,'MarkerSize',styles.(type).size,'ButtonDownFcn',{@addPanel,type,ID,'togleSelect'});
                end
                uistack(instruments.(type).(ID).handle,'top');
            else
                if instruments.(type).(ID).preSelect
                    faceColor=styles.preselectedColor;
                else
                    faceColor=styles.unselectedColor;
                end
                
                switch type
                    case 'boreholes'
                        nSensors=length(instruments.(type).(ID).sensorIDs);
                        if nSensors>1
                            for sn=1:nSensors
                                set(instruments.(type).(ID).menu(sn), 'Label', ['Add transducer #' num2str(sn) ': ' instruments.(type).(ID).sensorIDs{sn}(2:end) ' at ' ID(2:end) ' (' metadata.(type).(ID).grid ')'],'Callback', {@addPanel,'sensor',instruments.(type).(ID).sensorIDs{sn},'add'});
                            end
                            set(instruments.(type).(ID).menu(nSensors+1), 'Label', 'Add all in individual panels','Callback', {@addPanel,'boreholes',ID,'add'});
                            set(instruments.(type).(ID).menu(nSensors+2), 'Label', 'Add all in one panel','Callback', {@addPanel,'boreholes',ID,'addInOne'}, 'Visible', 'on');
                        else
                            set(instruments.(type).(ID).menu, 'Label', ['Add transducer ' instruments.(type).(ID).sensorIDs{1}(2:end) ' at ' ID(2:end) ' (' metadata.(type).(ID).grid ')'],'Callback', {@addPanel,'boreholes',ID,'add'});
                        end
                    case 'gps'
                        set(instruments.(type).(ID).menu, 'Label', ['Add GPS ' ID],'Callback', {@addPanel,type,ID,'add'});
                end
                set(instruments.(type).(ID).handle,'MarkerFaceColor',faceColor,'Marker',styles.(type).marker,'MarkerEdgeColor',styles.(type).color,'MarkerSize',styles.(type).size,'ButtonDownFcn',{@addPanel,type,ID,'preSelect'});
            end                
            % Showing/Hiding boreholes according to year selection and current selected flags
            if strcmp(type,'boreholes')
                [sensorYear,~,~]=datevec(metadata.(type).(ID).tLims(1));
                if any(sensorYear==displayStatus.mapYears) && any(metadata.(type).(ID).flags & displayStatus.sensorFlags)
                    set(instruments.(type).(ID).handle,'Visible','on');
                else
                    set(instruments.(type).(ID).handle,'Visible','off');
                end
            end
            
        end
    end    
end

function addPanel(source,eventdata,type,ID,option)
    global panels fHandles const instruments metadata
    if nargin<5
        option='none';
    end
    switch option
        case {'add','addInOne'}
            if ~isempty(type) && ~isempty(ID) && ~strcmp(type,'sensor')
                instruments.(type).(ID).preSelect=true;
            end
            doUpdatePlot=false;
            % we iterate for each instrument type (boreholes or gps)
            for i=1:length(const.locationsTypes)
                locationType=const.locationsTypes{i};
                % first we look for all the preselected instruments of the current type
                IDs={};
                list=fieldnames(instruments.(locationType));
                for j=1:length(list)
                    ID=list{j};
                    if instruments.(locationType).(ID).preSelect;
                        switch locationType
                            case {'gps','sensor'}
                                IDs{end+1}=ID;
                            case 'boreholes'
                                IDs=[IDs, instruments.(locationType).(ID).sensorIDs];
                        end
                    end
                end                
                if isempty(IDs)
                    continue;
                end
                
                switch locationType
                    case 'gps'
                        sensorType='gps';
                    case {'boreholes','sensor'}
                        sensorType='sensors';
                end
                
                % displaing dialog box yo get variables
               [selectedVariable, ok] = listdlg('ListString',const.(sensorType).variables.description,'SelectionMode','single','Name',['Select ' sensorType ' variable to plot'],'PromptString','Select variable:');
                % if user didn't ok or selection is empty we abort
                if ~ok && isempty(selectedVariable)
                    return;
                end
                % displaing dialog box to get source, but only if there is more than one choice
                if length(const.(sensorType).sources)>1
                    [selectedSource, ok] = listdlg('ListString',const.(sensorType).sources,'SelectionMode','single','Name',['Select ' sensorType ' data source'],'PromptString','Select source:');
                    if ~ok && isempty(selectedSource)
                        return;
                    end
                else
                    selectedSource=1;
                end

                % we now add the instruments in a new panel
                p=length(panels)+1;
                d=1;
                for idIdx=1:length(IDs)
                    panels(p).data(d).ID=IDs{idIdx};
                    panels(p).data(d).type=sensorType;
                    panels(p).data(d).source=const.(sensorType).sources{selectedSource};
                    panels(p).data(d).variable=const.(sensorType).variables.ID{selectedVariable};
                    panels(p).data(d).selected=0;
                    instruments.(locationType).(ID).preSelect=false;
                    switch option
                        case 'add'
                            p=p+1;
                        case 'addInOne'
                            d=d+1;
                    end
                end
                doUpdatePlot=true;
            end
            if doUpdatePlot
                updatePlot();
            end
            
        case 'togleSelect'
            clickType=get(fHandles.mapFigure,'SelectionType');
            if strcmp(clickType,'normal')
                panel=instruments.(type).(ID).panel;
                idx=instruments.(type).(ID).idx;
                selectedSensor([],[],[panel idx]);
            end
        case 'preSelect'
            clickType=get(fHandles.mapFigure,'SelectionType');
            if strcmp(clickType,'normal')
                % If the sensor is not being displayed, we toggle the preSelected status
                if instruments.(type).(ID).status
                    instruments.(type).(ID).preSelect=false;
                else
                    instruments.(type).(ID).preSelect=~instruments.(type).(ID).preSelect;
                end
            end
        otherwise
            return;
    end
    displayMap();
end

function removeData(source,eventdata,type,ID,instrumentType,instrumentID)
    global panels instruments
    instruments.(instrumentType).(instrumentID).preSelect=false;
    for p=length(panels):-1:1
        for d=length(panels(p).data):-1:1
            if strcmp(panels(p).data(d).type,type) && any(strcmp(panels(p).data(d).ID,ID))
                swapPanels([],[],[p d],[]);
            end
        end
    end
    updatePlot();
    displayMap();
end

function instruments=createMap(instruments, styles)
% create the map axes and load the background figure
    global fHandles metadata const displayStatus panels
    
    imageFile=[const.refImagesFolder const.mapImage];
    mapW=800;
    mapH=600;
    baseImage=imread(imageFile);
    fHandles.mapFigure=figure('Name','Map overview','NumberTitle','off','Position',[2 60 mapW mapH],'ResizeFcn','','KeyPressFcn','');

    %reading reoreferenciation data
    [pathstr, name, ~] = fileparts(imageFile);
    [imageH imageW ~]=size(baseImage);
    tfw=load([pathstr '/' name '.tfw']);
    maxN=tfw(6);
    minN=maxN+tfw(4)*(imageH-1);
    minE=tfw(5);
    maxE=minE+tfw(1)*(imageW-1);
    
    mapAxes=axes();
    image([minE maxE],[maxN minN],baseImage);
    set(mapAxes,'DataAspectRatio',[1 1 1],'YDir','normal');
    set(mapAxes,'XTick',[],'YTick',[],'Units','pixels');
    % Now we calculate the width to get the map as tall as the figure
    aspectRatio=imageH/imageW;
    W=mapH*aspectRatio;
    pos=[0 0 W mapH];    
    set(mapAxes,'Position',pos);
    
    
    hold on

    % plotting grid locations convex hulls
    list=fieldnames(metadata.grids);
    for j=1:length(list)
        ID=list{j};
        cHull=metadata.grids.(ID).convexHull;
        if ~isempty(cHull)
            plot(cHull(:,1),cHull(:,2),'k'); 
        end
    end
    
    for i=1:length(const.locationsTypes)
        type=const.locationsTypes{i};
        list=fieldnames(metadata.(type));
        for j=1:length(list)
            ID=list{j};
            [x y]=dealOneByOne(instruments.(type).(ID).pos);
            switch type
                case 'gps'
                    nMenues=1;
                case 'boreholes'
                    nMenues=length(instruments.(type).(ID).sensorIDs);
                    if nMenues>1
                        nMenues=nMenues+2;
                    end
            end
            instruments.(type).(ID).menu=nan(1,nMenues);
            instMenu= uicontextmenu;
            for sn=1:nMenues
                instruments.(type).(ID).menu(sn) = uimenu(instMenu, 'Label', 'empty');            
            end
            instruments.(type).(ID).handle=plot(x,y,'Color',styles.(type).color,'Marker',styles.(type).marker,'MarkerSize',styles.(type).size,'UIContextMenu', instMenu); 
        end
    end
    
    % Creating controls
    controlW=160;
    baseX=pos(1)+pos(3)+10;

    Y=25;
    uicontrol(fHandles.mapFigure,'Style', 'pushbutton','String','Remove all','Position', [baseX, Y, controlW, 20],'Callback',{@removeAll});
    Y=Y+25;
    uicontrol(fHandles.mapFigure,'Style', 'pushbutton','String','Add in individual panels','Position', [baseX, Y, controlW, 20],'Callback',{@addPanel,[],[],'add'});
    Y=Y+25;
    uicontrol(fHandles.mapFigure,'Style', 'pushbutton','String','Add in one panel','Position', [baseX, Y, controlW, 20],'Callback',{@addPanel,[],[],'addInOne'});
    Y=Y+25;
    uicontrol(fHandles.mapFigure,'Style', 'pushbutton','String','Invert selection','Position', [baseX, Y, controlW, 20],'Callback',{@invertSelection});
    
    [currentYear,~,~]=datevec(now);
    years=2008:currentYear;
    nYears=length(years);
    h=25+22*nYears;
    Y=Y+25;
    yearsGroup=uibuttongroup('Units','pixels','Position', [baseX Y controlW h]);iY=h-25;
    uicontrol(fHandles.mapFigure,'Style', 'text','String','Years','Position', [2 iY controlW-4 20],'parent',yearsGroup,'FontSize',12);iY=iY-20;
    yearsHandles=struct;
    for y=years
        yearsHandles.(['Y' num2str(y)])=uicontrol(fHandles.mapFigure,'Style', 'checkbox','String',num2str(y),'Position', [2 iY controlW-4 20],'parent',yearsGroup,'Min',0,'Max',1,'Value',1,'Callback',{@setYears,y});iY=iY-22;
    end
    set(yearsGroup,'Visible','on');  
    displayStatus.mapYears=years;
    function setYears(source, eventdata, year)
        if get(source,'Value')
            displayStatus.mapYears(end+1)=year;
            displayStatus.mapYears=unique(displayStatus.mapYears);
        else
            displayStatus.mapYears(displayStatus.mapYears==year)=[];
        end
        displayMap();
    end
    function invertSelection(source, eventdata)
        for y=years
            if any(displayStatus.mapYears==y)
                displayStatus.mapYears(displayStatus.mapYears==y)=[];
                set(yearsHandles.(['Y' num2str(y)]),'Value',0);
            else
                displayStatus.mapYears(end+1)=y;
                set(yearsHandles.(['Y' num2str(y)]),'Value',1);
            end
        end
        displayStatus.mapYears=unique(displayStatus.mapYears);    
        displayMap();
    end        
    function removeAll(source, eventdata)
        panels=[];
        displayMap();
    end

end

function instruments= createInstrumentsStructure()
    global metadata const
    instruments=[];
    % Creating a structure with one entry for each sensor and gps as in metadata
    for i=1:length(const.locationsTypes)
        type=const.locationsTypes{i};
        list=fieldnames(metadata.(type));
        for j=1:length(list)
            ID=list{j};
            instruments.(type).(ID).status=false;
            instruments.(type).(ID).selected=false;
            instruments.(type).(ID).panel=[];
            instruments.(type).(ID).idx=[];
            instruments.(type).(ID).preSelect=false;
            switch type
                case 'boreholes'
                    instruments.(type).(ID).pos=metadata.(type).(ID).pos;
                    instruments.(type).(ID).sensorIDs=metadata.(type).(ID).sensors;
                case 'gps'
                    instruments.(type).(ID).pos=metadata.(type).(ID).Relative.pos;
            end            
        end
    end
end

function instruments= resetInstrumentsStructure(instruments)
    global const
    locationsTypes=const.locationsTypes;
    % reseting status (if is or not in panels) and selected
    for i=1:length(locationsTypes)
        type=locationsTypes{i};
        list=fieldnames(instruments.(type));
        for j=1:length(list)
            ID=list{j};
            instruments.(type).(ID).status=false;
            instruments.(type).(ID).selected=false;
        end
    end
end
