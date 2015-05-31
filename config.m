% data file, if empty a dialog box will ask to select a file
sensorDataFile='data 2014 v5.mat';

% default folder for open/save data
DataFolder='/home/camilo/5_UBC/Data visualization GUI/Borehole data/';

% default folder were all processing routines are
routinesFolder='/home/camilo/5_UBC/Data visualization GUI/Rutines/';

% default folder for temporary data masks
MasksFolder='/home/camilo/5_UBC/Data visualization GUI/Masks/';

% accesory data folder (metadata, GPS, temperature, melt, etc...)
AccesoryDataFolder='/home/camilo/5_UBC/Data visualization GUI/Accesory data/';

% default folder for saved graphs/views
savedGraphsFolder='/home/camilo/5_UBC/Data visualization GUI/Saved graphs/';

% default folder for reference images/maps
refImagesFolder='/home/camilo/5_UBC/Data visualization GUI/Reference images/';
mapImage='map1024.tif';

% RAW data folder
rawDataFolder='/home/camilo/5_UBC/Field/FIELD_DATA/DATA';

% defining accesory data files
temperatureTimeserieFile='T_GL1.txt';
sensorReferenceTableFile='Pressure_Sensor_Reference_Table_2014.csv';
rawFilesMetadata='data_logges_raw_files_metadata.csv';
glacholeFile='glachole.mod';
gpsFile='GPSdata_v4.mat';
meltFile='meltData.mat';
thiknessGPRmodel='thikness_GPR_model.tif';

% Text editor location
% this is even text can be open in Matlab editor, this one is used to open
% raw files, that can be big, and it support go to line sintax:
% sublime_text filename:line
textEditor='/home/camilo/Program Files/Sublime Text 2/sublime_text';

% Phisical constants
g=9.8; %Acceleration of gravity
iceDensity=916; % Ice density in km per cubic meter

% Flags
sensorFlags={'ignore','questionable','good','excellent'}; % the order is important in case of multiple flags are found
sensorFlagsDefault=[false false true true];
dataMasks={'deleted','questionable','non_drainage','offset'};
dataMasksColor={[1 0 0],[.9 .5 0],[.75 0 .75],[]}; % red, orange and purple
dataMasksDefault= [false false false true]; % Set if the mask is selected to be applied by default
dataMaskIsLogical=[true  true  true  false]; % Set if the mask is logical, all logical masks are deal with by the same functions

%available normalization modes and descriptions
normModes={'range','window','rawRange','waterColumn','waterColumnOrMax','Zero2Max','cursor','manual'};
normModesTexts={'To data range','To visible window','To raw data range','Zero to max. water column','Zero to max. water column or max. value','Zero to max','Cursor range','Set manually'};

% Transducers database
% Name -> Maker brand and model.
% measurePress -> Maximum rated pressure.
% proofPress -> The maximum pressure that can be applied without changing the transducer’s performance or accuracy. 
% burstPress -> The maximum pressure that can be applied to a transducer without rupture of either the sensing element or transducer case. 
transducers=[];

% Only ones used in 2010 and 2011
% 35 units bougth in 2012
transducers(1).name='Barksdale 422-H2-06-A';% Barksdale absolute
transducers(1).measurePress=200;
transducers(1).proofPress=400;
transducers(1).burstPress=400;

% 14 units bougth in 2012
transducers(4).name='Honeywell SPTMV1000PA5W02';% Big Honeywell with case 1000 psi
transducers(4).reatedPress=1000;
transducers(4).proofPress=3000;
transducers(4).burstPress=5000;

% 45 bougth in 2013
% 16 bougth in 2014
transducers(2).name='Barksdale 422-H2-06';% Barksdale absolute
transducers(2).reatedPress=200;
transducers(2).proofPress=400;
transducers(2).burstPress=400;

% 10 units bougth in 2013
% 115 units bougth in 2014
transducers(3).name='Honeywell 19C200PG5K';% Small Honeywell, no case
transducers(3).reatedPress=200;
transducers(3).proofPress=600;
transducers(3).burstPress=1000;

% 5 units bougth in 2013
transducers(5).name='Honeywell SPTMV0200PG5W02';% Big Honeywell with case 200 psi
transducers(5).reatedPress=1000;
transducers(5).proofPress=600;
transducers(5).burstPress=1000;

