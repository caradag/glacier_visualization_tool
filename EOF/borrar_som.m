%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SOM algorithm 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% initilizing SOM
% chose size of the map for SOM 
ny=4; nx=4;
en=ny*nx;

msize=[ny nx];
% performing linear initialization of nodes
display('initialization')
%sMap=som_lininit(press_mat,'msize',msize,'hexa','sheet');
%sMap=som_lininit(press_mat,'msize',msize);
sMap=som_randinit(press_mat,'msize',msize);

% training SOM
display('training')
[sM,sT] = som_batchtrain(sMap,press_mat,'bubble','hexa','sheet','radius',[3 1],'trainlen',300); 
%[sM,sT] = som_batchtrain(sMap,press_mat,'trainlen',200); 
% here is tained over 200 times, usually this number should be equal or larger than the time series, i.e. number of rows
% in this example number of rows in data is 139  

% calulating quantization error
[q,t]=som_quality(sM,press_mat)


 bmu = som_bmus(sM,press_mat);
% figure;
% w=1/nx;
% h=1/ny;
% for y=1:ny
%     for x=1:nx;
%         n=((y-1)*nx)+x;
%         axes('Units','normalized','Position',[(x-1)*w, 1-y*h, w, h],'NextPlot','add','Box','on','XTickLabel',{},'YTickLabel',{});
%        
%         inGroup=bmu==n;
%         plot(press_mat(inGroup,:)','b');
%         
%         plot(sM.codebook(n,:),'k','LineWidth',2);
% 
%         text(0.05,0.9,sprintf('#%d, %d sensors, std: %.2f m.w.eq.',n,sum(inGroup),std(sM.codebook(n,:))/9800),'Units','normalized','BackgroundColor','w');
%     end    
% end
% 
% 
% for y=1:ny
%     for x=1:nx;
%         n=((y-1)*nx)+x;
%         axes('Units','normalized','Position',[(x-1)*w, 1-y*h, w, h],'NextPlot','add','Box','on','XTickLabel',{},'YTickLabel',{});
%        
%         inGroup=bmu==n;
%         plot(press_mat(inGroup,:)','b');
%         
%         plot(sM.codebook(n,:),'k','LineWidth',2);
% 
%         text(0.05,0.9,sprintf('#%d, %d sensors, std: %.2f m.w.eq.',n,sum(inGroup),std(sM.codebook(n,:))/9800),'Units','normalized','BackgroundColor','w');
%     end    
% end
% 
% return

 
% plotting the SOM
index=[1:en];
index=reshape(index,ny,nx);
index=index';
index=reshape(index,1,nx*ny);

figure;
mincodebook=min(min(sM.codebook));
maxcodebook=max(max(sM.codebook));

for i=1:en
    subplot(ny,nx,i)
    hold on
    inGroup=bmu==index(i);
    plot(press_mat(inGroup,:)','b');
    plot(sM.codebook(index(i),:),'k','LineWidth',2);
    set(gca,'xlim',[1 size(press_mat,2)],'ylim',[mincodebook maxcodebook]);
    title(['#' num2str(index(i))]);
end

return

% calulating hits (frequencies) of occurences of each pattern, for each seasn
hi=som_hits(sM,press_mat);
hi=100*hi/sum(hi);

% saving the results
%infile='/home/vradic/Caroline_paper/SOM_results/4x5_02/';
%filename1='IVT_CFSR_SOM_1979_2010.mat';
%save(fullfile(infile,filename1),'sM','hi','q','t');

SOM1(1:Nx*Ny,1)=NaN;
SOM2=SOM1;
 
% plotting the SOM
index=[1:en];
index=reshape(index,ny_som,nx_som);
index=index';
index=reshape(index,1,nx_som*ny_som);

X1=reshape(x_NARR,Nx,Ny);
Y1=reshape(y_NARR,Nx,Ny);

X1b=X1(1:5:end,1:5:end);
Y1b=Y1(1:5:end,1:5:end);

figure;
for i=1:en
           
    SOM1(incrop)=sM.codebook(index(i),1:length(incrop));
    SOM2(incrop)=sM.codebook(index(i),length(incrop)+1:end);
    
    SOM3=(SOM1.^2+SOM2.^2).^0.5;

 subplot(ny_som,nx_som,i)
 SOM1p=reshape(SOM1,Nx,Ny);
 SOM2p=reshape(SOM2,Nx,Ny);
 SOM3p=reshape(SOM3,Nx,Ny);
 
SOM1pb=SOM1p(1:5:end,1:5:end);
SOM2pb=SOM2p(1:5:end,1:5:end);

h=imagesc(x_NARR,y_NARR,SOM3p');
%colorbar
caxis([0 400])
axis xy  
set(h,'alphadata',~isnan(SOM3p'))  
hold on
plot(xx_coast_NARR,yy_coast_NARR,'k-','LineWidth',1);
hold on
plot(x_dom,y_dom,'-.','Color',[0.6 0.6 0.6],'LineWidth',1);
xlim([min(x_dom),max(x_dom)]);
ylim([min(y_dom),max(y_dom)]); 
hold on
quiver(X1b,Y1b,SOM1pb,SOM2pb,'Color',[0 0 0]);
title([num2str(index(i)) ', f=' num2str(hi(i),'%2.1f')])
axis off 
end