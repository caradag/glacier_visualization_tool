% global metadata const
% sensors=fieldnames(metadata.sensors);
% nSensors=length(sensors);
% masksToApply=[true true true true];
% 
% resamplingInterval=5; %Minutes
% windowSize=9; % Days
% step= 1; %Days
% noiseTreshold=6000; %Pa
% targetPeriod=1; % Days
% 
% %nSensors=10;
% 
% dailyContent=struct;
% 
% for i=1:nSensors
%     ID=sensors{i};
%     if any(strcmp(metadata.sensors.(ID).flag,{'ignore','questionable'}))
%         disp(['Skipping sensor ' ID(2:end) ' (' metadata.sensors.(ID).flag ')']);
%         continue
%     end
%     data=load([const.DataFolder const.sensorDataFile],ID);
% 
%     time=data.(ID).time.serialtime(:);
%     nSamples=length(time);
%     yData=data.(ID).pressure{1}(:);
%     
%     % Retrieveing masks information
%     nMasks=length(const.dataMasks);
%     dataToUse=true(nSamples,1);
%     for m=1:nMasks
%         if exist([const.MasksFolder ID '_' const.dataMasks{m} '.mat'],'file')
%             mask=load([const.MasksFolder ID '_' const.dataMasks{m} '.mat']);
%             maskField=fieldnames(mask);
%             mask=mask.(maskField{1});
%         elseif isfield(data.(ID),const.dataMasks{m})
%             mask=data.(ID).(const.dataMasks{m});
%         else
%             % Inicializing masks to default values
%             switch const.dataMasks{m}
%                 case 'deleted'
%                     mask=isnan(yData);
%                 case 'offset'
%                     mask=zeros(nSamples,1);
%                 otherwise
%                     mask=false(nSamples,1);
%             end
%         end
%         if masksToApply(m) && const.dataMaskIsLogical(m)
%             dataToUse(mask)=false;
%         end
%         if masksToApply(m) && strcmp(const.dataMasks{m},'offset')
%             yData=yData+mask;
%         end
%     end                            
%     disp(['Processing sensor ' ID(2:end) ' (' num2str(sum(~dataToUse)) ' samples masked)']);
%     yData=yData(dataToUse);
%     time=time(dataToUse);
% 
% 
%     [dailyContent.(ID).strength dailyContent.(ID).time dailyContent.(ID).meanPress dailyContent.(ID).noise dailyContent.(ID).std dt2 windowSize2]=frequencyStrenght(time, yData, targetPeriod, resamplingInterval, windowSize, step,noiseTreshold);
% 
%     dt=resamplingInterval/1440;
%     fprintf('Final effective dt = %.3f minutes (%.1f seconds difference), effective window length = %.3f days (%.1f minutes difference)\n',dt2*1440,abs(dt-dt2)*86400,windowSize2,abs(windowSize2-windowSize)*1440);
%     
%     thickness=data.(ID).position{1}.thickness;
%     if isnan(thickness)
%         thickness=getGPRdepth(metadata.sensors.(ID).pos(1),metadata.sensors.(ID).pos(2));
%     end
%     oberburden=thickness*const.iceDensity*const.g;
%     dailyContent.(ID).meanPress=dailyContent.(ID).meanPress/oberburden;
% end

sensors=fieldnames(dailyContent);
nSensors=length(sensors);
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

strengthMean=strengthSum./strengthSamples;
meanPress=pressSum./strengthSamples;
meanNoise=noiseSum./strengthSamples;
meanStd=stdSum./strengthSamples;

%strengthMean(strengthSamples<4)=NaN;

figure();
hold on
%smoothStrength=smooth(strengthMean,15,'moving');
smoothingWindow=21;
smoothStrength=runningMedian(strengthMean,smoothingWindow);
[AX, strengthHandle, countHandle]=plotyy(time,smoothStrength,time(1:end-1),strengthSamples(1:end-1));
set(get(AX(1),'Ylabel'),'String','Relative power of 1/Day freq.','Color','k') 
set(get(AX(2),'Ylabel'),'String','Number of operative transducers','Color','k')
set(AX(1),'YColor','k') 
set(AX(2),'YColor','k') 
set(strengthHandle,'LineWidth',2) 
uistack(strengthHandle,'top')

extraTime=50;
[ticks labels] = smartDateTick(mint,maxt+extraTime,'m','y');
set(AX(1),'XTick',ticks,'XTickLabel',labels,'XLim',[mint maxt+extraTime],'YLim',[0 .7],'YTick',0:.1:.7);
set(AX(2),'XTick',[],'XTickLabel',{},'XLim',[mint maxt+extraTime],'YLim',[0 110],'YTick',0:10:110);

plot(time,smooth(meanPress,smoothingWindow,'moving')/2,'r');
plot(time,smooth(meanNoise,smoothingWindow,'moving'),'y');
smoothStd=smooth(meanStd,smoothingWindow,'moving');
smoothStd=smoothStd/max(smoothStd);
plot(time,smoothStd/2,'m');
axis(AX(1));
[years,~,~]=datevec(time);
for y=unique(years)
    yId=years==y;
    [peak,peakId]=max(smoothStrength(yId));
    yeart=time(yId);
    peakt=yeart(peakId);
    text(peakt,peak+0.025,[datestr(peakt,'mmm-dd') '^{th}'],'Rotation',90)
end
title({'Relative strength of oscilation with one day period (blue) and number of operative transducers (green)';'Mean pressure (read), Mean standard deviation (magenta) and noise (yellow)'})

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