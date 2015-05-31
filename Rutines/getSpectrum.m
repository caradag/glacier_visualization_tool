function getSpectrum(source,eventdata)

    global panels displayStatus
    
    [p d] = selectedSensor();
        
    [yData time] = timeSubset(displayStatus.tLims,panels(p).data(d).time,panels(p).data(d).yData);
    
                
    %resampling delta time
    dt=5/1440;%5 minutes
    doDetrend=1;
    keepMean=0;
    maxFreqToPlot=1/(2/1440); %2 minutes oscilations
    
    [~, regularP, freq, NFFT, targetFreqIdx, dt, windowSize]=FFTsetup(time, yData, dt, 1);
    samplesCount=length(regularP);
    
    meanP=0;
    if doDetrend
        if keepMean
            meanP=mean(regularP);
        end
        regularP=detrend(regularP)+meanP;
    end

        
    pressFFT=fft(regularP,NFFT);
    power = (abs(pressFFT).^2)/NFFT;
    totalPower=sum(power);
    freqPow=power(targetFreqIdx)/totalPower;    
    %noise(w)=sum(power(highFreqIdx))/sum(power);
    
	figure('Name',['Spectrum of ' panels(p).data(d).ID ' from ' datestr(time(1)) ' to ' datestr(time(end))]);
    hold on
    box on
    grid on
    [~,idx]=min(abs(freq-maxFreqToPlot));
    plot(freq(2:idx),power(2:idx),'r');
    plot(freq(targetFreqIdx),power(targetFreqIdx),'*k');
    set(gca,'XScale','log','YScale','log');
    ylabel('Power');
    xlabel('Frequency [1/day]');
    title(sprintf('Zero freq.: %g Total Power: %f , relative power of diurnal oscilations: %f',power(1),totalPower,freqPow))
    disp(['Power of Zero frequency: ' num2str(power(1))])
    disp(['Mean of raw data: ' num2str(mean(yData))])
    
    kPaSTD=std(panels(p).data(d).norm2y(yData));
    disp(['Raw data standard deviation: ' num2str(1000*kPaSTD) ' Pa = ' num2str(100*kPaSTD/9.8) ' cm w.eq.'])
    disp(['Regularized Prssure sample count: ' num2str(length(regularP))])
    disp(['Regularized Prssure Standard deviation: ' num2str(std(regularP))])
    disp(['Regularized Prssure mean: ' num2str(mean(regularP))])
    disp(['Total Power: ' num2str(totalPower)])
    
    
    
    