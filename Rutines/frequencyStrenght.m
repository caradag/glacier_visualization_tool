function [freqPow freqPowTime meanPress noise stdev dt2 windowSize2 wTimes]= frequencyStrenght(ts, ps, targetPeriod, resamplingInterval, windowSize, step, noiseTreshold, keepMean)
%resampling interval in minutes, windows size and step in days,
%noiseTreshold in Pa

psiPerPascal=0.000145037891;

if nargin<7
    keepMean=false;
end

    
%resampling
dt=resamplingInterval/(24*60);

[regularTime, regularP, freq, NFFT, targetFreqIdx, dt2, windowSize2]=FFTsetup(ts, ps, dt, targetPeriod, windowSize,ceil(min(ts)));


highFreqLimit=20; %minutes
highFreqIdx=(1440./freq)<highFreqLimit;


samplesPerWindow=round(windowSize2/dt2);
samplesCount=length(regularP);
samplesPerStep=round(step/dt2);

nWindows=floor((samplesCount-samplesPerWindow)/samplesPerStep)+1;
freqPow=nan(nWindows,1);
freqPowTime=nan(nWindows,1);
meanPress=nan(nWindows,1);
noise=nan(nWindows,1);
stdev=nan(nWindows,1);
wTimes=nan(nWindows,2);
for w=1:nWindows
    wStart=((w-1)*samplesPerStep)+1;
    wEnd=wStart+samplesPerWindow-1;
    wTimes(w,:)=[regularTime(wStart) regularTime(wEnd)];
    % Computing mean time of the window
    freqPowTime(w)=regularTime(round(wStart+samplesPerWindow/2));  
    % Computing mean pressure inside the window
    meanPress(w)=nanmean(regularP(wStart:wEnd));
    % Detrending time series
    detrendedP=detrend(regularP(wStart:wEnd));
    % Computin standard deviation
    stdev(w)=std(detrendedP);
    
    if keepMean
        % Adding mean back to the time series if requested
        detrendedP=detrendedP+meanPress(w);
    end
                    
    pressFFT=fft(detrendedP,NFFT);
    power = (abs(pressFFT).^2)/NFFT;
    totalPower=sum(power);
    freqPow(w)=power(targetFreqIdx)/totalPower;
    noise(w)=sum(power(highFreqIdx))/totalPower;
    
    % We zero the freqPow if the noise threshold level is greater than
    % twice the standar deviation
    if stdev(w) < noiseTreshold
        freqPow(w)=0;
    end
end

