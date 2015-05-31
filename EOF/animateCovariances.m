function animateCovariances(covStack, covThreshold,workPath,covMode)

if ~isstruct(covStack) 
    if exist([workPath filesep covStack],'file')
        load([workPath filesep covStack]);
    elseif exist(covStack,'file')
        load(covStack);
    else
        error('ANIMATE_COVARIANCES:Can_not_load_covariance_data','Can''t load covariance data.');
    end
end

framesFolder='Covariance_animation_frames';
if ~exist([workPath filesep framesFolder],'dir')
    mkdir([workPath filesep framesFolder]);
end

pairCount=0;
dotRadius=20;

showFigures='off';

semiAxisScale=[[0 3];
               [20 3.5];
               [30 1.7];
               [40 1];
               [50 0.7];
               [75 0.2];
               [100 0.05];
               [200 0.01];
               [400 0.002];
               [800 0.001];
               [1200 0.0003]];


% Retriving number of time windows
nWindows=length(covStack);
% The number of covariances in the upper triangular part outside the diagoinal
% of the covariance matrix is (n^2)-s)/2 where n is the size of the matrix
% We will stack all covariances in one vector, the limits of the elements
% that come from each individual matrix are
ns=[covStack.n];
winLims=[0 cumsum(((ns.^2)-ns)/2)];
% And the total number of elements will be
nVals=winLims(end);
covVals=zeros(nVals,1);
% We populate now our vector of covariances
for i=1:nWindows
    n=size(covStack(i).cov,1);
    switch covMode
        case 'raw'
            covVals(winLims(i)+1:winLims(i+1))=covStack(i).cov(triu(true(n),1));
        case 'trend';
            covVals(winLims(i)+1:winLims(i+1))=covStack(i).trendCov(triu(true(n),1));
        case 'residual';
            covVals(winLims(i)+1:winLims(i+1))=covStack(i).residualCov (triu(true(n),1));
        case 'product';
            covVals(winLims(i)+1:winLims(i+1))=covStack(i).residualCov (triu(true(n),1)).*covStack(i).trendCov(triu(true(n),1));
    end
end

% Bringing covariances to the range [-1 1]
minRawCovVals=min(covVals);
maxRawCovVals=max(covVals);

covVals(covVals<0)=covVals(covVals<0)/abs(min(covVals));
covVals(covVals>0)=covVals(covVals>0)/abs(max(covVals));

% aboveThreshold=sum(abs(covVals)>=covThreshold);
% fprintf('%.1f%% (%d) of covariance samples above covariance threshold of %.2f\n',100*aboveThreshold/nVals,aboveThreshold,covThreshold)
% figure;
% hist(covVals,20);
% [~, name, ~] = fileparts(dataFile); 
% title([strrep(name(10:end),'_',' ') ' raw var range [' num2str(minRawCovVals) ', ' num2str(maxRawCovVals) ']'])


metadata=load('data/data 2014 v5 good only_metadata.mat');
sensors=fieldnames(metadata);


imageFile='/home/camilo/5_UBC/Data visualization GUI/Reference images/map1024.tif';
mapW=560;
mapH=560;

%mapFigure=figure('Name','Map overview','NumberTitle','off','Color',[1 1 1],'MenuBar','none','Visible',showFigures);
mapFigure=figure('Name','Map overview','NumberTitle','off','Color',[1 1 1],'Visible',showFigures);
pos=get(mapFigure,'Position');
pos(3)=mapW;
pos(4)=mapH;
set(mapFigure,'Position',pos);

baseImage=imread(imageFile);
baseImage=cat(3,flipud(baseImage(:,:,1)),flipud(baseImage(:,:,2)),flipud(baseImage(:,:,3)));
%reading reoreferenciation data
[pathstr, name, ~] = fileparts(imageFile);
[imageH, imageW, ~]=size(baseImage);
tfw=load([pathstr '/' name '.tfw']);
maxN=tfw(6);
minN=maxN+tfw(4)*(imageH-1);
minE=tfw(5);
maxE=minE+tfw(1)*(imageW-1);


mapAxes=axes();
set(mapAxes,'DataAspectRatio',[1 1 1],'YDir','normal');
set(mapAxes,'XTick',[],'YTick',[],'Units','pixels','XLim',[minE maxE],'YLim',[minN maxN],'Color',[1 1 1]);
axesPos=get(mapAxes,'Position');
reductionFactor=min(axesPos(3)/imageW,axesPos(4)/imageH);
baseImage=imresize(baseImage, reductionFactor);
[imageH, imageW, ~]=size(baseImage);


rangeE=linspace(minE,maxE,imageW);
rangeN=linspace(minN,maxN,imageH);
[E N]=meshgrid(rangeE,rangeN);

for i=1:nWindows
    messageLength=fprintf('%06.2f%% %d/%d',100*pairCount/nVals,i,nWindows);
    if ~ishandle(mapFigure)
        break;
    end
    cla;
    hold on
    frame=baseImage;
    n=covStack(i).n;
    [cols rows]=meshgrid(1:n,1:n);
    cols=cols(triu(true(n),1));
    rows=rows(triu(true(n),1));
    nPairs=(n*n-n)/2;
    pairCount=pairCount+nPairs;
    pInactive=[];
    pActive=[];
    maxFrameCov=0;
    plottedPairs=0;
    for pair=1:nPairs
        switch covMode
            case 'raw'
                cov=covStack(i).cov(rows(pair),cols(pair));
            case 'trend';
                cov=covStack(i).trendCov(rows(pair),cols(pair));
            case 'residual';
                cov=covStack(i).residualCov (rows(pair),cols(pair));
            case 'product';
                cov=covStack(i).residualCov (rows(pair),cols(pair))*covStack(i).trendCov(rows(pair),cols(pair));
        end
    
        if cov>0
            cov=cov/maxRawCovVals;
            color=logical([1 0 0]);
        else
            cov=cov/minRawCovVals;
            color=logical([0 0 1]);
        end
        maxFrameCov=max(maxFrameCov,cov);
        
        sensorID1=covStack(i).sensors{cols(pair)};
        sensorID2=covStack(i).sensors{rows(pair)};
        p1=metadata.(sensorID1).pos;
        p2=metadata.(sensorID2).pos;

        if cov<covThreshold || isnan(cov)
            pInactive=[pInactive;p1;p2];
            continue
        end
        pActive=[pActive;[p1 p2 pair cov cols(pair) rows(pair)]];

        cov=(cov-covThreshold)/(1-covThreshold);
        plottedPairs=plottedPairs+1;
        pp = sqrt(sum((p1-p2).^2));
        [~,p1Col]=min(abs(rangeE-p1(1)));
        [~,p1Row]=min(abs(rangeN-p1(2)));
        [~,p2Col]=min(abs(rangeE-p2(1)));
        [~,p2Row]=min(abs(rangeN-p2(2)));
        
        semiAxisMinor=interp1(semiAxisScale(:,1),semiAxisScale(:,2),pp);
        
        maxWidth=ceil((pp*semiAxisMinor)/((maxE-minE)/imageW));
        margin=max(maxWidth,dotRadius);
        
        startRow=max(min(p1Row,p2Row)-margin,1);
        endRow=min(max(p1Row,p2Row)+margin,imageH);
        startCol=max(min(p1Col,p2Col)-margin,1);
        endCol=min(max(p1Col,p2Col)+margin,imageW);

        boxE=E(startRow:endRow,startCol:endCol);
        boxN=N(startRow:endRow,startCol:endCol);
        d1=sqrt((boxE-p1(1)).^2 + (boxN-p1(2)).^2);
        d2=sqrt((boxE-p2(1)).^2 + (boxN-p2(2)).^2);
        d=d1+d2;
        
        pp=max(pp,20);        
        vals=((d/pp)-1)/semiAxisMinor;
        vals(vals>1)=1;
        vals=cos(vals*pi/2);

        box=cat(3,vals* color(1),vals* color(2),vals* color(3));
        frame(startRow:endRow,startCol:endCol,1:3)=frame(startRow:endRow,startCol:endCol,1:3)+uint8(box*cov*255);
    end
    if n==1
        sensorID1=covStack(i).sensors{1};
        pInactive=metadata.(sensorID1).pos;
    end
    if ~ishandle(mapFigure)
        break;
    end    
    axes(mapAxes);
    image(rangeE,rangeN,frame);
    if ~isempty(pInactive)
        plot(pInactive(:,1),pInactive(:,2),'ok','MarkerSize',5,'MarkerFaceColor','g');
    end
    if ~isempty(pActive)
        plot([pActive(:,1);pActive(:,3)],[pActive(:,2);pActive(:,4)],'or','MarkerSize',10,'MarkerFaceColor','g');
        %sorting pActive
        [~,sortedIdx]=sort(pActive(:,6),'descend');
        pActive=pActive(sortedIdx,:);
        uniqueActive=unique([pActive(:,1:2); pActive(:,3:4)],'rows');
        sensorLetter=zeros(1,size(uniqueActive,1));
        letterCount=0;
        for p=1:min(size(pActive,1),9)
            letters=[0 0];
            for j=0:1
                x=pActive(p,j*2+1);
                y=pActive(p,j*2+2);
                idx=uniqueActive(:,1)==x & uniqueActive(:,2)==y;
                if ~sensorLetter(idx)
                    sensorLetter(idx)=97+letterCount;
                    letterCount=letterCount+1;
                end
                letters(j+1)=sensorLetter(idx);
                text(x-9,y+7,char(letters(j+1)),'FontSize',10);
            end
%            text(minE-100+mod(floor((p-1)/3),3)*500,minN-30-mod(p-1,3)*50,sprintf('#%d (%c) %s and (%c)%s',p,letters(1),covStack(i).sensors{cols(pActive(p,5))}(2:end),letters(2),covStack(i).sensors{rows(pActive(p,5))}(2:end)));
            ranges=covStack(i).range(pActive(p,[7,8]),:);
            ranges=diff(ranges,1,2)/9800; %Pressure range in meters
            rangeTxT={'',''};
            for j=1:2
                if round(ranges(j)) < 1
                    rangeTxT{j}=sprintf('.%d',round(ranges(j)*10));
                elseif round(ranges(j)) < 100
                    rangeTxT{j}=sprintf('%.0f',round(ranges(j)));
                else
                    rangeTxT{j}='++';
                end
            end
            text(minE-130+mod(floor((p-1)/3),3)*530,minN-30-mod(p-1,3)*50,sprintf('#%d %c: %s(%s) & %c: %s(%s)',p,letters(1),covStack(i).sensors{cols(pActive(p,5))}(2:end),rangeTxT{1},letters(2),covStack(i).sensors{rows(pActive(p,5))}(2:end),rangeTxT{2}));
        end
    end    
    title(sprintf('#%d: %s, %s to %s (max. cov. %.2f, plotted pairs %d/%d)',i,datestr(covStack(i).timeLims(1),'yyyy'),datestr(covStack(i).timeLims(1),'mmm-dd'),datestr(covStack(i).timeLims(2),'mmm-dd'),maxFrameCov,plottedPairs,nPairs));
    drawnow;
    if ~ishandle(mapFigure)
        break;
    end
    saveas(mapAxes,sprintf([workPath filesep framesFolder filesep '%05d.png'],i),'png');
    fprintf('%c',8*ones(messageLength,1));
    
end

