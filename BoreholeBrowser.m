function BoreholeBrowser()
    global data gps sMelt ambientTemp gridList metadata panels fHandles displayStatus const

    const=loadConfiguration();
    % defining path to rutines
    path(path,const.routinesFolder);
    %path(path,'/home/camilo/5_UBC/GPS_processing/02_Solution data manipulation (Lucas, SCOUT, PPP, Relative)/Relative/');
    % browser window size
    W=1020;
    H=668;

    % initialize global variables
    displayStatus=struct('timeSel',[]);
    displayStatus.showDeleted=false;
    displayStatus.sensorFlags=const.sensorFlagsDefault;
    displayStatus.dataMasks=const.dataMasksDefault;
    [currentYear,~,~]=datevec(now);
    displayStatus.mapYears=2008:currentYear;
    fHandles=struct;

    % ############# SET CONSTANTS ###################
    % set general constants
    const.psiPerPascal=0.000145037891;
    const.sensorPressureLimit=200/const.psiPerPascal;
    const.sensorPressureTolerance=400/const.psiPerPascal;

    %defining available axis units
    const.axisIDs=  {'press_kPa', 'press_mWaterEq' , 'press_PSI' , 'volt_V', 'temp_C', 'speed_cmPerDay', 'deviation_mm', 'melt_mmPerDay','ID','norm'};
    const.axisUnits={'kPa'      , 'm (w.depth eq.)', 'PSI', 'Volts'     , '°C'    , 'cm/day'        , 'mm'          , 'mm.w.eq/day','ID','Normalized'};
    for i=1:length(const.axisIDs)
        const.availableAxes.(const.axisIDs{i}).ticks=[];
        const.availableAxes.(const.axisIDs{i}).labels=[];
        const.availableAxes.(const.axisIDs{i}).unit=const.axisUnits{i};
    end    

    const.gps.sources={'Relative','PPP','Lucas','SCOUT'};
    const.gps.variables.ID={'speed','projSpeed','longitudinalDeviation','transversalDeviation','verticalDeviation'};
    const.gps.variables.description={'Speed','Projected speed','Longitudinal deviation','Transversal deviation','Vertical deviation'};
    
    const.sensors.sources={'final'};
    const.sensors.variables.ID={'pressure','temperature','battvolt'};
    const.sensors.variables.description={'Pressure','Logger temperature','Battery voltage'};
    
    const.locationsTypes={'boreholes','gps'};% Geographical points with associated data that should be ploted in the map
    
    const.maxMemorizedHistorySteps=20;
    % ############# LOADING DATA ###################
    loadData();

    % ############# creating main browser interface ###################
    disp('Creating main data browser figure');
    fHandles.browsefig=figure('Name','Field Data Browser','NumberTitle','off','Position',[2 60 W H],'ResizeFcn',@drawFigure,'KeyPressFcn',@figureKeyPress,'MenuBar','none');
    drawFigure();
    %set(fHandles.browsefig,'Name','Field Data Browser','NumberTitle','off','Position',[2 60 W H],'ResizeFcn',@drawFigure,'KeyPressFcn',@figureKeyPress,'MenuBar','none');
end
%##########################################################################
%################# DRAW FIGURE SUB FUNCTION ###############################
%##########################################################################
function drawFigure(source,eventdata)
    global fHandles const displayStatus
    if ~isfield(fHandles,'browsefig')
        %Newer version of matlab call the ResizeFn while the figure is
        %being created. With this we avoid trying to draw the figure before
        %the handle to it is assigned to fHandles.browsefig
        return;
    end
    [~, ~, w, H]=dealOneByOne(get(fHandles.browsefig,'Position'));
    clf(fHandles.browsefig);
    buttonW=80;
    leftMargin=45;
    vScrollW=16;
    %##################### DRAWING AXES AND SCROLLS #######################
    axesW=w-buttonW-leftMargin-13-vScrollW;
    fHandles.axis=axes('position',[leftMargin/w 50/H axesW/w (H-78)/H],'Box','on');
    yAxisListW=110;
    yAxisListLeftMargin=5;
    fHandles.yAxisList=uicontrol('Style', 'popupmenu','String',const.axisUnits,'Position', [yAxisListLeftMargin (H-78+50+11) yAxisListW 15],'Callback',@setYAxis);
    cursorInfoX=yAxisListLeftMargin+yAxisListW+5;
    cursorInfoW=axesW+leftMargin-yAxisListLeftMargin-yAxisListW+buttonW;
    fHandles.cursorInfo=uicontrol('Style', 'text','String','Sensor:       Time:                      Pressure:','Position', [cursorInfoX (H-78+50+5) cursorInfoW 20],'HorizontalAlignment','left','FontSize',13);

    fHandles.vScroll=uicontrol('Style', 'slider','Value',1,'Min',0,'Max',1,'Position', [(axesW+leftMargin+4) 50 vScrollW (H-78)],'Callback',@updatePos);
    fHandles.hScroll=uicontrol('Style', 'slider','Value',0.5,'Min',0,'Max',1,'SliderStep',[0 1],'Enable','off','Position', [40 10 (w-200) 15],'Callback',@updatePos);
    fHandles.timeShowAllButton=uicontrol('Style', 'pushbutton','String','All','Position',[45+(w-200) 10 34 15],'Callback',{@figureKeyPress,[],[],'o'});
    fHandles.timeShowAllButton=uicontrol('Style', 'pushbutton','String','Month','Position',[83+(w-200) 10 58 15],'Callback',{@figureKeyPress,[],[],'M'});
    fHandles.timeShowAllButton=uicontrol('Style', 'pushbutton','String','Week','Position',[145+(w-200) 10 45 15],'Callback',{@figureKeyPress,[],[],'W'});

    %######################## DRAWING CONTROLS ############################
    baseX=w-buttonW-5;
    
    nFlags=length(const.sensorFlags);
    h=25+22*nFlags;
    Y=H-h-25;
    flagsGroup=uibuttongroup('Units','pixels','Position', [baseX Y buttonW h]);iY=h-25;
    uicontrol(fHandles.browsefig,'Style', 'text','String','Flags','Position', [2 iY buttonW-4 20],'parent',flagsGroup,'FontSize',12);iY=iY-20;
    for f=1:nFlags
        uicontrol(fHandles.browsefig,'Style', 'checkbox','String',const.sensorFlags{f},'Position', [2 iY buttonW-4 20],'parent',flagsGroup,'Min',0,'Max',1,'Value',displayStatus.sensorFlags(f),'Callback',{@setSensorFlags,f});iY=iY-22;
    end
    set(flagsGroup,'Visible','on');

    nMasks=length(const.dataMasks);
    h=25+22*nMasks;
    Y=Y-h-5;
    masksGroup=uibuttongroup('Units','pixels','Position', [baseX Y buttonW h]);iY=h-25;
    uicontrol(fHandles.browsefig,'Style', 'text','String','Masks','Position', [2 iY buttonW-4 20],'parent',masksGroup,'FontSize',12);iY=iY-20;
    for f=1:nMasks
        uicontrol(fHandles.browsefig,'Style', 'checkbox','String',const.dataMasks{f},'Position', [2 iY buttonW-4 20],'parent',masksGroup,'Min',0,'Max',1,'Value',displayStatus.dataMasks(f),'Callback',{@setDataMasks,f});iY=iY-22;
    end
    set(masksGroup,'Visible','on');
    
    Y=Y-25;
    fHandles.deleteSelectedButton=uicontrol(fHandles.browsefig,'Style', 'pushbutton','String','Mask sel.','Position', [baseX Y buttonW 20],'Callback',{@doMask,'',true},'KeyPressFcn',@figureKeyPress);
    Y=Y-25;
    fHandles.deleteSelectedButton=uicontrol(fHandles.browsefig,'Style', 'pushbutton','String','Unmask sel.','Position', [baseX Y buttonW 20],'Callback',{@doMask,'',false},'KeyPressFcn',@figureKeyPress);

    Y=Y-25;
    uicontrol(fHandles.browsefig,'Style', 'text','String','Vert. scale','Position', [baseX Y buttonW 16]);
    Y=Y-25;
    fHandles.nPanelsOnScreen=uicontrol(fHandles.browsefig,'Style', 'slider','Value',1000,'Min',1,'Max',1000,'Position', [baseX Y buttonW 20],'Callback',@updatePos);
    Y=Y-25;
    fHandles.prevButton=uicontrol(fHandles.browsefig,'Style', 'pushbutton','String','<','Position', [baseX Y (buttonW/2-1) 20],'Callback',{@browseTroughData,-1});
    fHandles.nextButton=uicontrol(fHandles.browsefig,'Style', 'pushbutton','String','>','Position', [baseX+(buttonW/2)+2 Y (buttonW/2-1) 20],'Callback',{@browseTroughData,+1});
    Y=Y-25;
    fHandles.drawButton=uicontrol(fHandles.browsefig,'Style', 'pushbutton','String','Re-Draw','Position', [baseX, Y, buttonW, 20],'Callback',{@updatePlot,0,1},'KeyPressFcn',@figureKeyPress);
    Y=Y-25;
    fHandles.timeZoomButton=uicontrol(fHandles.browsefig,'Style', 'pushbutton','String','Zoom','Position', [baseX, Y, buttonW, 20],'Callback',@updatePos,'KeyPressFcn',@figureKeyPress);
    Y=Y-25;
    fHandles.backButton=uicontrol(fHandles.browsefig,'Style', 'pushbutton','String','Bck','Position', [baseX, Y, (buttonW/2-1), 20],'Callback',{@updatePlot,-1},'KeyPressFcn',@figureKeyPress);
    fHandles.forwardButton=uicontrol(fHandles.browsefig,'Style', 'pushbutton','String','Fwd','Position', [baseX+(buttonW/2)+2, Y, (buttonW/2-1), 20],'Callback',{@updatePlot,1},'KeyPressFcn',@figureKeyPress);

    %######################## CREATING MENUS ##################################
     dataMenu = uimenu('Label','Data');
     uimenu(dataMenu,'Label','Import new data...','Callback',{@reImportData});
     uimenu(dataMenu,'Label','Save updated data file...','Callback',{@saveData});
     uimenu(dataMenu,'Label','Export data file...','Callback',{@saveData,[],[],[]});
%     uimenu(importExportMenu,'Label','Export Borehole positions','Callback','generateSensorCoordList');

    graphMenu = uimenu('Label','Current graph');
    uimenu(graphMenu,'Label','Show/Hide deleted samples [d]','Callback',{@figureKeyPress,[],[],'d'});
    uimenu(graphMenu,'Label','Display map','Callback',{@displayMap,'create'});
%    uimenu(graphMenu,'Label','Distance between sensors...','Callback','ruler');
    uimenu(graphMenu,'Label','Save current graph...','Callback',{@saveRestoreCurrentView,'save'});
    uimenu(graphMenu,'Label','Load saved graph...','Callback',{@saveRestoreCurrentView,'load'});

    analisysMenu = uimenu('Label','Analisys');
    diurnalOscillationsMenu=uimenu(analisysMenu,'Label','Run diurnal oscilations power analisis');
    uimenu(diurnalOscillationsMenu,'Label','Run on current screen data','Callback',{@diurnalOscilationPower,[],'window'});
    uimenu(diurnalOscillationsMenu,'Label','Run on loadad data','Callback',{@diurnalOscilationPower,[],'all'});
    correlationMenu=uimenu(analisysMenu,'Label','Run cross correlation analisys');
    uimenu(correlationMenu,'Label','Run on current screen data','Callback','dailyForcingContent');
    uimenu(correlationMenu,'Label','Run on loadad data','Callback','dailyForcingContent');
    stepwiseRegressionMenu=uimenu(analisysMenu,'Label','Run stepwise regresion analisys');
    uimenu(stepwiseRegressionMenu,'Label','Run on current screen data','Callback','dailyForcingContent');
    uimenu(stepwiseRegressionMenu,'Label','Run on loadad data','Callback','dailyForcingContent');
    spectrumMenu=uimenu(analisysMenu,'Label','Show frequency spectrum');
    uimenu(spectrumMenu,'Label','Of selected time setries over current window','Callback',{@getSpectrum});
    

    %########################## PLOTING DATA ##################################
    updatePlot();
    function setSensorFlags(source,eventdata,idx)
        displayStatus.sensorFlags(idx)=get(source,'Value');
        displayMap();
        updatePlot();
    end
    function setDataMasks(source,eventdata,idx)
        displayStatus.dataMasks(idx)=get(source,'Value');
        displayMap();
        updatePlot([],[],0,1);
    end
end