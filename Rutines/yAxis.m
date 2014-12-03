function yAxis(panel,idx)
% Build the y axis and its labels which are stored in displayStatus.availableAxes
    global const panels displayStatus
    % If a line is specified, we update only the axes related to the line variable
    if nargin==2
        % If it is the only line in the panel using its axes there is nothing to do
        if isSingleAxis(panels(panel).data(idx).axisID,panel)
            return
        end
        axisNames={panels(panel).data(idx).axisID};
        if strcmp(axisNames{1},'press_kPa')
            axisNames(2:3)={'press_mWaterEq','press_PSI'};
        end
    else % If no line is specified, we build/re-build the all the axes
       axisNames=fieldnames(const.availableAxes);
    end
    
    % Reseting to default the axes that will be updated
    for k=1:length(axisNames)
        displayStatus.availableAxes.(axisNames{k})=const.availableAxes.(axisNames{k});
    end
    
    [selPanel selIdx] = selectedSensor();
    for i=1:length(panels)
        nDataFields=length(panels(i).data);
        %##################### AXIS LABELS AND TICKS ##########################
        %creating Y axis
        %for each of the axis field on panel's axisLims we check the limits and crate the axis values  
        for k=1:length(axisNames)
            if isfield(panels(i).axisLims,axisNames{k})
                axisLims=panels(i).axisLims.(axisNames{k});
                % If we have axis limits we proceed to add ticks and labels accordingly
                if ~isempty(axisLims) 
                    % If there is more than one line in the panel we check if they use the same axis (i.e. same units)
                    if ~ isSingleAxis(axisNames{k},i)
                        % If there is more than one line using the axis and they are not using the same normalization values 
                        % we modify axisLims to match the selected line in the panel

                        % BUT IF THERE IS NO SELECTED LINE OR IT IS NOT IN CURRENT PANEL
                        % We don't render ticks and labels
                        if (isempty(selPanel) ||  isempty(selIdx)) || selPanel~=i
                            continue
                        end
                        
                        % We then set axisLims to the limits of the selected line in panel
                        axisLims=panels(selPanel).data(selIdx).norm2y([0 1]);
                        % If current axis is pressure in special units we make the 
                        % corresponding unit transformation
                        if strcmp(axisNames{k},'press_mWaterEq')
                            axisLims=axisLims/const.g;
                        end
                        if strcmp(axisNames{k},'press_PSI')
                            axisLims=axisLims*const.psiPerPascal*1000;
                        end
                    end
                    [ticks labels] = getSubPlotAxis(axisLims,i,displayStatus.nPanelsOnScreen);
                    displayStatus.availableAxes.(axisNames{k}).ticks=[displayStatus.availableAxes.(axisNames{k}).ticks ticks];
                    displayStatus.availableAxes.(axisNames{k}).labels=[displayStatus.availableAxes.(axisNames{k}).labels labels];
                end
            end
            if strcmp(axisNames{k},'ID')
                %generating the ID axis
                [ticks labels] = getIdAxis(i);
                displayStatus.availableAxes.(axisNames{k}).ticks=[displayStatus.availableAxes.(axisNames{k}).ticks ticks];
                displayStatus.availableAxes.(axisNames{k}).labels=[displayStatus.availableAxes.(axisNames{k}).labels labels];
            end
        end
    end
end

function [scaledTicks labels] = getSubPlotAxis(limits,globalPos,plotsOnScreen)
% getSubPlotAxis creates the axis for a given panel

% we shift and scale the data by a tiny amount to avoid the last tick of one
% plot to be in exactely the same position of the first tick of the next
% wich would produce an error as ticks must be monotonically increasing
dataShift=0.0001;
dataSpace=1-dataShift;

maxData=max(limits);
minData=min(limits);
spanData=maxData-minData;

%choosing the right amount of tick marks given de amount of plots on screen
maxTicks=2;
if plotsOnScreen<=1
    maxTicks=20;
elseif plotsOnScreen<2
    maxTicks=12;
elseif plotsOnScreen<3
    maxTicks=8;
elseif plotsOnScreen<4
    maxTicks=6;
elseif plotsOnScreen<6
    maxTicks=4;
elseif plotsOnScreen<8
    maxTicks=3;
elseif plotsOnScreen<10
    maxTicks=2;
elseif plotsOnScreen<15
    maxTicks=2;
else
    maxTicks=0;
end
ticks=[];

tickStep=spanData/maxTicks;%the tick step that fits to the number of requiered ticks marks
multi=10^floor(log10(tickStep));%multiplier (power of 10 corespoinding to the first digit of the tick step value)
scaledTickStep=tickStep/multi;
validSteps=[1 2 5];%acceptable steps
[~, stepID]=min(abs(validSteps-scaledTickStep));
step=validSteps(stepID)*multi;%best acceptable tick step

firstStep=ceil(minData/step)*step;%first tick step

%unscaled tick marks
ticks=firstStep:step:maxData;

labels=mat2cell(ticks,1,ones(1,length(ticks)));
labels = cellfun(@num2str,labels,'UniformOutput',false);%labels as a cell array of strings
scaledTicks=(((ticks-minData)/spanData)*dataSpace)+dataShift+globalPos-1;
end

function [ticks labels] = getIdAxis(p)
    global panels
    ticks=[];
    labels={};
    for d=1:length(panels(p).data)
        labels{d}=panels(p).data(d).ID;
    end
    labels=unique(labels);
    nLabels=length(labels);
    for l=1:nLabels
        ticks(l)=((1/(nLabels+1))*l)+p-1;
    end
end

function answer = isSingleAxis(axisName, i)
    global panels
    answer=true;
    nDataFields=length(panels(i).data);
    if nDataFields<=1
        return;
    end
    linesUsingAxis=0;
    allAbsoluteNormalization=true;
    for j=1:nDataFields
        % if the data line has same units of current axis
        % OR data line use pressure axis (in kPa) and current axis is also pressure but in other units
        if strcmp(panels(i).data(j).axisID,axisName) || (strcmp(panels(i).data(j).axisID,'press_kPa') && any(strcmp(axisName,{'press_mWaterEq','press_PSI'})))
            linesUsingAxis=linesUsingAxis+1;
            if any(strcmp(panels(i).data(j).normMode{1},{'range','window','rawRange','waterColumn','waterColumnOrMax','Zero2Max'}))
                allAbsoluteNormalization=false;
            end
        end
    end
    if linesUsingAxis>1 && ~allAbsoluteNormalization
        answer=false;
    end
end