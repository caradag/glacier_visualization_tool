function [data time] = timeSubset(refTime,time,data)
%timeSubset Find a subset of data with all the samples in the range of
%refTime

trange=[min(refTime) max(refTime)];

rangeIni=find(time>=trange(1),1);
if trange(2)>time(end)
    rangeEnd=length(time);
else
    rangeEnd=find(time<trange(2),1,'last');
end
time=time(rangeIni:rangeEnd);
data=data(rangeIni:rangeEnd);

end

