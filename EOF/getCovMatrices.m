function statStack = getCovMatrices(windowSize, timeStep, preprocessing,options)
% Compute covariance matrices over a moving window trough the dataset
%
% Inputs: 
%   windowSize  - Size of the moving window in days
%                 Default: NONE it is mandatory Data type: Double
%   timeStep    - Amount of time in days to shift the window on each step
%                   Default: 1 day  Data type: Double
%   preprocessing - Cell array with preprocessing options
%                   Default: {'detrend'}  Data type: cell array of strings
%       Available options are:
%           'envelope'   : Replace data by the difference between its upper and lower envelopes
%           'runmedian'  : Smooth using running median (see trendWin option)
%           'detrend'    : Subtract the best linear fit to the data
%           'standardize': Substract the mean and divide by the std
%           'unitscale'  : Scale data to the range [0 1]. (x-min)/(max-min)
%           'zeromean'   : Substract the mean
%           'keepmean'   : Keep the mean even if detrended, standardized...
%               Preprocessing options are applied in the above order.
%               keepmean will keep the mean found in raw data or after
%               envelope & runmedian calculations if applied
%  ######################## OPTIONS #############################
%   options     - Optional structure with computation options.
%                 It can include any of the following fields
%    GENERAL OPTIONS >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>       
%    datatype  > Either 'pressure' or 'temperature'
%                  Default: 'pressure' Data type: char string
%    startTime > Star time of the computation.
%                  Default: start of dataset. Data type: matlab serial time
%    endTime   > End time of the computation.
%                  Default: end of dataset. Data type: matlab serial time
%    dt        > Time step for data interpolation to a regular sampling
%                  Default: 2 minutes Data type: double in DAYS
%    trendWin  > Runing median window size for computation of the trend.
%                  Default: 1, Units: Days
%    windowNum > As alternative to start-end times a window correlative
%                number can be specified. If zero all time windows will be
%                used.
%                  Default: 0
%    interp_meth > Method used for interpolation as defined for interp1
%                  Default: 'linear' Data type: char string
%  max_nan     > Option pass to extract_v5. Default 10
%  max_succ_nan> Option pass to extract_v5. Default 4
%  max_dt      > Option pass to extract_v5. Default 20 min
%  max_miss    > Option pass to extract_v5. Default 4
%  max_miss_int> Option pass to extract_v5. Default 4
%  max_miss_out> Option pass to extract_v5. Default 4
%
%    AVAILABLE STATS >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>       
%    cov       > Boolean. If true covariances will be computed on the
%                original data (nomalized/detrended if requested)
%                  Default: false
%    std       > Boolean. If true standard deviations will be computed on
%                de original (nomalized/detrended if requested)
%                  Default: false
%    range     > Boolean. If true data ranges (min/max) will be computed on
%                de original (nomalized/detrended if requested)
%                  Default: false
%    trendCov  > Boolean. If true covariances will be computed on the
%                signal trend (running median)
%                  Default: false
%    resCov    > Boolean. If true covariances will be computed on the
%                signal resiudual (signal - running median)
%                  Default: false
%    SOM       > Boolean. If true SOM will be computed.
%                   Default: false


% Output: Vector of sctructures containing the following fields:
%  timeLims    > Start and end time of the time window (matlab timestamp)
%  sensors     > Sensor IDs of the ones used for computation (cell array)
%  loggers     > Logger ID for each sensor. (cell array)
%  n           > Number of sensors used in computation (integer)
%  window      > Correlative number of the time window (integer)
%  PLUS REQUESTED STATS FIELDS    
%  cov         > Covariance matrix
%  trendCov    > Covariance matrix for the running median trends
%  resCov      > Covariance matrix for the residuals after removng trends
%  std         > Satndard deviations
%  range       > Satndard deviations
%  SOM         > Self organinzing maps
%
    %% DEALING WITH INPUTS AND ASSINGNING DEFAULTS VALUES IF NEEDED
    global data
    
    if nargin<1
        error('GET_COV_MAT:No_window_length','Window length in days MUST be specified');
    end
    if nargin<2
        timeStep=1;
    end
    if nargin<3
        preprocessing={'detrend'};
    end
    if nargin<4
        options=struct;
    end
    
    if ~isfield(options,'datatype')
        options.datatype='pressure';
    end
    if ~isfield(options,'startTime')
        options.startTime=-Inf; %[2008 1 1];
    end
    if ~isfield(options,'endTime')
        options.endTime=Inf; %[2014 12 31];
    end
    if ~isfield(options,'dt')
        options.dt=2/1440;
    end
    if ~isfield(options,'max_nan')
        options.max_nan=10;
    end
    if ~isfield(options,'max_succ_nan')
        options.max_succ_nan=4;
    end
    if ~isfield(options,'interp_meth')
        options.interp_meth='linear';
    end
    if ~isfield(options,'max_dt')
        options.max_dt=20/1440;
    end
    if ~isfield(options,'max_miss')
        options.max_miss=options.max_succ_nan;
    end
    if ~isfield(options,'max_miss_int')
        options.max_miss_int=options.max_succ_nan;
    end
    if ~isfield(options,'max_miss_out')
        options.max_miss_out=options.max_succ_nan;
    end
    if ~isfield(options,'trendWin')
        options.trendWin=1;
    end
    if ~isfield(options,'max_miss_out')
        options.max_miss_out=options.max_succ_nan;
    end
    if ~isfield(options,'max_miss_out')
        options.max_miss_out=options.max_succ_nan;
    end
    if ~isfield(options,'windowNum')
        options.windowNum=0;
    end
    
    
    if ~isfield(options,'cov')
        options.cov=false;
    end
    if ~isfield(options,'std')
        options.std=false;
    end
    if ~isfield(options,'range')
        options.range=false;
    end
    if ~isfield(options,'trendCov')
        options.trendCov=false;
    end
    if ~isfield(options,'resCov')
        options.resCov=false;
    end
    if ~isfield(options,'SOM')
        options.SOM=false;
    end
    
    statStack=[];
    

    %% LOADING DATA AND FINDING DEFAULT TIME LIMITS IF NEEDED
    if isempty(data)
        disp('Loading data file...');
        data = load('data 2014 v5 good only.mat');
    end
    
    % Setting up some useful variables
    sensors = fieldnames(data);
    sensor_count = length(sensors);
    % If start and end time are not finite we loop trough the data to find the
    % minimum and maximum time stamps
    if ~isfinite(options.startTime) || ~isfinite(options.endTime)
        mint=Inf;
        maxt=-Inf;
        for s=1:sensor_count
            mint=min(mint,data.(sensors{s}).time.serialtime(1));
            maxt=max(maxt,data.(sensors{s}).time.serialtime(end));
        end
        if ~isfinite(options.startTime)
            options.startTime=mint;
        end
        if ~isfinite(options.endTime)
            options.endTime=maxt;
        end
    end
    options.startTime=floor(options.startTime);
    options.endTime=ceil(options.endTime);
    windowSize=round(windowSize);

    %% MAIN LOOP TO COMPUTE STATS MATRICES
    disp('Computing stats...');
    tic;
    startTimes=options.startTime:timeStep:(options.endTime-timeStep);
    nWindows=length(startTimes);
    nSamples=floor(windowSize/options.dt)+1;
    
    startWin=1;
    endWin=nWindows;
    if options.windowNum
        startWin=options.windowNum;
        endWin=options.windowNum;
    end
    
    % Looping through each time window
    for  windowCount=startWin:endWin
        tstart =startTimes(windowCount);
        tfinal = tstart+windowSize;
        
        messageLength=fprintf('%.1f%% %s',100*windowCount/nWindows,datestr(tstart));

        sensorsInRange=false(1,sensor_count);
        % Looping through the boreholes
        for ii=1:sensor_count;
            tlim = data.(sensors{ii}).time.serialtime([1 end]);
            % If sensor data covers the whole window
            if tlim(1)<=tstart && tlim(2)>=tfinal;
                sensorsInRange(ii)=true;
            end   
        end
        sensorsInRange=find(sensorsInRange);
        nSensorsInRange=length(sensorsInRange);
        % Preallocating the matrix for cov_v3
        press_mat = nan(nSamples,nSensorsInRange);
        loggers = cell(nSensorsInRange,1);

        % Looping through the boreholes
        for ii=1:nSensorsInRange;
            sensorIdx=sensorsInRange(ii);
            % Assigning data as inputs for extract_v4
            t_in = data.(sensors{sensorIdx}).time.serialtime;
            switch options.datatype
                case 'pressure'
                    p_in = data.(sensors{sensorIdx}).pressure{1};
                case 'temperature'
                    p_in = data.(sensors{sensorIdx}).temperature{1};
                otherwise
                    error('GET_COV_MAT:Unknown_data_type','Invalid datatype, you can choose pressure or temperature only.');
            end
            loggers{ii} = data.(sensors{sensorIdx}).logger{1};

            % Calling extract_v5
            [p_out, ~] = extract_v5(tstart, tfinal, t_in, p_in,...
                options.dt, options.max_nan, options.max_succ_nan, options.interp_meth, options.max_dt,...
                options.max_miss, options.max_miss_int, options.max_miss_out);
            
            press_mat(:,ii) = p_out(:);
        end
        sensorIDs=sensors(sensorsInRange);

        % Removing nan data series that might be returned if the number
        % and/or distribution of NaNs go beyond specified tresholds.
        nanCols=all(isnan(press_mat));
        if any(nanCols)
            fprintf('%c',8*ones(messageLength,1));  
            fprintf('%s from %s to %s -> Sensors %s eliminated due to NaNs content\n',datestr(tstart,'yyyy'),datestr(tstart,'mmm-dd'),datestr(tfinal,'mmm-dd'),strjoin(sensorIDs(nanCols),','));  
            messageLength=0;
        end
        
        press_mat=press_mat(:,~nanCols);
        sensorIDs=sensorIDs(~nanCols);
        sensorsInRange=sum(~nanCols);
        
        % ############### DATA PREPROCESSING #############
        % Preprocessiog options are:
        %   'envelope'   : Replace data by the difference between its upper and lower envelopes
        %   'runmedian'  : Smooth using running median (see trendWin option)
        %   'detrend'    : Subtract the best linear fit to the data
        %   'standardize': Substract the mean and divide by the std
        %   'unitscale'  : Scale data to the range [0 1]. (x-min)/(max-min)
        %   'zeromean'   : Substract the mean
        %   'keepmean'   : Keep the mean even if detrended, standardized...
        preProcessingOpt={'envelope','runmedian','detrend','standardize','unitscale','zeromean','keepmean'};
        if any(cell2mat(cellfun(@(x) ~any(strcmp(preProcessingOpt,x)),preprocessing,'UniformOutput',false)))
            warning('GETSTATS:Unrecogized_option',['Unrecognized preprocessing option. Valid options are: ' strjoin(preProcessingOpt,', ') '.']);
        end
        if any(strcmp(preprocessing,'envelope'))
            % One hour window
            winSize=ceil((1/24)/options.dt)+1-mod(10,2);
            press_mat=runningMedian(press_mat,winSize);
            % One day window
            winSize=ceil(1/options.dt)+1-mod(10,2);
            press_mat=runningAmp(press_mat,winSize);
        end                   
        if any(strcmp(preprocessing,'runmedian'))
            % Computing window size in time steps and adjusting it to the
            % next odd integer            
            winSize=ceil(options.trendWin/options.dt)+1-mod(10,2);
            press_mat=runningMedian(press_mat,winSize);
        end        
        if any(strcmp(preprocessing,'keepmean'))
            originalMean=mean(press_mat);
        end        
        if any(strcmp(preprocessing,'detrend'))
            press_mat = detrend(press_mat);
        end
        if any(strcmp(preprocessing,'standardize'))
            dataStd=std(press_mat);
            dataMean=mean(press_mat);
            press_mat = bsxfun(@minus, press_mat, dataMean);
            press_mat = bsxfun(@rdivide, press_mat, dataStd);
        end
        if any(strcmp(preprocessing,'unitscale'))
            dataMin=min(press_mat);
            dataRange=max(press_mat)-dataMin;
            press_mat = bsxfun(@minus, press_mat, dataMin);
            press_mat = bsxfun(@rdivide, press_mat, dataRange);
        end
        if any(strcmp(preprocessing,'zeromean'))
            dataMean=mean(press_mat);
            press_mat = bsxfun(@minus, press_mat, dataMean);
        end
        if any(strcmp(preprocessing,'keepmean'))
            dataMean=mean(press_mat);
            press_mat = bsxfun(@plus, press_mat, originalMean-dataMean);
        end            
%         save('press_mat-mat','press_mat');
%         return

        descriptionTxt=strjoin(preprocessing,'_');
        
        %################ STATS COMPUTATIONS ##################
        statStack(end+1).timeLims=[tstart tfinal];                    
        statStack(end).sensors=sensorIDs;                    
        statStack(end).loggers=loggers;                    
        statStack(end).n=sensorsInRange;
        statStack(end).window=windowCount;
        
        if options.range
            % Computing minimum and maximum of all dataseries
            statStack(end).range=[min(press_mat);max(press_mat)]';
        end
        if options.std
            % Coputing standad deviations
            statStack(end).std=std(press_mat)';
        end
        if options.cov        
            % Computing the covariance matrix
            statStack(end).cov=computeCov(press_mat);
        end
        if options.trendCov || options.resCov
            % Computing window size in time steps and adjusting it to the
            % next odd integer
            winSize=ceil(options.trendWin/options.dt)+1-mod(10,2);
            %Computing trends by running median
            press_trend_mat=runningMedian(press_mat,winSize);
            
            if options.trendCov
                % Computing trends covariaces if requested
                statStack(end).trendCov=computeCov(press_trend_mat);
            end
            if options.resCov
                % Computing residuals covariaces if requested
                statStack(end).residualCov=computeCov(press_mat-press_trend_mat);
            end
        end
        if options.SOM
            % Computing self prganizing maps
            ny=5; nx=5;
            sM=getSOM(press_mat,nx,ny);
            statStack(end).SOM=sM;
            if options.windowNum
                figure;
                mincodebook=min(min(sM.codebook));
                maxcodebook=max(max(sM.codebook));
                samplesCount=size(sM.codebook,2);
                w=1/nx;
                h=1/ny;
                for x=1:nx;
                    for y=1:ny
                        n=((x-1)*ny)+y;
                        axes('Units','normalized','Position',[(x-1)*w, 1-y*h, w, h],'NextPlot','add','Box','on','XTickLabel',{},'YTickLabel',{},'xlim',[1 samplesCount],'ylim',[mincodebook maxcodebook]);

                        inGroup=sM.bmu==n;
                        plot(press_mat(:,inGroup),'b');

                        plot(sM.codebook(n,:),'k','LineWidth',2);
                        %set(gca,'xlim',[1 samplesCount],'ylim',[mincodebook maxcodebook]);
                        
                        text(0.03,0.91,sprintf('#%d, %d sensors, std: %.2f m.w.eq.',n,sum(inGroup),std(sM.codebook(n,:))/9800),'Units','normalized','BackgroundColor','w');
                        text(0.03,0.1,strjoin(cellfun(@(x) x(2:end),sensorIDs(inGroup),'UniformOutput',false)),'Units','normalized','BackgroundColor','w','FontSize',8);
                    end    
                end                
                return
            end

        end
        
        fprintf('%c',8*ones(messageLength,1));  
    end
    fprintf('Done in %.1 minutes',toc/60);
end

function covariance=computeCov(x,normalize)
    if nargin<2
        normalize=false;
    end
    % Get the number of samples in the time serie in m
    m = size(x,1);
    % Remove the mean of each colum
    x = bsxfun(@minus,x,sum(x,1)/m);
    % Computing unnormalized covariance
    unnormCov = x' * x;
    % diag(unnormCov)/(m-1) are the variances
    % Therefore, the standar deviations are
    % sqrt(diag(unnormCov)/(m-1))
    
    if normalize
        % This is equivalent to normalize each time series before
        % by dividing it by the square root of the variance
        C = sqrt(diag(unnormCov));
        normDenominator  = C * C';    
    else
        % The time normalization denominator is
        % normDenominator = TimeSpan/TimeStep
        % Which for regular time step is equal to
        normDenominator= m-1;
    end
    covariance = unnormCov./normDenominator;
end

function sM=getSOM(press_mat,nx,ny)
    press_mat=press_mat';
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % SOM algorithm 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % initilizing SOM
    % Size of the map for SOM 
    msize=[ny nx];
    % performing linear initialization of nodes
    display('initialization')
    %sMap=som_lininit(press_mat,'msize',msize,'hexa','sheet');
    %sMap=som_lininit(press_mat,'msize',msize);
    sMap=som_randinit(press_mat,'msize',msize);

    % training SOM
    display('training')
    %[sM,sT] = som_batchtrain(sMap,press_mat,'bubble','hexa','sheet','radius',[3 1],'trainlen',80); 
    [sM,sT] = som_batchtrain(sMap,press_mat,'trainlen',120); 
    % here is tained over 200 times, usually this number should be equal or larger than the time series, i.e. number of rows

    % calulating quantization error
    % [q,t]=som_quality(sM,press_mat);
    sM.bmu=som_bmus(sM,press_mat);
end

function ramp=runningAmp(invec,winlen)
% return a running mean and a running standard deviation
    [N, cols]=size(invec);

    W=(winlen-1)/2;% Half window size
    ramp=nan(N,cols);
    for i=1:N
        ramp(i,:)=max(invec(max(1,i-W):min(i+W,N),:))-min(invec(max(1,i-W):min(i+W,N),:));
    end
end
    