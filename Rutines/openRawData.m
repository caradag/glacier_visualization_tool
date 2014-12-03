function [fileName loggerChannel lineNumber line lineTime value]=openRawData(source,eventdata,panel,d,mode)
    global panels data fHandles const
    
    if nargin<5
        mode='open';
    end
    line='';
    lineTime=NaN;
    value=NaN;
    ID=panels(panel).data(d).ID;
    currentCursor=get(fHandles.axis,'CurrentPoint');
    cTime=currentCursor(1,1);
    % Finding closest point to click position
    dist=abs(data.(ID).time.serialtime-cTime);
    dist(isnan(data.(ID).pressure{1}))=Inf;
    [~, pointIdx]=min(dist);
    % Finding to which file that point correspond
    fileLims=data.(ID).metadata.files.limits{1};
    fileIdx=(fileLims(:,1)<=pointIdx) & (fileLims(:,2)>=pointIdx);
    fileName=data.(ID).metadata.files.names{1}{fileIdx};
    % Finding the line of the file where that data point is stored
    lineNumber=data.(ID).sourceLine{1}(pointIdx);
    % Logger type
    loggerType=data.(ID).metadata.files.logger{1}{fileIdx,2};
    % Channel
    loggerChannel=data.(ID).metadata.files.logger{1}{fileIdx,3};
    % Adjusting line according to header lines typical of the corresponding datalogger
    headerLines=0;
    if strcmp(loggerType,'CR1000')
        headerLines=4;
    end
    lineNumber=lineNumber+headerLines;
    switch mode
        case 'open'
            disp(['Opening ' loggerType ' file ' fileName ' on line ' num2str(lineNumber) ' look for channel ' num2str(loggerChannel)])
            system(['"' const.textEditor '" ' const.rawDataFolder filesep fileName ':' num2str(lineNumber) '&']);
        case 'getLine'
            [~, line]=system(['sed -n ' num2str(lineNumber) ',' num2str(lineNumber) 'p "' const.rawDataFolder filesep fileName '"']);
            switch loggerType
                case {'CR10','CR10X'}
                    lineData=textscan(line, ['%*u %f %f %f %*f %*f %s %s %s %s %s %s'], 'delimiter', ',','emptyvalue',NaN);
                    lineTime=datenum([lineData{1} 1 1])+(lineData{2}-1)+fix(lineData{3}/100)/24+rem(lineData{3},100)/1440;
                    value=lineData{loggerChannel+3}{1};
                case 'CR1000'                            
                    lineData=textscan(line,'"%4f-%2f-%2f %2f:%2f:%f" %*u %*f %*f %s %s %s %s %s %s %s %s','delimiter',',','emptyvalue',NaN,'TreatAsEmpty','"NAN"');
                    lineTime=datenum([lineData{1:6}]);
                    value=lineData{loggerChannel+6}{1};
            end
            line=strtrim(line);            
    end
end