function changeDataField(source,eventdata,idx,field,value)
global panels const displayStatus
%Change the color or style of a data serie
if nargin<5
    value='';
end
switch field
    case 'color'
        % changing line color of a data serie
        newColor=uisetcolor('Pick new color for the data serie');
        if ~isempty(newColor)
            panels(idx(1)).data(idx(2)).color=newColor;
            nHandles=length(panels(idx(1)).data(idx(2)).lineHandle);
            for i=1:nHandles
                if ishandle(panels(idx(1)).data(idx(2)).lineHandle(i))
                    set(panels(idx(1)).data(idx(2)).lineHandle(i),'Color',newColor);
                end
            end
        end
        disp(['New color selected: [' num2str(newColor) ']']);
        saveHistory();
    case 'style'
        %available styles and descriptions
        styles={'-   none','--  none',':   none','-   x   ','--  x   ',':   x   ','nonex   ','none*   ','none+   '};
        stylesTexts={'Solid','Dashed','Dotted','Solid and markers (x)','Dashed and markers (x)','Dotted and markers (x)','Only markers x x x','Only markers * * *','Only markers + + +'};

        % first get current style
        if isfield(panels(idx(1)).data(idx(2)),'style')
            prevStyle=panels(idx(1)).data(idx(2)).style;
        else
            prevStyle='-';
        end
        if isempty(value)
            % create an logical array seting the selected items in the dialog box
            selectedStyle=find(strcmp(prevStyle,styles),1);
            % displaing dialog box
            [selectedStyle,ok] = listdlg('ListString',stylesTexts,'SelectionMode','single','InitialValue',selectedStyle,'Name','Select data serie line style','PromptString','Select style:');
            % if user press ok we proceed to check values
        else
            selectedStyle=1;
            styles={value};
            ok=true;
        end
        if ok && ~isempty(selectedStyle)
            % changing line style of a data serie
            newStyle=styles{selectedStyle};
            panels(idx(1)).data(idx(2)).style=newStyle;
            nLines=length(panels(idx(1)).data(idx(2)).lineHandle);
            for line=1:nLines
                if ishandle(panels(idx(1)).data(idx(2)).lineHandle(line))
                    set(panels(idx(1)).data(idx(2)).lineHandle(line),'LineStyle',newStyle(1:4));
                    set(panels(idx(1)).data(idx(2)).lineHandle(line),'Marker',newStyle(5:8));
                end
            end
        end
        saveHistory();
    case 'normalization' % re define the normalization function to change the vertiacal limits of a data serie
        % first get current value for the normalization mode
        prevMode=panels(idx(1)).data(idx(2)).normMode{1};
        if isempty(value)
            % create an logical array seting the selected items in the dialog box
            selectedMode=find(strcmp(prevMode,const.normModes),1);
            % displaing dialog box
            [selectedMode,ok] = listdlg('ListString',const.normModesTexts,'SelectionMode','single','InitialValue',selectedMode,'Name','Select Y axis limits mode','PromptString','Select mode:','ListSize',[300 150]);
        else
            selectedMode=find(strcmp(value,const.normModes),1);
            if isempty(selectedMode)
                disp('Nomalization mode not known');
                return
            end                
            ok=true;
        end
        if any(strcmp(const.normModes{selectedMode},{'waterColumn','waterColumnOrMax'})) && ~strcmp(panels(idx(1)).data(idx(2)).type,'sensors')
            disp('Selected nomalization mode is valid only for pressure sensors');
            return
        end
            
        % if user press ok we proceed to check values
        if ok && ~isempty(selectedMode)
            selectedMode=const.normModes{selectedMode};
            % If selected mode is different than the previous one change it
            if ~strcmp(selectedMode,prevMode) || any(strcmp(selectedMode,{'manual','window'}))
                selectedMode={selectedMode};
                switch selectedMode{1}
                    case 'manual'
                        currentLims=panels(idx(1)).data(idx(2)).norm2y([0 1]);
                        axisID=panels(idx(1)).data(idx(2)).axisID;
                        unit=const.axisUnits{strcmp(const.axisIDs,axisID)};
                        manualLims = inputdlg({['Minimum value (' unit '): '],['Maximum value (' unit '): ']},'Enter new Y axis limits',1,{num2str(currentLims(1)), num2str(currentLims(2))});
                        if isempty(manualLims)
                            return
                        end
                        manualLims=[str2double(manualLims{1}), str2double(manualLims{2})];
                        if numel(manualLims)~=2
                            disp('Invalid values');
                            return
                        end
                        selectedMode{2}=[min(manualLims) max(manualLims)];
                    case 'cursor'
                        normMin=min(displayStatus.timeSel(:,2)-idx(1)+1);
                        normMax=max(displayStatus.timeSel(:,2)-idx(1)+1);
                        selectedMode{2}=panels(idx(1)).data(idx(2)).norm2y([normMin normMax]);
                end
                
                panels(idx(1)).data(idx(2)).normMode=selectedMode;
                panels(idx(1)).data(idx(2)).yData=[];
                populatePanels();
                updatePlot();
            end
        end 
    case 'verticalLimitsToAll'
        normMode=panels(idx(1)).data(idx(2)).normMode;
        for p=1:length(panels)
            for d=1:length(panels(p).data)
                currentNormMode=panels(p).data(d).normMode;
                if (p~=idx(1) || d~=idx(2)) && (~isequal(currentNormMode,normMode) || any(strcmp(normMode,{'manual','window'})))
                    panels(p).data(d).normMode=normMode;
                    panels(p).data(d).yData=[];
                end
            end
        end
        populatePanels();
        updatePlot();
    case 'filter'
        if isfield(panels(idx(1)).data(idx(2)),'filter')
            prevMode=panels(idx(1)).data(idx(2)).filter;
        else
        end
        filterModes={'none','median2sigma','median5sigma'};
        filterModesTexts={'None','Discard points 2 sigma away from running median','Discard points 5 sigma away from running median'};
        selectedMode=strcmp(prevMode,filterModes);
        if ~any(selectedMode)
            selectedMode(1)=1;
        end
        [selectedMode,ok] = listdlg('ListString',filterModesTexts,'SelectionMode','single','InitialValue',selectedMode,'Name','Select outlier filter mode','PromptString','Select mode:');
        selectedMode=filterModes{selectedMode};
        if ok && ~strcmp(selectedMode,prevMode)
            panels(idx(1)).data(idx(2)).filter=filterModes{selectedMode};
            panels(idx(1)).data(idx(2)).yData=[];
            populatePanels();
            updatePlot();
        end 
    otherwise
        return;
end
end

