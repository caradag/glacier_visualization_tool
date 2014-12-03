function [freqPow freqPowTime meanPress noise stdev dt2 windowSize2]= frequencyStrenght(ts, ps, targetPeriod, resamplingInterval, windowSize, step,noiseTreshold)
%resampling interval in minuts, windows size and step in days,
%noiseTreshold in Pa
global const

%removing leading NaNs
leadingNaNs=find(~isnan(ps),1,'first')-1;
if leadingNaNs>0
    ps=ps(leadingNaNs+1:end);
    ts=ts(leadingNaNs+1:end);
end
%removing trailing NaNs
trailingNaNs=length(ps)-find(~isnan(ps),1,'last');
if trailingNaNs>0
    ps=ps(1:end-trailingNaNs);
    ts=ts(1:end-trailingNaNs);
end

    
%resampling
dt=resamplingInterval/(24*60);%5 minutes


samplesPerWindow=round(windowSize/dt);
NFFT = 2^nextpow2(samplesPerWindow); % Next power of 2 from length of window
% Now the frequencies of the FFT would be
freq =  0.5*(1/dt)*linspace(0,1,NFFT/2+1);
% Where "0.5*(1/dt)" is the Nyquist frequency
% But this probably none of the frequencies will match exactely the target frequency
% So fi find the closest one
[~, targetIdx]= min(abs(freq-(1/targetPeriod)));
% the value of this frequency is given by (1/dt)*(targetIdx-1)*(1/NFFT)
% So we modify dt so the targetIdx'th frequency exactely match the taget frequency
dt2=targetPeriod*(targetIdx-1)*(1/NFFT);
% So the real final frequency scale is
freq =  0.5*(1/dt2)*linspace(0,1,NFFT/2+1);
windowSize2=dt2*samplesPerWindow;

% We store a logical index pointing the target frequency, this will be use
% to pick the power of the target frequency and the power of the non-target frequencies
targetFreqIdx = freq==freq(targetIdx);

minTime=ceil(min(ts)); %We start the data at first day start so later is is easit to match for all transducers
maxTime=max(ts);
regularTime=minTime:dt2:maxTime;

regularP = interp1(ts,ps,regularTime,'linear');
maxP=max(regularP);
minP=min(regularP);
ampP=maxP-minP;
normP=(regularP-minP)/ampP;


samplesCount=length(regularP);
samplesPerStep=round(step/dt2);
nWindows=floor((samplesCount-samplesPerWindow)/samplesPerStep)+1;
freqPow=nan(nWindows,1);
freqPowTime=nan(nWindows,1);
meanPress=nan(nWindows,1);
noise=nan(nWindows,1);
stdev=nan(nWindows,1);
for w=1:nWindows
    wStart=((w-1)*samplesPerStep)+1;
    wEnd=wStart+samplesPerWindow-1;
    detrendedP=detrend(regularP(wStart:wEnd));
    freqPowTime(w)=regularTime(round(wStart+samplesPerWindow/2));  
    meanPress(w)=nanmean(regularP(wStart:wEnd));
    stdev(w)=std(detrendedP);
    noise(w)=median(abs(diff(detrendedP)))/stdev(w);
    if 2*stdev(w) < (200/const.psiPerPascal)/1024
        freqPow(w)=0;
    end
            
    pressFFT=fft(detrendedP,NFFT)/samplesPerWindow;
    power = abs(pressFFT).^2;
%    freqPow(w)=power(targetFreqIdx)/max(power(~targetFreqIdx));    
    freqPow(w)=power(targetFreqIdx)/sum(power);    
end
freqPow=(freqPow-min(freqPow))/(max(freqPow)-min(freqPow));
