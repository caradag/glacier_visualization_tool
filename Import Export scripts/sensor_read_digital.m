function sdata=sensor_read_digital(sensor)
%PLOTDIGITALSENSOR Summary of this function goes here
%   Detailed explanation goes here
    global const
    if isempty(const)
        const=loadConfiguration();
    end

    dataPath='/home/camilo/5_UBC/Arduino sensors and loggers/Data/';
    dirOutput=dir(dataPath);
    years=[];
    [currentYear,~,~]=datevec(now);
    for i=1:length(dirOutput)
        if(dirOutput(i).isdir)
            year=str2num(dirOutput(i).name);
            if(~isempty(year) && year>2000 && year<=currentYear)
                years(end+1)=year;
            end
        end
    end
    timestamp=[];
    data=[];
    sourceline=[];
    filesNames={};
    fileLimits=[];
    fileTimeOffsets=[];
    fileSamplingStep=[];
    fileLogger={};
    sampleCount=0;
    filesCount=0;
    headers='';
    for i=1:length(years)
        disp(['Processing year ' num2str(years(i))]);
        files=dir([dataPath num2str(years(i)) filesep sensor '*.*']);
        for j=1:length(files);
            disp(['     Processing ' files(j).name]);
            fullFilePath=[dataPath num2str(years(i)) filesep files(j).name];
            rawData=load(fullFilePath);
            timestamp=[timestamp; datenum(rawData(:,1:6))];
            data=[data; rawData(:,7:end)];
            
            [samples, ~]=size(rawData);
            filesCount=filesCount+1;
            filesNames{filesCount}=files(j).name;
            fileLimits(filesCount,1:2)=[sampleCount+1, sampleCount+samples];
            fileTimeOffsets(filesCount,1:2)=[0 0];
            fileSamplingStep(filesCount)=median(diff(timestamp));
            
            sampleCount=sampleCount+samples;
            
            fid=fopen(fullFilePath);
            fisrtLine=fgetl(fid);
            firstChar='%';
            line='';
            dataStartLine=2;
            while(firstChar=='%')
                headers=line(2:end);
                line=fgetl(fid);
                firstChar=line(1);
                dataStartLine=dataStartLine+1;
            end
            fclose(fid);

            semicolonPos=find(fisrtLine==':',1,'first');
            fileLogger{filesCount}=fisrtLine(semicolonPos+1:end);
            sourceline=[sourceline; (1:samples)'+dataStartLine];
        end
    end
    [sampleCount, dataFiledsCount]=size(data);
    disp(['Data start: ' datestr(min(timestamp))]);
    disp(['Data end  : ' datestr(max(timestamp))]);
    disp(['Bigger data gap: ' num2str(max(diff(timestamp))*24) ' hours']);
    medianInterval=median(diff(timestamp));
    disp(['Typical interval: ' num2str(medianInterval*1440) ' minutes (' num2str(medianInterval) ' days)']);
    disp(['Data samples: ' num2str(sampleCount)]);
    disp(['Number of data fields: ' num2str(dataFiledsCount)]);
    disp(['Headers: ' headers]);
    
    fieldHeders={};
    for i=1:dataFiledsCount
        fieldHeders{i}=getFieldHeader(headers,i+6);
    end


    sdata=struct;
    sdata.time.serialtime=timestamp;

    for i=1:dataFiledsCount
        switch getFieldHeader(headers,i+6);
            case {'Press[m]','Pressure[m]','Pressure[psi]'}
                sdata.pressure={single(data(:,i))*9800};%saving pressure in pascals
            case {'Cond[uS]','Conductivity[uS]'}
                sdata.conductivity={single(data(:,i))};
            case {'Trans[%]','Transmittance[%]'}
                sdata.transmissivity={single(data(:,i))};
            case 'BG[W/m2]'
                sdata.backgroundLuminosity={single(data(:,i))};
            case 'IR   [%]'
                sdata.IR_reflectivity={single(data(:,i))};
            case 'Red  [%]'
                sdata.RED_reflectivity={single(data(:,i))};
            case 'Green[%]'
                sdata.GREEN_reflectivity={single(data(:,i))};
            case 'Blue [%]'
                sdata.BLUE_reflectivity={single(data(:,i))};
            case 'UV   [%]'
                sdata.UV_reflectivity={single(data(:,i))};
            case 'Acc_X[g]'
                sdata.accelerationX={single(data(:,i))};
            case 'Acc_Y[g]'
                sdata.accelerationY={single(data(:,i))};
            case 'Acc_Z[g]'
                sdata.accelerationZ={single(data(:,i))};
            case 'AccSD[g]'
                sdata.accelerationSTD={single(data(:,i))};
            case 'Inc[deg]'
                sdata.inclination={single(data(:,i))};
            case 'MagX[uT]'
                sdata.magneticFieldX={single(data(:,i))};
            case 'MagY[uT]'
                sdata.magneticFieldY={single(data(:,i))};
            case 'MagZ[uT]'
                sdata.magneticFieldZ={single(data(:,i))};
            case 'Az [deg]'
                sdata.azimuth={single(data(:,i))};
            case 'Conf [%]'
                sdata.confinement={single(data(:,i))};
            case 'Temp [C]'
                sdata.bedTemperature={single(data(:,i))};
            case 'Volta[V]'
                sdata.voltage={single(data(:,i))};            
        end
    end
    
% Adding metadata
    filename_info = [const.AccesoryDataFolder const.sensorReferenceTableFile];

    [logger_ID,logger_type,channel,sensor_ID,sensor_make,snubber,hole_ID,...%Sensor's ID info
     thickness,sensor_grid,sensor_north,sensor_east,sensor_elev,nominal_north,nominal_east,...%Sensor's position info
     install_year,install_day,install_time,uninstall_year,uninstall_day,uninstall_time,...%Sensor's installation info 
     atpress,atpress_CR1K,multiplier,icepress]...%Sensor's data calibration info
        = textread(filename_info,'%s %s %f %s %s %s %s %f %s %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f','delimiter',',','emptyvalue',NaN,'headerlines',1);

    idx=find(strcmp(sensor_ID,sensor));
    
    sdata.sourceLine={uint32(sourceline)};
  
    sdata.metadata.installationTime={[install_year(idx), install_day(idx), install_time(idx)]};
    sdata.metadata.uninstallationTime={[uninstall_year(idx), uninstall_day(idx), uninstall_time(idx)]};
    sdata.metadata.sensorMake={sensor_make(idx)};
    sdata.metadata.snubber={snubber(idx)};
    sdata.metadata.atmosphericReadingCR10X={snubber(idx)};
    sdata.metadata.atmosphericReadingCR10X={atpress(idx)};
    sdata.metadata.atmosphericReadingCR1000={atpress_CR1K(idx)};
    sdata.metadata.multiplier={multiplier(idx)};
    sdata.metadata.hole={hole_ID(idx)};
    
    sdata.metadata.files.names={filesNames};
    sdata.metadata.files.limits={fileLimits};
    sdata.metadata.files.timeshifts={fileTimeOffsets};
    sdata.metadata.files.inFileDiscontinuities={[]};
    sdata.metadata.files.samplingStep={fileSamplingStep};
    sdata.metadata.files.logger={fileLogger};
    sdata.metadata.files.inFileDiscontinuities={[]};
    
    sdata.grid=sensor_grid(idx);
    sdata.logger={logger_ID(idx)};
    sdata.icepress= {thickness(idx)*9.8*916};
    
    position=struct;
    position.north=sensor_north(idx);
    position.east=sensor_east(idx);
    position.elev=sensor_elev(idx);
    position.thickness=thickness(idx);
    position.nominal_north=nominal_north(idx);
    position.nominal_east=nominal_east(idx);
    
    sdata.position={position};
    
    sdata.temperature={zeros(sampleCount,1)};
    sdata.battvolt={zeros(sampleCount,1)};
    if ~isfield(sdata,'pressure')
        sdata.pressure={zeros(sampleCount,1)};
    end
end
function header=getFieldHeader(headers,fildNum)
    header='No header found';
    fieldStart=1;
    fieldCount=1;
    for i=1:length(headers)
        if(headers(i)==',' || i==length(headers))
            if(fieldCount==fildNum)
                header=headers(fieldStart:i-1);
                if(i==length(headers))
                    header=headers(fieldStart:i);
                end
                return
            end
            fieldCount=fieldCount+1;
            fieldStart=i+1;
        end
    end
end 

