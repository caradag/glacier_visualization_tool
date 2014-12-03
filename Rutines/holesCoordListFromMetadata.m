sensorCoordsFileName=uiputfile('*.csv','Choose output coordinates file name','pressure_sensors_coords.csv');
[~, name, ext] = fileparts(sensorCoordsFileName);

 config;
filename_info = [AccesoryDataFolder sensorReferenceTableFile];

[logger_ID,logger_type,channel,sensor_ID,sensor_make,snubber,hole_ID,...%Sensor's ID info
 thickness,sensor_grid,sensor_north,sensor_east,sensor_elev,nominal_north,nominal_east,...%Sensor's position info
 install_year,install_day,install_time,uninstall_year,uninstall_day,uninstall_time,...%Sensor's installation info 
 atpress,atpress_CR1K,multiplier,icepress]...%Sensor's data calibration info
    = textread(filename_info,'%s %s %f %s %s %s %s %f %s %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f','delimiter',',','emptyvalue',NaN,'headerlines',1);


sensorList=unique(sensor_ID);
holesList=unique(hole_ID);
if isempty(holesList{1})
    holesList=holesList(2:end);
end
nHoles=length(holesList);


minYear=Inf;
maxYear=-Inf;
for i=1:nHoles
    year=str2double(holesList{i}(1:2))+2000;
    minYear=min(minYear, year);
    maxYear=max(maxYear, year);
end
for year=minYear:maxYear
    fid=fopen([name '_' num2str(year) ext],'w');
    fprintf(fid,'Easting,Northing,Elevation,Hole,Sensors,Grid,Instalation,Uninstallation,Depth\n');
    for i=1:nHoles
        holeYear=str2double(holesList{i}(1:2))+2000;
        if holeYear~=year
            continue
        end
        % Finding entries for current hole
        cases=strcmp(holesList{i},hole_ID);
        casesIdx=find(cases);
        nCases=sum(cases);    

        north=sensor_north(casesIdx(1));
        east=sensor_east(casesIdx(1));
        if (isempty(north) || isnan(north)) || (isempty(east) || isnan(east))
            north=nominal_north(casesIdx(1));
            east=nominal_east(casesIdx(1));
        end
        elev=sensor_elev(casesIdx(1));
        sensors=strjoin({sensor_ID{cases}},'/');
        grid=sensor_grid{casesIdx(1)};
        depth=thickness(casesIdx(1));

        [y, idx]=min(install_year(casesIdx));
        absIdx=casesIdx(idx);
        install=datenum(y,1,1)+install_day(absIdx)-1;
        installTxt=datestr(install);
        
        [y, idx]=max(uninstall_year(casesIdx));
        absIdx=casesIdx(idx);
        uninstall=datenum(y,1,1)+uninstall_day(absIdx)-1;
        
        if isnan(uninstall)
            uninstalTxt='';
        else
            uninstalTxt=datestr(uninstall);
        end

        fprintf(fid,'%6.2f,%7.2f,%3.1f,%s,%s,%s,%s,%s,%.1f\n',east,north,elev,holesList{i},sensors,grid,installTxt,uninstalTxt,depth);
    end
    fclose(fid);
end