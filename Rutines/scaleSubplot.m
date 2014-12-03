function [scaledData] = scaleSubplot(data,limits,subPos,globalPos)
%scaleSubplot Scale and shift data to be plot in the background of the
%borehole pressure time serie, and return position of axis tick marks and
%labels
nSubPlots=subPos(2);

maxData=max(limits);
minData=min(limits);

if all(data<minData) && all(data>maxData)
    scaledData=[];
    return;
end

spanData=maxData-minData;

normData=(data-minData)/spanData;

%computing range of data in scaled axis
dataSpace=(1/nSubPlots);
dataShift=dataSpace*(nSubPlots-subPos(1));

scaledData=(normData*dataSpace)+dataShift+globalPos-1;

end

