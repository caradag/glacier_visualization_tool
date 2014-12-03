function doFlag(source,eventdata,ID,flag)
% Set a mask file to ignore a sensor, used for sensors with only bad data
    global metadata panels const data
    if nargin<4
        Selection = listdlg('Name','Flag sensor','PromptString','Select flag type','ListString',const.sensorFlags,'SelectionMode','single','OKString','Flag','InitialValue',3);
        if isempty(Selection)
            return;
        else
            flag=const.sensorFlags{Selection};
        end
    end
    prevComment={''};
    if isfield(data.(ID),'comments')
        nLines=length(data.(ID).comments);
        for i=1:nLines
            prevComment{1}=sprintf('%s%s\n',prevComment{1},data.(ID).comments{i});
        end
    end
    
    options.Resize='on';
    options.WindowStyle='normal';
    options.Interpreter='none';
    description = inputdlg(['Describe why this sensor should be flagged as ' upper(flag) ': '],'Flag sensor',10,prevComment,options);
    if isempty(description)
        % Description is empty i.e. {}
        % when the cancel button is pressed
        return;
    elseif isempty(description{:})
        % Description contain an empty string i.e. {''}
        % when the OK button is pressed but no text has being entered
        description{1}='No description of the flag was entered';
    end
    fileName=[const.MasksFolder ID '_' flag '.txt'];
    disp([ID ' will be flag to be ' flag '. To revert this just delete the flag file ' fileName])
    description=description{1};
    nLines=size(description,1);
    fid=fopen(fileName,'w');
    for i=1:nLines
        fprintf(fid,'%s\n',strtrim(description(i,:)));
    end
    fclose(fid);
            
    npanels=length(panels);
    if npanels==1 && length(panels.data)==1
        browseTroughData([],[],+1);
    end
    % flaging in metadata
    metadata.sensors.(ID).flag=flag;
    
    updatePlot;
end