fid=fopen('actyvity_summary.txt','w')
iniTime=Inf;
for i=1:gridCount
    for j=1:length(gridList.(char(gridListText(i))))
        sensor=['S' char(gridList.(char(gridListText(i))){j})];
            sensorNorth=data.(sensor).position{1}.north;
            if ~isnumeric(sensorNorth) || ~isfinite(sensorNorth)
                sensorNorth=data.(sensor).position{1}.nominal_north;
            end
            sensorEast=data.(sensor).position{1}.east;
            if ~isnumeric(sensorEast) || ~isfinite(sensorEast)
                sensorEast=data.(sensor).position{1}.nominal_east;
            end
            activityCount=data.(sensor).activityCount/(max(data.(sensor).time.serialtime)-min(data.(sensor).time.serialtime));
            fprintf(fid,'%f %f %f %s %s\n',sensorEast,sensorNorth,activityCount,sensor(2:end),char(gridListText(i)));
    end
end
fclose(fid);