function batchDiurnalOscilationPowerAnalysis(windowSize, actions, options)
% Compute the relative strength of diurnal oscillations in the power spectrum
% of the pressure time series in a moving window and display several related
% graphics if requested.
% Inputs:
%   windowSize: Size of yje moving window in days
%
%   actions: cell array of strings with the actions to perform, options are
%       compute: Compute/Recopute relative strength of diurnal oscillations
%       save: save relative strength of diurnal oscillations data
%       pressInTime: Sapce averaged plot showing the evolution of pressure
%       dayStrengthInTime: Sapce averaged plot showing the evolution of the strength of diurnal oscillations
%       stdInTime: Sapce averaged plot showing the evolution of the pressure standard deviation
%       noiseInTime: Sapce averaged plot showing the evolution of the pressure noise
%       covInTime: Sapce averaged plot showing the evolution of the unnormalized covariance
%       velocity: Sapce averaged plot showing the evolution of the unnormalized covariance
%       degreeDay: Degree day time series
%       sensorsInTime: Plot of the amount of active sensors along the time
%       plotInSpace: Time averaged plot showing distribution of daily content over space
%       crevasseScatter: Scatter plot of strength of diurnal oscillations vs distance to crevasses
%
%   options: Structure with values of all configurable values, possible fields are
%       dataFile: Data file to load the data from
%             Default: empty
%       step: Time step used to move the time window forward
%             Default: 1 day , Units: Days
%       resamplingInterval: Resampling interval to regularize time series
%             Default: 5 minutes , Units: Minutes
%       targetPeriod: Period of oscillations to be detected
%             Default: 1 Day , Units: Days
%       noiseTreshold: Amplitude of pressure oscilations considered within the noise range
%             Default: 1347 Pa, Units: Pascals
%             1347 Pa is the minimum step for a 200 PSI sensor digitized with 10 bits resolution
%       keepMean: Boolean. Whether to keep the mean of the time series before computing 
%             the FFT (fast fourier transfor) or not.
%             Default: false
%       smoothingWindow: Size of smoothing running window.
%             Time series will be smoothed for ploting using a running mean.
%             Default: 21 days, Units: Days
%
% Example call:
%   batchDiurnalOscilationPowerAnalysis(5,{'compute','save','dayStrengthInTime'},struct('keepMean',false))
global metadata const

if nargin<3
    options=struct;
end
if nargin<2
    error('DAYLY_FORCING_CONTENT:Not_enough_input_arguments','Not enough input arguments, you must specify window length and actions.');
end

% Setting up default values
%windowSize=9; % Days
resamplingInterval=5; %Minutes
step= 1; %Days
noiseTreshold=1347; %Pa
targetPeriod=1; % Days
keepMean=false;
smoothingWindow=21;

if isfield(options,'smoothingWindow')
    smoothingWindow=options.smoothingWindow;
end
if isfield(options,'step')
    step=options.step;
end
if isfield(options,'resamplingInterval')
    resamplingInterval=options.resamplingInterval;
end
if isfield(options,'targetPeriod')
    targetPeriod=options.targetPeriod;
end
if isfield(options,'noiseTreshold')
    noiseTreshold=options.noiseTreshold;
end
if isfield(options,'keepMean')
    keepMean=options.keepMean;
end
if isfield(options,'dataFile')
    if exist(options.dataFile,'file')
        if any(strcmp(actions,'compute'))
            disp(['As compute is requested, data in ' options.dataFile ' will be dismiss.']);
        else
            dailyContent=load(options.dataFile);
        end
    else
        error('Data file doesn''t exist');
    end
else
    dailyContent=[];
end
if isfield(options,'covarianceFile')
    if exist(options.covarianceFile,'file')
        load(options.covarianceFile);
    end
else
    covStack=[];
end
if ~iscell(actions)
    actions={actions};
end
sensors=fieldnames(metadata.sensors);
nSensors=length(sensors);
masksToApply=[true true true true];

%% COMPUTING RELATIVE STRENGTH OF OASCILATIONS IN THE TARGET PERIOD
if any(strcmp(actions,'compute')) || isempty(dailyContent)
    dailyContent=struct;

    for i=1:nSensors
        ID=sensors{i};
        if any(strcmp(metadata.sensors.(ID).flag,{'ignore','questionable'}))
            disp(['Skipping sensor ' ID(2:end) ' (' metadata.sensors.(ID).flag ')']);
            continue
        end
        data=load([const.DataFolder const.sensorDataFile],ID);

        time=data.(ID).time.serialtime(:);
        nSamples=length(time);
        yData=data.(ID).pressure{1}(:);

        % Retrieveing masks information
        nMasks=length(const.dataMasks);
        dataToUse=true(nSamples,1);
        for m=1:nMasks
            if exist([const.MasksFolder ID '_' const.dataMasks{m} '.mat'],'file')
                mask=load([const.MasksFolder ID '_' const.dataMasks{m} '.mat']);
                maskField=fieldnames(mask);
                mask=mask.(maskField{1});
            elseif isfield(data.(ID),const.dataMasks{m})
                mask=data.(ID).(const.dataMasks{m});
            else
                % Inicializing masks to default values
                switch const.dataMasks{m}
                    case 'deleted'
                        mask=isnan(yData);
                    case 'offset'
                        mask=zeros(nSamples,1);
                    otherwise
                        mask=false(nSamples,1);
                end
            end
            if masksToApply(m) && const.dataMaskIsLogical(m)
                dataToUse(mask)=false;
            end
            if masksToApply(m) && strcmp(const.dataMasks{m},'offset')
                yData=yData+mask;
            end
        end                            
        disp(['Processing sensor ' ID(2:end) ' (' num2str(sum(~dataToUse)) ' samples masked)']);
        yData=yData(dataToUse);
        time=time(dataToUse);


        [dailyContent.(ID).strength dailyContent.(ID).time dailyContent.(ID).meanPress dailyContent.(ID).noise dailyContent.(ID).std dt2 windowSize2]=frequencyStrenght(time, yData, targetPeriod, resamplingInterval, windowSize, step,noiseTreshold,keepMean);

        dt=resamplingInterval/1440;
        fprintf('Final effective dt = %.3f minutes (%.1f seconds difference), effective window length = %.3f days (%.1f minutes difference)\n',dt2*1440,abs(dt-dt2)*86400,windowSize2,abs(windowSize2-windowSize)*1440);

        thickness=data.(ID).position{1}.thickness;
        if isnan(thickness)
            thickness=getGPRdepth(metadata.sensors.(ID).pos(1),metadata.sensors.(ID).pos(2));
        end
        oberburden=thickness*const.iceDensity*const.g;
        dailyContent.(ID).meanPress=dailyContent.(ID).meanPress/oberburden;
    end
end

%% SAVING DAY OSCILATION RELATIVE POWER DATA

if any(strcmp(actions,'save'))
    defaultFileName=sprintf('Relative_power_of_%d_Day_oscillations_in_a_%d_days_moving_window.mat',targetPeriod,windowSize);
    [dataFile dataPath]=uiputfile(defaultFileName,'Save ocillation power data');            
    if dataFile
        save([dataPath dataFile],'-struct','dailyContent');
    end
end
%% COMPUTING AND PLOTTING VARIABLES IN TIME (SPACE AVERAGED)

sensors=fieldnames(dailyContent);
nSensors=length(sensors);
doIntime=false;
for i=1:length(actions)
   doIntime=doIntime | any(strcmp(actions{i},{'pressInTime','dayStrengthInTime','stdInTime','noiseInTime','covInTime','sensorsInTime','velocity','degreeDay'}));
end
if doIntime
    % Computing values averaged over the glacier for each day
    disp('Computing means')
    mint=Inf;
    maxt=-Inf;
    for i=1:nSensors
        ID=sensors{i};
        if isempty(dailyContent.(ID).time)
            continue
        end

        mint=min(dailyContent.(ID).time(1),mint);
        maxt=max(dailyContent.(ID).time(end),maxt);
    end

    if any(strcmp(actions,'velocity'))
        figure;
        gps=load('/home/camilo/5_UBC/Data visualization GUI/Accesory data/R22C18_multibase_Speed.mat');
        originalNan=isnan(gps.ws);
        smoothSpeed=runningMedian(gps.ws,15);
        smoothSpeed(originalNan)=NaN;
        plot(gps.wt,smoothSpeed,'LineWidth',2);
        ylabel('Surface speed [m/day]');
        extraTime=50;
        [ticks labels] = smartDateTick(mint,maxt+extraTime,'m','y');
        set(gca,'XTick',ticks,'XTickLabel',labels,'XLim',[mint maxt+extraTime],'YLim',[0 0.2]);
        return
    end
    if any(strcmp(actions,'degreeDay'))
        figure;
        [Y M D H MIN SEC temp]=textread([const.AccesoryDataFolder const.temperatureTimeserieFile],'%4d-%2d-%2d %2d:%2d:%2d %f','emptyvalue',NaN,'headerlines',1);
        time=datenum([Y M D H MIN SEC]);
        [time idx]=unique(time);
        temp=temp(idx);
        % Eliminanting all negative values
        time=time(temp>0);
        days=floor(mint):ceil(maxt);
        degDay=histc(time,days)*(5/1440);
        
%         smoothSpeed=runningMedian(gps.ws,15);
%         smoothSpeed(originalNan)=NaN;
        plot(days,degDay,'LineWidth',2);
        ylabel('Positive degree days [day]');
        extraTime=50;
        [ticks labels] = smartDateTick(mint,maxt+extraTime,'m','y');
        set(gca,'XTick',ticks,'XTickLabel',labels,'XLim',[mint maxt+extraTime],'YLim',[0 2]);
        return
    end
    
    time=floor(mint):floor(maxt);
    strengthSum=zeros(length(time),1);
    strengthSamples=zeros(length(time),1);
    strengthCount=zeros(length(time),1);
    pressSum=zeros(length(time),1);
    noiseSum=zeros(length(time),1);
    stdSum=zeros(length(time),1);

    for i=1:nSensors
        ID=sensors{i};
        if isempty(dailyContent.(ID).time)
            continue
        end

        startIdx=find(time==floor(dailyContent.(ID).time(1)));
        n=length(dailyContent.(ID).time);

        strengthSum(startIdx:startIdx+n-1)=strengthSum(startIdx:startIdx+n-1)+dailyContent.(ID).strength;
        pressSum(startIdx:startIdx+n-1)=pressSum(startIdx:startIdx+n-1)+dailyContent.(ID).meanPress;
        noiseSum(startIdx:startIdx+n-1)=noiseSum(startIdx:startIdx+n-1)+dailyContent.(ID).noise;
        stdSum(startIdx:startIdx+n-1)=stdSum(startIdx:startIdx+n-1)+dailyContent.(ID).std;

        strengthSamples(startIdx:startIdx+n-1)=strengthSamples(startIdx:startIdx+n-1)+1;
    end
    
    meanCov=zeros(length(time),1);
    if ~isempty(covStack)
        nCov=length(covStack);
        for j=1:nCov
            n=size(covStack(j).cov,1);
            if n<2
                continue;
            end
            covTime=mean(covStack(j).timeLims);
            timeIdx=time==floor(covTime);
            %meanCov(timeIdx)=sum(abs(covStack(j).cov(triu(true(n),1)))>0.9)/n;
            meanCov(timeIdx)=mean(abs(covStack(j).cov(triu(true(n),1))));
        end
    end    
    
    meanStrength=strengthSum./strengthSamples;
    meanPress=pressSum./strengthSamples;
    meanNoise=noiseSum./strengthSamples;
    meanStd=stdSum./strengthSamples;

    %% Making figures

    
    
    smoothStrength=runningMedian(meanStrength,smoothingWindow);
    smoothPress=smooth(meanPress,smoothingWindow,'moving');
    smoothNoise=smooth(meanNoise,smoothingWindow,'moving');
    smoothStd=smooth(meanStd,smoothingWindow,'moving')/9800;
    smoothCov=smooth(meanCov,smoothingWindow,'moving');

    Y=[];
    for i=1:length(actions)
        currentAction=actions{i};
        switch currentAction
            case 'pressInTime'
                Y=smoothPress;
                yLabelTxt='Mean pressure [OBP]';
                ylimits=[0 1.25];
            case 'dayStrengthInTime'
                %Y=smoothStrength*100;
                Y=smoothStrength.*smoothStd;
                yLabelTxt='Relative power of 1/Day freq. [%]';
                ylimits=[0 75];
            case 'stdInTime'
                Y=smoothStd;
                yLabelTxt='Mean pressure standar deviation [m w.eq.]';
                ylimits=[0 10];
            case 'noiseInTime'
                Y=smoothNoise*100;
                yLabelTxt='Mean power of high freq. [%]';
                ylimits=[0 10];
            case 'covInTime'
                Y=smoothCov/(1000*1000);
                yLabelTxt='Mean covariance [kPa^2]';
                ylimits=[0 1e3];
            case 'sensorsInTime'
                time=time(1:end-1);
                Y=strengthSamples(1:end-1);
                yLabelTxt='Number of operative transducers';
                ylimits=[0 110];
        end
        figure();
        hold on
        box on
%         [AX, yHandle, countHandle]=plotyy(time,Y,time(1:end-1),strengthSamples(1:end-1));
%         set(get(AX(1),'Ylabel'),'String',yLabelTxt,'Color','k') 
%         set(get(AX(2),'Ylabel'),'String','Number of operative transducers','Color','k')
%         set(AX(1),'YColor','k') 
%         set(AX(2),'YColor','k') 
%         set(yHandle,'LineWidth',2,'Color','b') 
%         uistack(yHandle,'top')
% 
%         extraTime=50;
%         [ticks labels] = smartDateTick(mint,maxt+extraTime,'m','y');
%         set(AX(1),'XTick',ticks,'XTickLabel',labels,'XLim',[mint maxt+extraTime]);
%         set(AX(2),'XTick',[],'XTickLabel',{},'XLim',[mint maxt+extraTime],'YLim',[0 110],'YTick',0:10:110);
% 
%         axis(AX(1));

        plot(time,Y,'LineWidth',2);
        ylabel(yLabelTxt);

        extraTime=50;
        [ticks labels] = smartDateTick(mint,maxt+extraTime,'m','y');
        set(gca,'XTick',ticks,'XTickLabel',labels,'XLim',[mint maxt+extraTime],'YLim',ylimits);

        if any(strcmp(actions{i},{'dayStrengthInTime','stdInTime','covInTime'}))
            [years,~,~]=datevec(time);
            for y=unique(years)
                yId=years==y;
                [peak,peakId]=max(Y(yId));
                yeart=time(yId);
                peakt=yeart(peakId);
                text(peakt,peak,[datestr(peakt,'mmm-dd') '^{th}'],'Rotation',90)
            end
        end
        title({'Relative strength of oscilation with one day period (blue) and number of operative transducers (green)';'Mean pressure (read), Mean standard deviation (magenta) and noise (yellow)'})
       
    end    

    % figure();
    % plot(time,meanNoise);
    % [ticks labels] = smartDateTick(mint,maxt,'m','y');
    % set(gca,'XTick',ticks,'XTickLabel',labels,'XLim',[mint maxt]);
    % title('Noisee')

    % figure();
    % plot(time,meanStd);
    % [ticks labels] = smartDateTick(mint,maxt,'m','y');
    % set(gca,'XTick',ticks,'XTickLabel',labels,'XLim',[mint maxt]);
    % title('Std')
    % 
    % figure();
    % plot(time,strengthMean,'*');
    % [ticks labels] = smartDateTick(mint,maxt,'m','y');
    % set(gca,'XTick',ticks,'XTickLabel',labels,'XLim',[mint maxt]);
    % title('Std')
end

%% COMPUTING AND PLOTTING OVER THE MAP TIME AVERAGED VALUES
if any(strcmp(actions,'plotInSpace'))
    %imageFile='/home/camilo/5_UBC/Data visualization GUI/Reference images/map1024.tif';
    imageFile='/home/camilo/5_UBC/Data visualization GUI/Reference images/base_map_1280px.tif';

    mapFigure=figure('Name','Map overview','NumberTitle','off','Color',[1 1 1]);

    baseImage=imread(imageFile);
    %reading reoreferenciation data
    [pathstr, name, ~] = fileparts(imageFile);
    [imageH, imageW, ~]=size(baseImage);
    tfw=load([pathstr '/' name '.tfw']);
    maxN=tfw(6);
    minN=maxN+tfw(4)*(imageH-1);
    minE=tfw(5);
    maxE=minE+tfw(1)*(imageW-1);


    mapAxes=axes();
    %set(mapAxes,'DataAspectRatio',[1 1 1],'YDir','normal');


    image([minE maxE]/1000,[maxN minN]/1000,baseImage);
    hold on
    axis equal
    axis xy
    set(mapAxes,'XLim',[minE maxE]/1000,'YLim',[minN maxN]/1000,'Color',[1 1 1]);

    seasonStart=[6 1]; % Month and day of the start of the included period 
    seasonEnd=[9 30]; % Month and day of the end of the included period 
    seasonStart=[7 15]; % Month and day of the start of the included period 
    seasonEnd=[9 7]; % Month and day of the end of the included period 
    for i=1:nSensors
        ID=sensors{i};
        if isempty(dailyContent.(ID).time)
            continue
        end

        [~, months, days]=datevec(dailyContent.(ID).time);
        mask= ((months*100+days) >= sum(seasonStart.*[100 1])) & ((months*100+days) <= sum(seasonEnd.*[100 1]));
        meanDailyContent=nanmean(dailyContent.(ID).strength(mask));
        mSize=round(meanDailyContent*30);
        meanPress=nanmean(dailyContent.(ID).meanPress);
        mSize=round(meanPress*10);
        if mSize>0
            plot(metadata.sensors.(ID).pos(1)/1000,metadata.sensors.(ID).pos(2)/1000,'o','MarkerSize',mSize,'MarkerFaceColor','r');
        end
    end
end

%% COMPUTING AND PLOTTING CREVASSE SCATER (OSCILLATION POWER VS DISTANCE TO CREVASSES)
if any(strcmp(actions,'crevasseScatter'))

    crevasses=load('/home/camilo/5_UBC/Data visualization GUI/Accesory data/crevasse_points.csv');
    gPos=pos2grid(crevasses,2011,0);
    meansDaily=zeros(nSensors,1);
    dists=zeros(nSensors,1);
    for i=1:nSensors
        ID=sensors{i};
        if isempty(dailyContent.(ID).time)
            continue
        end

        meansDaily(i)=nanmean(dailyContent.(ID).strength);

        %dists(i)=min(sqrt((crevasses(:,1)-metadata.sensors.(ID).pos(1)).^2+(crevasses(:,2)-metadata.sensors.(ID).pos(2)).^2));  
        sGrid=pos2grid(metadata.sensors.(ID).pos,2011,0);
        dist=sqrt((gPos(:,1)-sGrid(:,1)).^2+(gPos(:,2)-sGrid(:,2)).^2);  
        dist(gPos(:,2)<sGrid(:,2))=[];
        dists(i)=min(dist)*1000/16;
    end
    title('Mean relative strength of diurnal oscilations')

    figure();
    hold on

    values = hist3([meansDaily dists],[5 5]);
    values = imresize(values,50,'bicubic');
    imagesc([min(dists) max(dists)],[min(meansDaily) max(meansDaily)],values)
    colorbar
    plot(dists,meansDaily,'w*');
    x=linspace(min(dists), max(dists),6);
    y=linspace(min(meansDaily), max(meansDaily),6);
    for i=1:6
        plot([1 1]*x(i),y([1,end]),'k');
        plot(x([1,end]),[1 1]*y(i),'k');
    end
    xlim([min(dists) max(dists)]);
    ylim([min(meansDaily) max(meansDaily)]);
    xlabel('Distance to crevasses [m]')
    ylabel('Mean diurnal activity index')
    title('Mean relative strength of diurnal oscilations vs distance to crevasses')
end


