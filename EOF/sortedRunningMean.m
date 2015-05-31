function rmean=sortedRunningMean(invec,winlen,frac)
% return a running median

    if nargin<3
        frac=0.5;
    end
    
    N=length(invec);

    W=(winlen-1)/2;% Half window size
    
    rmean=nan(N,length(frac)+1);
    pos=[1; round(frac(:)*winlen); winlen];
    npos=length(pos);
    for i=W+1:N-W
        s=sort(invec(i-W:i+W));
        for j=1:npos-1
            rmean(i,j)=mean(s(pos(j):pos(j+1)));
        end
    end        
end