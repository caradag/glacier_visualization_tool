%Script to run the different rutines of the EOF analisis
clc

dataSetDescription='5Day_normalized_detrended_SOM';

% MAIN OPTIONS
% Covariances computation
windowSize=5; % Day ex t_interval
timeStep=1; % Days
doNormalize=true;
doDetrend=true;

% Animation
doCreateCovAnimation=1;
doCreateCirclesAnimation=0;
covThreshold=0.9;
%covMode='product';
 covMode='raw';
% covMode='trend';
% covMode='residual';

%% CREATING COVARIANCE MATRICES
% Using getCovMatrices to save the covariance matrices


dataFolder=['Results' filesep dataSetDescription];
if ~exist(dataFolder,'dir')
    mkdir(dataFolder);
end
covDataFile=['covariances_' dataSetDescription '.mat'];

if exist([dataFolder filesep covDataFile],'file')
    load([dataFolder filesep covDataFile]);
else
    disp(['Covariances data file: ' dataFolder filesep covDataFile ' NOT FOUND']);
    disp('Computing covariances...');
    
    % ADDITIONAL OPTIONS
    options=struct;
    options.trendCov = 0;
    options.resCov = 0;
    options.SOM = 1;
    options.windowNum=2198;
    covStack = getCovMatrices(windowSize, timeStep, {'standardize'},options);

    % SAVING DATA
    % Optiaonally we can save tha covariance data for later use
    save([dataFolder filesep covDataFile],'covStack');
end
%% CREATING EOF CIRCLE PLOTS
% makeCircles will create a figure for EOFs as a circle plot, one for each
% time window and each one of the the mos significant eigenvectors
% Figures will be in the subfolder "Plots"
if doCreateCirclesAnimation
    figuresToCreate='map'; % Can be also {'map','eigenVectors'}
    showFiguresWhileRuning='off'; % Whether to show or not the figures on screen

    for i=1:length(covStack)
        makecircle(covStack(i), doNormalize, dataFolder,figuresToCreate,showFiguresWhileRuning);
    end

    avconvCommand=['avconv -r 14 -i ' dataFolder '/Circle_plots/*.png -vcodec libx264 ' dataFolder filesep dataSetDescription '_' sprintf('%03d',round(covThreshold*100)) '.mp4'];
    avconvCommand=['avconv -r 14 -i ' dataFolder '/Covariance_animation_frames/%05d.png -vcodec libx264 -vf crop=860:870:40:0 ' dataFolder filesep dataSetDescription '_EOFs.mp4'];
    disp('To produce animation execute:')
    disp([' >' avconvCommand]);
end
%% CREATING COVARIANCE ANIMATIONS
if doCreateCovAnimation
    animateCovariances(covStack,covThreshold,dataFolder,covMode)

    avconvCommand=['avconv -r 14 -i ' dataFolder '/Covariance_animation_frames/%05d.png -vcodec libx264 -vf crop=920:870:10:0 ' dataFolder filesep dataSetDescription '_' sprintf('%03d',round(covThreshold*100)) '.mp4'];
    disp('To produce animation execute:')
    disp([' >' avconvCommand]);
end