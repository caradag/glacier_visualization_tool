% Using get_cov_matrices to save the covariance matrices
windowSize=15; %ex t_interval
timeStep=5;
doNormalize=true;
doDetrend=true;
options=struct;
options.save_to_disk=false;
options.folder = 'test';

covStack = getCovMatrices(windowSize, timeStep, doNormalize, doDetrend,options);

save('cov_stack_15Day_normalized_detrended.mat','covStack');