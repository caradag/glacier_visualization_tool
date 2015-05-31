%% COMPUTING RELATIVE STRENGTH OF OASCILATIONS IN THE TARGET PERIOD

diurnal=@(A,f,x) A*sin(2*pi*(x+f));

global metadata const
close all

%ranges=[0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.2];
%ranges=[0 0.01 0.02 0.05 0.1 0.2 1 2]*1e4;
%ranges=[0 0.2 0.4 0.6 1 2 4 7]*1e4;
%ranges=[0.3 1];
ranges=0.03:0.005:0.2;
linesCount=20;
colors=hsv(linesCount);
sensors=fieldnames(metadata.sensors);
nSensors=length(sensors);
masksToApply=[true true true true];
dailyContent=struct;
dateLims=[datenum([2009 1 1]) datenum([2014 12 31])];

windowSize=7; % Days
resamplingInterval=5; %Minutes
step= 7; %Days
noiseTreshold=1347; %Pa
targetPeriod=1; % Days
keepMean=false;
smoothingWindow=21;


figuresHandles=nan(1, length(ranges)-1);
figureLineCount=zeros(1, length(ranges)-1);
phases=nan(linesCount,length(ranges)-1);

for i=1:length(figuresHandles)
    figuresHandles(i)=figure('Name',['Range: ' num2str(ranges(i)) ' to ' num2str(ranges(i+1))]);
    hold on
    box on
    title(['DOI index range: ' num2str(ranges(i)) ' to ' num2str(ranges(i+1))]);
end
for i=1:nSensors
    ID=sensors{i};
    if any(strcmp(metadata.sensors.(ID).flag,{'ignore','questionable'}))
        disp(['Skipping sensor ' ID(2:end) ' (' metadata.sensors.(ID).flag ')']);
        continue
    end
    data=load([const.DataFolder const.sensorDataFile],ID);

    time=data.(ID).time.serialtime(:);
    if min(time)>dateLims(2) || max(time)<dateLims(1)
        continue;
    end     
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
    [yData time] = timeSubset(dateLims,time,yData);
    if isempty(time)
        continue;
    end
    [dailyContent.(ID).strength, dailyContent.(ID).time, ~, ~,dailyContent.(ID).std, ~, ~, dailyContent.(ID).wTimes]=frequencyStrenght(time, yData, targetPeriod, resamplingInterval, windowSize, step,noiseTreshold,keepMean);
    
    %dailyContent.(ID).strength=dailyContent.(ID).strength.*dailyContent.(ID).std;
    for r=1:length(figuresHandles)
        if figureLineCount(r)>=linesCount
            continue
        end
        inBin=find(dailyContent.(ID).strength>=ranges(r) & dailyContent.(ID).strength<ranges(r+1));
        if isempty(inBin)
            continue
        end
        figure(figuresHandles(r));
        hold on
        for p=1:length(inBin)
            [wData wTime] = timeSubset(dailyContent.(ID).wTimes(inBin(p),:),time,yData);
            desc=[ID ', ' datestr(wTime(1)) ' to '  datestr(wTime(end)) ': ' num2str(dailyContent.(ID).strength(inBin(p)))];
            disp(desc);
            wTime=wTime-min(wTime);
            wData=detrend(wData)/std(wData);
            ffit = fit( wTime(:),wData(:), diurnal,'StartPoint', [1 0.5],'Lower',[0 0],'Upper',[Inf 1]);
            yf=diurnal(ffit.A,ffit.f,wTime);
            %dstd=std(yf-y)
            figureLineCount(r)=figureLineCount(r)+1
            
            plot(wTime+ffit.f,wData,'Color',colors(figureLineCount(r),:));
            phases(figureLineCount(r),r)=ffit.f;
%             hold on
%             plot(wTime+ffit.f,yf,'r');
            %title(['f= ' num2str(ffit.f) ', A= ' num2str(ffit.A)])
%            plot(wTime-mod(ffit.f,1),detrend(wData)/std(wData));
            if figureLineCount(r)>=linesCount
                break
            end            
        end
    end
    if all(figureLineCount>=linesCount)
        break
    end
end


sensors=fieldnames(dailyContent);
nSensors=length(sensors);
strengthStack=[];
for i=1:nSensors
    ID=sensors{i};
    strengthStack=[strengthStack;dailyContent.(ID).strength(:)]; 

end
figure;
hist(strengthStack,50);

hphases=mod((phases+.25)*24,24);
figure;
hold on
plot(ranges(1:end-1),nanmean(hphases),'*b')
plot(ranges(1:end-1),nanmedian(hphases),'*g')
plot(ranges(1:end-1),nanstd(hphases),'*r')

for r=1:length(figuresHandles)
    text(ranges(r),12,num2str(figureLineCount(r)))
end
legend('Mean','Median','Std')