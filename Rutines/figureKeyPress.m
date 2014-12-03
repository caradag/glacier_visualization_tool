function figureKeyPress(source,eventdata,panel,d,overrideCurrentKey)
    global fHandles displayStatus panels
    if nargin<3
        panel=[];
    end
    if nargin<4
        d=[];
    end
    if nargin >= 5
        currentKey=overrideCurrentKey;
        source=fHandles.browsefig;
    else
        currentKey=get(fHandles.browsefig,'CurrentCharacter');
    end
    clickType=get(fHandles.browsefig,'SelectionType');
    currentCursor=get(fHandles.axis,'CurrentPoint');
    switch get(source,'Parent')
%##########################################################################
%######### MANAGING CALLS FROM MAIN FIGURE, BUTTONS AND UICONTROLS ########
%##########################################################################
        case {fHandles.browsefig,0}
            switch currentKey
                case {'R','r'} % Remove all panels
                    panels=[];
                    updatePlot();
                case 'n'
                    browseTroughData([],[],1);
                case 'p'
                    browseTroughData([],[],-1);
                case 'b'
                    historyGoBack;
                case 'f'
                    historyGoForward;
                case 'm'
                    displayMap([],[],'create');
                case 'o' % zoom out to full range
                    updatePos('figureKeyPress',[],displayStatus.tRange);
                     updatePlot();
                case 'M' % zoom to a month around center of current view
                    updatePos('figureKeyPress',[],[-16 16]+mean(displayStatus.tLims));
                    updatePlot();
                case 'W' % zoom out to full range
                    updatePos('figureKeyPress',[],[-4 4]+mean(displayStatus.tLims));
                    updatePlot();
                case 'D' % zoom out to full range
                    updatePos('figureKeyPress',[],[-0.6 0.6]+mean(displayStatus.tLims));
                    updatePlot();
                case 'z' % zoom in to timeSel
                    updatePos('figureKeyPress',[],displayStatus.timeSel(:,1));
                case 'a' % Open add data dialog box
                    addData();
                case 'k' % Toggle between line plot or marker plot for selected line
                    [panel idx] = selectedSensor();
                    if strcmp(panels(panel).data(idx).style,'-   none')
                        changeDataField( [],[],[panel idx],'style','none.   ');
                    else
                        changeDataField( [],[],[panel idx],'style','-   none');
                    end                    
                otherwise
                    disp(currentKey);
            end
%##########################################################################
%############## MANAGING CALLS GRAPHIC OBJECS IN THE DATA AXIS ############
%##########################################################################
        case fHandles.axis
            % ###### Capture clicks to set time limits ######
            switch clickType
                case 'normal'
                    plotTimeSel(currentCursor(1,1:2),'replaceOther');
                case 'alt'
                    %plotTimeSel(currentCursor(1,1:2),'replaceNearest');
            end
            % if the source is a data serie line, we display cursor information
            if strcmp(get(source,'Tag'),'Data serie')
                cursorInfo=getCursorInfo(panel,d,currentCursor(1,1:2));
                set(fHandles.cursorInfo,'String',cursorInfo);
                selectedSensor(source,eventdata,[panel d]);
            end            
    end
end

function cursorInfo=getCursorInfo(panel,d,xy)
    global data panels metadata const
    d=d(1);
    cTime=xy(1);
    normVal=xy(2)-panel+1;
    yVal=panels(panel).data(d).norm2y(normVal);
    ID=panels(panel).data(d).ID;
    variable=panels(panel).data(d).variable;
    Variable=[upper(variable(1)) variable(2:end)];

    axisID=panels(panel).data(d).axisID;
    unit=const.axisUnits{strcmp(const.axisIDs,axisID)};

    wComments='';
    closestGPS='';        
    if strcmp(panels(panel).data(d).type,'sensors')
        if isfield(data.(ID),'comments') && ~isempty(data.(ID).comments)
            wComments=' SENSOR WITH COMMENTS ';
        end
        %looking for nearest GPS with data
        closestGPS='None';
        minDist=Inf;
        gpsIDS=fieldnames(metadata.gps);
        for i=1:length(gpsIDS)
            % Checking current GPS has data in sensr time window
            sensorWin=metadata.sensors.(ID).tLims;
            gpsWin=metadata.gps.(gpsIDS{i}).Relative.tLims;
            if isempty(gpsWin)
                disp(['WARNING: empty time limits for GPS ' gpsIDS{i} '/Relative']);
                continue
            end
            if isempty(sensorWin)
                disp(['WARNING: empty time limits for sensor ' ID]);
                continue
            end
            cases=[];
            % we chech the cases for which there is NO overlap this is
            %the cases when one range is out to the right or the left of
            % the other
            if all(gpsWin>sensorWin(2)) || all(gpsWin<sensorWin(1))
                continue;
            end
            gpsXY=metadata.gps.(gpsIDS{i}).Relative.pos;
            sensorXY=metadata.sensors.(ID).pos;
            dist=sqrt(sum((gpsXY-sensorXY).^2));
            if dist < minDist
                closestGPS=[' Closest GPS: ' gpsIDS{i} ' (' sprintf('%.0f',minDist) ' m) '];
                minDist=dist;
            end
        end
    end
    cursorInfo=['Sensor: ' ID(2:end) '  Time: ' datestr(cTime) '  ' Variable ': ' sprintf('%.1f',yVal) ' ' unit '  ' closestGPS wComments];
end
    