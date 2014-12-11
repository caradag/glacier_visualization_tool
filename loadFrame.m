covFile='/home/camilo/5_UBC/Data visualization GUI/EOF/Results/5Day_normalized_detrended/covariances_5Day_normalized_detrended.mat';
if ~exist('covStack','var')
    load(covFile);
end
global panels displayStatus const
panels=struct('data',{});
frame = str2double(inputdlg('Frame number: ','frame',1));
n=covStack(frame).n;
[cols rows]=meshgrid(1:n,1:n);
cols=cols(triu(true(n),1));
rows=rows(triu(true(n),1));
nPairs=(n*n-n)/2;
loaded=false(n,1);
for pair=1:nPairs
    cov=covStack(frame).cov(rows(pair),cols(pair));
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
