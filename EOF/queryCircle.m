function queryCircle(year, window,windowLength,dow, eigenVec, normData,basePath)
%% retrive and display information about one specific circle plot
%

% Setting user-specified inputs to default if not specified
if nargin < 6 || isempty(normData);
    normData=false;
end

if normData
    folderName=sprintf('%s/Results/Normalized press, %d days int, 2008 to 2014 (%d)/',basePath,windowLength,dow);
    cov_data = sprintf('%ddays_int_norm_cov_data_%d_%d.mat',windowLength,year,window);
else
    folderName=sprintf('%s/Results/Unnormalized press, %d days int, 2008 to 2014 (%d)/',basePath,windowLength,dow);
    cov_data = sprintf('%ddays_int_unnorm_cov_data_%d_%d.mat',windowLength,year,window);
end

if exist([folderName cov_data],'file')
    load([folderName cov_data]);
else
    fprintf(2,'Covariance data file NOT FOUND :%s%s\n',folderName,cov_data);
end

% fprintf('Loading data file...\n');
% % We load onlt the sensors we need
% data = load('data 2014 v5 good only.mat','-regexp',strjoin(sensors_clean,'|'));
% sensors = fieldnames(data);

[V,D] = eig(cov_clean); % D is a diagonal matrix of e/values and V is a matrix  
                        % whose columns are the corresponding eigenvectors
D2 = diag(D); % D2 is a column vector of e/values

% Getting the e/values (eigval2) and e/vectors (V2) that satisfies the lambda test
lambdabar = sum(D2)/length(sensors_clean);
ind = D2>lambdabar;
[~,order]=sort(D2,'descend');
eigval = D2(order);
V2 = V(:,order); % eigval is a column vector containing the eigenvalues

% Normalizing the e/vector (V2)
[m,n] = size(V2);
eigvec_mat = V2./repmat(max(abs(V2),[],1),m,1); % eigvec_mat is a matrix whose 
                                                % columns are the eigenvectors
startTime=datenum(start_time);
endTime=datenum(end_time);

eigvec = eigvec_mat(:,eigenVec); % eigvec is the eigenvector jj
if max(eigvec)<1;
    eigvec = -eigvec;
end

fprintf('%d Eigenvalues out of %d passed lambda test.\n',sum(ind),length(D2));
fprintf('Eigenvalue %d: %.3f\n',eigenVec,eigval(eigenVec));
fprintf('Mean eigenvalue: %.3f\n',lambdabar);
fprintf('Window covering from: %s to %s (%.1f days)\n\n',start_time,end_time,endTime-startTime);

fprintf('Magnitud of each sensor on eigenvector #%d\n',eigenVec);

[~,order]=sort(abs(eigvec),'descend');
%Looping trough components of the eigenvector
num=1;
for kk=order'
    fprintf('    #%d (%d) Sensor %s with value %.3f\n',num,order(num),sensors_clean{kk},eigvec(kk));
    num=num+1;
end

