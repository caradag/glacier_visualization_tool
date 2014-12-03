function checkFileUsage()
global data

sensors=fieldnames(data);
nSensors=length(sensors);
fileNamesStack={};
for i=1:nSensors
    fileNamesStack=cat(1,fileNamesStack,data.(sensors{i}).metadata.files.names{1});
end
fileNamesStack=unique(fileNamesStack);

[currentYear,~,~]=datevec(now);
startYear=2008;


season_names = {'winter' 'summer'};        

dataFilesPath;
filename_info = [AccesoryDataFolder sensorReferenceTableFile];
filename_metadata = [AccesoryDataFolder rawFilesMetadata];
filespec.suff_max = 120; %maximum suffix of individual data files
%rawDataFolder='/media/VERBATIM HD/FIELD_master/DATA';

[pathName,ignoreFlag]= textread(filename_metadata,'%s %d %*f %*f %*f %*f %*f %*f %*d %*s','delimiter',',','headerlines',6,'commentstyle','matlab');
pathName(ignoreFlag==0)=[];

% Looking for unused files
disp('Searching for unused files in the data folder structure');
for year=startYear:currentYear
    for season=1:2
        directory=['/' num2str(year) '/' season_names{season} '/loggers/raw/'];
        files=dir([rawDataFolder directory]);
        nFiles=length(files);
        for i=1:nFiles
            if ~strcmp(files(i).name,'.') && ~strcmp(files(i).name,'..') && ~any(strcmp(fileNamesStack,[directory files(i).name])) && ~any(strcmp([directory files(i).name],pathName)) && files(i).bytes>0
                rawLineCount=NaN;
                if files(i).bytes<(80*1024*1024) % We will count lines only for files smaller than 80 Mb
                    [~, rawLineCount]=system(['sed -n ''$='' "' rawDataFolder directory files(i).name '"']);
                    rawLineCount=str2double(rawLineCount);
                end
                disp(['Unused file ' directory files(i).name ' with ' num2str(rawLineCount) ' lines (' num2str(files(i).bytes/2014) ' Kb)']);
            end
        end
    end
end

% Looking for used but identical files
disp('Searching for used but identical files in the data folder structure');
nFiles=length(fileNamesStack);
fingerprints = cell(nFiles,1);
disp('Creating MD5 file fingerprints...');
for i=1:nFiles
    fingerprints{i}=getFingerprint([rawDataFolder fileNamesStack{i}]);
end
[uniqueFingerprints, indexes]=unique(fingerprints);
nonUnique=1:nFiles;
nonUnique(indexes)=[];
nonUniqueFingerprints=unique(fingerprints(nonUnique));
for i=1:length(nonUniqueFingerprints)
    identicalFiles=find(strcmp(nonUniqueFingerprints{i},fingerprints));
    fileInfo=dir([rawDataFolder fileNamesStack{i}]);
    if fileInfo.bytes==0
        continue
    end
    disp(['Files ' sprintf('%s, ',fileNamesStack{identicalFiles}) ' are identical.']);
end

end
function fingerprint = getFingerprint(fullPath)
    [~,result]=system(['md5sum "' fullPath '"']);
    fingerprint=strtok(result);
end