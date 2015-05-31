function diurnalOscilationPower(source,eventdata,windowSize,mode)
% Compute diurnal oscillation power on data loaded on current panels of the
% data browser GUI.
% If pressure data is found in any of the current time series, it adds a new
% data line (in red) showing the relative power of one day period oscilations
% in the frecuency spectrum of the pressure data. This is the power of one
% day oscilations divided by total power of the spectrum.
%
% INPUTS:
% windowSize => Size of the running window were the frequency content is analyzed
% mode => 'window' works only on the data visible on current window
%         'all' works over all data loaded

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
                    [yData time] = timeSubset(displayStatus.tLims,panels(p).data(d).time,panels(p).data(d).yData);
                case 'all'
                    yData=panels(p).data(d).yData;
                    time=panels(p).data(d).time;
            end
            disp(['Processing ' panels(p).data(d).ID ' from ' datestr(time(1)) ' to ' datestr(time(end))]);
            
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