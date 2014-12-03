function rmedian=runningMedian(invec,winlen)
% return a running mean and a running standard deviation

    checkinputs(invec,winlen);
    N=length(invec);

    W=(winlen-1)/2;% Half window size
    rmedian=nan(N,1);
    for i=1:N
        rmedian(i)=median(invec(max(1,i-W):min(i+W,N)));	% Coputing mean for the corresponding window
    end
end

function checkinputs(invec,winlen)
    if winlen<3
        error('Window length must greater or equal than 3 (and odd)');
    end
    if ~mod(winlen,2)
        error('Window length must be an odd number (and greater or equal than 3)');
    end
    if min(size(invec))>1
        error('Input vector must be a row or column vector');
    end
    if length(invec)<winlen+1
        error('Input vector must have more than winlen elements');
    end
end
    
