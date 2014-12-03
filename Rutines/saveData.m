function saveData(source,eventdata,flags,masks,fields)
    global metadata const
    
    if nargin<3
        flags=const.sensorFlags;
    end
    if isempty(flags)
        selection = listdlg('Name','Select sensors to export','PromptString','Select valid flags','ListString',const.sensorFlags,'SelectionMode','multiple');
        if isempty(selection)
            return;
        else
            flags=const.sensorFlags(selection);
        end
    end
    if nargin<4
        masks=const.dataMasks;
    end
    if isempty(masks)
        selection = listdlg('Name','Select masks','PromptString','Select masks to apply before exporting','ListString',const.dataMasks,'SelectionMode','multiple');
        if isempty(selection)
            return;
        else
            masks=const.dataMasks(selection);
        end
    end
    defaultFields={'pressure','temperature','battvolt','sourceLine'};
    if nargin<5
        fields=defaultFields;
    end
    if isempty(fields)
        selection = listdlg('Name','Select data fields to export','PromptString','Select data fields','ListString',defaultFields,'SelectionMode','multiple');
        if isempty(selection)
            return;
        else
            fields=defaultFields(selection);
        end
    end        
            
    [dataFile dataPath]=uiputfile([const.DataFolder '*.mat'],'Save data file');
    if ~dataFile
        return
    end
    [~, fileName, ext] = fileparts(dataFile);
    metadataFileName=[fileName '_metadata' ext];
    sensorMetadata=metadata.sensors;
    
    sensors = fieldnames(metadata.sensors);
    nSensors=length(sensors);
    for s=1:nSensors
        ID=sensors{s};
        doSave=true;
        disp(['(' num2str(s) '/' num2str(nSensors) ') Saving ' ID '...'])
        tmp=load([const.DataFolder const.sensorDataFile],ID);

        % Retreiving flags
        nFlags=length(const.sensorFlags);
        for f=1:nFlags
            flagFile=[const.MasksFolder ID '_' const.sensorFlags{f} '.txt'];
            if exist(flagFile,'file')
                tmp.(ID).flag=const.sensorFlags{f};
                % Loading content of flag file
                comments={};
                fid=fopen(flagFile,'r');
                tline = fgetl(fid);
                while ischar(tline)
                    comments{1,end+1}=tline;
                    tline = fgetl(fid);
                end
                fclose(fid);                  
                tmp.(ID).comments=comments;
            end
        end
        
        if isfield(tmp.(ID),'flag') && ~any(strcmp(tmp.(ID).flag,flags)) % If sensor should not be saved we skipp to the next one
            disp([ID ' flagged as ' tmp.(ID).flag ', won''t be included in new data file.'])
            sensorMetadata=rmfield(sensorMetadata,ID);
            continue
        end
        % Retrieveing masks information
        nMasks=length(const.dataMasks);
        toDelete=false(length(tmp.(ID).time.serialtime),1);
        for m=1:nMasks
            mask=[];
            if exist([const.MasksFolder ID '_' const.dataMasks{m} '.mat'],'file')
                mask=load([const.MasksFolder ID '_' const.dataMasks{m} '.mat']);
                maskField=fieldnames(mask);
                mask=mask.(maskField{1});
            elseif isfield(tmp.(ID),const.dataMasks{m})
                mask=tmp.(ID).(const.dataMasks{m});
            elseif strcmp(const.dataMasks{m},'deleted')
                mask=isnan(tmp.(ID).pressure{1});
            end
            if ~isempty(mask)
                if any(strcmp(masks,const.dataMasks{m}))
                    % Applying mask
                    if const.dataMaskIsLogical(m)
                        toDelete(mask)=true;
                    else
                        tmp.(ID).pressure{1}=tmp.(ID).pressure{1}+mask;
                    end
                    if isfield(tmp.(ID),const.dataMasks{m})
                        tmp.(ID)=rmfield(tmp.(ID),const.dataMasks{m});
                    end
                else
                    % Copying mask to exported dataset
                    tmp.(ID).(const.dataMasks{m})=mask;
                end                
            end            
        end
        % Removing elements to be deleted due to masks applied
        if any(toDelete)
            tmp.(ID).time.serialtime(toDelete)=[];
            tmp.(ID).pressure{1}(toDelete)=[];
            tmp.(ID).temperature{1}(toDelete)=[];
            tmp.(ID).battvolt{1}(toDelete)=[];
            tmp.(ID).sourceLine{1}(toDelete)=[];
            for m=1:nMasks
                if isfield(tmp.(ID),const.dataMasks{m})
                    tmp.(ID).(const.dataMasks{m})(toDelete)=[];
                end            
            end
        end
            
        % Removing fields that don't need to be exported
        nFields=length(defaultFields);
        for i=1:nFields
            if ~any(strcmp(defaultFields{i},fields))
                tmp.(ID)=rmfield(tmp.(ID),defaultFields{i});
            end
        end
            
        if exist([dataPath dataFile],'file')
            save([dataPath dataFile],'-struct','tmp','-append');
        else
            save([dataPath dataFile],'-struct','tmp');
        end
    end
    % Saving metadata
    disp('Saving metadata...')
    save([dataPath metadataFileName],'-struct','sensorMetadata');
    disp('DONE')
end