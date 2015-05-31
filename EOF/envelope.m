refTime=[datenum([2014 7 10]) datenum([2014 7 20])];
[ydata time] = timeSubset(refTime,data.S14P04.time.serialtime,data.S14P04.pressure{1});
dt=5/1440;
dtInDay=1/dt;


rtime=min(time):dt:max(time);

figure;
hold on
mdata=runningMedian(ydata(:),5);

rdata=interp1(time,ydata,rtime);

plot(rtime,rdata,'b');

maxDayStart=10/24;
minDayStart=22/24;

if mod(rtime(1),1)<=maxDayStart
    maxStart=maxDayStart+floor(rtime(1));    
else
    maxStart=maxDayStart+floor(rtime(1))+1;
end
[~,firstSample]=min(abs(rtime-maxStart));
nDays=floor(rtime(end)-rtime(firstSample));

maxPressStack=reshape(rdata(firstSample:firstSample-1+nDays*dtInDay),dtInDay,nDays);
dayTimeStack=reshape(rtime(firstSample:firstSample-1+nDays*dtInDay),dtInDay,nDays);

[dayMax, idx]=max(maxPressStack);
maxIdx=idx+[0:nDays-1]*dtInDay;
timeMax=dayTimeStack(maxIdx);
maxIdx=maxIdx+firstSample-1;

if mod(rtime(1),1)<=minDayStart
    minStart=minDayStart+floor(rtime(1));    
else
    minStart=minDayStart+floor(rtime(1))+1;
end
[~,firstSample]=min(abs(rtime-minStart));
nDays=floor(rtime(end)-rtime(firstSample));

minPressStack=reshape(rdata(firstSample:firstSample-1+nDays*dtInDay),dtInDay,nDays);
dayTimeStack=reshape(rtime(firstSample:firstSample-1+nDays*dtInDay),dtInDay,nDays);

[dayMin, idx]=min(minPressStack);
minIdx=idx+[0:nDays-1]*dtInDay;
timeMin=dayTimeStack(minIdx);
minIdx=minIdx+firstSample-1;

plot(timeMax,dayMax,'og');
plot(timeMin,dayMin,'og');

envLims=max(minIdx(1),maxIdx(1)):min(minIdx(end),maxIdx(end));
upperEnv=interp1(timeMax,dayMax,rtime(envLims),'spline');
lowerEnv=interp1(timeMin,dayMin,rtime(envLims),'spline');
plot(rtime(envLims),upperEnv,'g')
plot(rtime(envLims),lowerEnv,'g')
%figure;
plot(rtime(envLims),upperEnv-lowerEnv,'m')
