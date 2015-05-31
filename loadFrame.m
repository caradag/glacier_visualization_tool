function loadFrame()
covFile='/home/camilo/5_UBC/Data visualization GUI/EOF/Results/5Day_normalized_detrended_trend+res/covariances_5Day_normalized_detrended_trend+res.mat';
if ~exist('covStack','var')
    load(covFile);
end
global panels displayStatus
persistent lastFrame

options = str2double(inputdlg({'Frame number: ','Cov. source (1=raw, 2=trend, 3=residual, 4=trend*res'},'Choose frame',1,{num2str(lastFrame),'1'}));
frame=options(1);

switch options(2)
    case 1
        cellCov=cov2cell(covStack,'cov');
    case 2
        cellCov=cov2cell(covStack,'trendCov');
    case 3
        cellCov=cov2cell(covStack,'residualCov');
    case 4
        cellCov=cellfun(@(a,b) a.*b, cov2cell(covStack,'trendCov'),cov2cell(covStack,'residualCov'),'UniformOutput',false);
end
% vecCov=cellCov2vec(cellCov);
% 
% [n,xout]=hist(covVector,50);
% figure;
% bar(xout,n)

panels=struct('data',{});
lastFrame=frame;
n=covStack(frame).n;
[cols rows]=meshgrid(1:n,1:n);
cols=cols(triu(true(n),1));
rows=rows(triu(true(n),1));
nPairs=(n*n-n)/2;
loaded=false(n,1);
for pair=1:nPairs
    cov=cellCov{frame}(rows(pair),cols(pair));
    disp([covStack(frame).sensors{rows(pair)} ' with ' covStack(frame).sensors{cols(pair)} ' covariance of ' num2str(cov)])
    if abs(cov)>=0.9
        if ~loaded(rows(pair))
            panels(end+1).data=[];
            panels(end).data.type='sensors';
            panels(end).data.variable='pressure';
            panels(end).data.source='final';
            panels(end).data.ID=covStack(frame).sensors{rows(pair)};
            panels(end).data.normMode={'window'};
            loaded(rows(pair))=true;
        end
        
        if ~loaded(cols(pair))
            panels(end+1).data=[];
            panels(end).data.type='sensors';
            panels(end).data.variable='pressure';
            panels(end).data.source='final';
            panels(end).data.ID=covStack(frame).sensors{cols(pair)};
            panels(end).data.normMode={'window'};
            loaded(cols(pair))=true;
        end
    end
end
displayStatus.tLims=covStack(frame).timeLims;
updatePlot;
updatePos('figureKeyPress',[],covStack(frame).timeLims)
end
function cellCov=cov2cell(covStruct,covField)
    %Computing covariances stats
    N=length(covStruct); % Total number of covariane matrices
    cellCov=cell(N,1); % Initializing cell vector to hold all covariance matrices
    [cellCov{:}]=deal(covStruct.(covField)); % Copying covariance matrices into covVector
end
function vecCov=cellCov2vec(cellCov)
    % Now we extract the elements on the upper tiangular part and sort them as a colum vector
    vecCov = cellfun(@(x) x(triu(true(size(x,1)),1)),cellCov,'UniformOutput',false);
    % Tranforming covVector in non-cell vector that contain all covariance values
    vecCov=cat(1,vecCov{:})';
end
