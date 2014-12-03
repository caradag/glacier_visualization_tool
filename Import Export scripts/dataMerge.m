baseData='/home/camilo/5_UBC/Field/FIELD_DATA/BluishBook/data extraction code/Borehole data/data 2011 v5.mat';
updateData='/home/camilo/5_UBC/Field/FIELD_DATA/BluishBook/data extraction code/Import Export scripts/sensors_data.mat';

load(updateData);
uData=data;
load(baseData);

clc
updatedSensors=fieldnames(uData);
originalSensors=fieldnames(data);
path(path,'/home/camilo/5_UBC/Field/FIELD_DATA/BluishBook/data extraction code/Rutines/');

nUpdated=length(updatedSensors);
changed=0;
for i=1:nUpdated
    sensor=char(updatedSensors(i));
    if isfield(data,sensor)
        disp(['  Checking new data for sensor ' sensor]);
        doMerge=0;
        % START TIME
        uStart=min(uData.(sensor).time.serialtime);
        oStart=min(data.(sensor).time.serialtime);
        if abs(uStart-oStart) < (1/86400)
            disp(['      Same start time: ' datestr(uStart)]);
        elseif uStart > oStart
            disp(['    !!Later start time: ' datestr(uStart) ' v/s ' datestr(oStart)]);
        elseif uStart < oStart
            disp(['    !!Earlier start time: ' datestr(uStart) ' v/s ' datestr(oStart)]);
            doMerge=1;
        end
        % END TIME
        uEnd=max(uData.(sensor).time.serialtime);
        oEnd=max(data.(sensor).time.serialtime);
        if abs(uEnd-oEnd) < (1/86400)
            disp(['      Same end time: ' datestr(uEnd)]);
        elseif uEnd > oEnd
            disp(['      Later end time: ' datestr(uEnd) ' v/s ' datestr(oEnd)]);
            doMerge=1;
        elseif uEnd < oEnd
            disp(['    !!Earlier end time: ' datestr(uEnd) ' v/s ' datestr(oEnd)]);
        end
        % DATA COUNT
        uCount=length(uData.(sensor).time.serialtime);
        oCount=length(data.(sensor).time.serialtime);
        if uCount == oCount
            disp(['      Same data samples count: ' num2str(uCount)]);
        elseif uCount > oCount
            disp(['      More data samples in updated data: ' num2str(uCount) ' v/s ' num2str(oCount)]);
            if all(isnan(uData.(sensor).time.serialtime(oCount+1:uCount)))
                disp(['      Extra NaNs in updated data ignored']);
            else
                disp(['      More data samples in updated data: ' num2str(uCount) ' v/s ' num2str(oCount)]);
                doMerge=1;
            end
        elseif uCount < oCount
            disp(['    !!Less data samples in updated data: ' num2str(uCount) ' v/s ' num2str(oCount)]);
        end
                
        % GRID POSITION
        if ~strcmp(char(uData.(sensor).grid),char(data.(sensor).grid))
            disp(['    !!Grid position changed: ' char(uData.(sensor).grid) ' v/s ' char(data.(sensor).grid)]);
            doUpdate=input('Do update? y/n [y]: ','s');
            if isempty(doUpdate)
                doUpdate='y';
            end
            if doUpdate=='y'
                data.(sensor).grid=uData.(sensor).grid;
                disp(['GRID UPDATED']);
                changed=1;
            end
        end
        
        % POSITION
        if (~isnan(uData.(sensor).position{1}.north) && (uData.(sensor).position{1}.north ~= data.(sensor).position{1}.north)) ||...
           (~isnan(uData.(sensor).position{1}.east) && (uData.(sensor).position{1}.east ~= data.(sensor).position{1}.east)) ||...     
           (~isnan(uData.(sensor).position{1}.elev) && (uData.(sensor).position{1}.elev ~= data.(sensor).position{1}.elev)) ||...
           (~isnan(uData.(sensor).position{1}.thickness) && (uData.(sensor).position{1}.thickness ~= data.(sensor).position{1}.thickness)) ||...
           (~isnan(uData.(sensor).position{1}.nominal_north) && (uData.(sensor).position{1}.nominal_north ~= data.(sensor).position{1}.nominal_north)) ||...
           (~isnan(uData.(sensor).position{1}.nominal_east) && (uData.(sensor).position{1}.nominal_east ~= data.(sensor).position{1}.nominal_east))
       
            disp(['    !!Position changed']);
            uData.(sensor).position{1}
            data.(sensor).position{1}
            doUpdate=input('Do update? y/n [y]: ','s');
            if isempty(doUpdate)
                doUpdate='y';
            end
            if doUpdate=='y'
                data.(sensor).position{1}=uData.(sensor).position{1};
                disp(['POSITION UPDATED']);
                changed=1;
            end
        end
        
        % MERGING ++++++++++++++++++++++++++++++++++
        if doMerge
            if abs(uStart-oStart) < (1/86400) && uCount > oCount && uEnd > oEnd
                disp(['MERGING data for ' sensor]);
                
                data.(sensor).time=uData.(sensor).time;
                data.(sensor).pressure=uData.(sensor).pressure;
                data.(sensor).temperature=uData.(sensor).temperature;
                data.(sensor).battvolt=uData.(sensor).battvolt;
                data.(sensor).effpress=uData.(sensor).effpress;
                data.(sensor).icepress=uData.(sensor).icepress;
                data.(sensor).logger=uData.(sensor).logger;

                if isfield(data.(sensor),'deleted')
                    data.(sensor).deleted=[data.(sensor).deleted; ones(uCount-oCount,1)];
                end
                if isfield(data.(sensor),'dailyContentMask')
                    data.(sensor).dailyContentMask=[data.(sensor).dailyContentMask; nan(uCount-oCount,1)];
                end
                data.(sensor).limits=getSensorLimits(data.(sensor));
                changed=1;
            else
                disp(['!!Special merging needed for ' sensor]);
            end
        end
    else
        disp(['ADDING new sensor ' sensor]);
        data.(sensor)=uData.(sensor);
        data.(sensor).limits=getSensorLimits(data.(sensor));
    end
end

if changed
    sensors=fieldnames(data);
    sensor_count=length(sensors);

    disp([num2str(sensor_count) ' sensors in final data']);

    disp('Saving data in updated_data.mat ...');
    save('updated_data', 'data','sensors','sensor_count');
else
    disp('No new data done, no changes needed.');
end
disp('DONE!');

    
        