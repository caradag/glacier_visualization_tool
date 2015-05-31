function crossCorrelation(source,eventdata,mode)
% Compute crosscorrelation between data series loaded on current panels of
% the data browser GUI.
% If pressure data is found in any of the current time series, it will be
% included on the computation.
%
% INPUTS:
% mode => 'window' works only with the data visible on current window
%         'cursors' works over the data between slection cursosr (green lines)

    global panels displayStatus
    
    if nargin<3 || isempty(windowSize)
        windowSize= str2double(inputdlg('Running window length [Days]','Diurnal oscillations power analisys configuration',1,{'5'}));
    end
    if nargin<4 || isempty(mode)
        mode='window';
    end
    
            
    nPanels=length(panels);
    disp(['Processing ' num2str(nPanels) ' panels...']);
    
    for p=1:nPanels
        nData=length(panels(p).data);
        for d=1:nData
            if ~strcmp(panels(p).data(d).variable,'pressure')
                continue;
            end
            switch mode
                case 'window'
                    tLims=displayStatus.tLims;
                case 'cursors'
                    tLims=displayStatus.timeSel(1:2,1);
            end
            disp(['Processing ' panels(p).data(d).ID ' from ' datestr(tLims(1)) ' to ' datestr(tLims(2))]);
            [yData time] = timeSubset(tLims,panels(p).data(d).time,panels(p).data(d).yData);
            
            [freqPow freqPowTime]= frequencyStrenght(time,yData, 1, 5, windowSize, 1,0);
            
            panels(p).data(end+1).time = freqPowTime;
            panels(p).data(end).yData = freqPow;
            panels(p).data(end).ID = panels(p).data(d).ID;
            panels(p).data(end).type = 'sensors';
            panels(p).data(end).source = panels(p).data(d).ID;
            panels(p).data(end).variable = 'DOP';
            panels(p).data(end).selected = 0;
            panels(p).data(end).normMode = {'range'};
            panels(p).data(end).filter = 'none';
            panels(p).data(end).style = '-   none';
            panels(p).data(end).axisID = 'norm';
            panels(p).data(end).description = ['Relative power of diurnal oscillation at sensor ' panels(p).data(d).ID];
            panels(p).data(end).selection = [];
            panels(p).data(end).cleanTimeLims = time([1 end]);
            panels(p).data(end).color = [1 0 0];
            panels(p).data(end).norm2y = @(v)v;
            panels(p).data(end).y2norm = @(v)v;
            panels(p).data(end).pos = panels(p).data(d).pos;
            panels(p).data(end).breakes = [1 length(freqPowTime)];
        end
    end
    updatePlot();