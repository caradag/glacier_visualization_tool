function thickness=getGPRdepth(E,N)
    global const
    
    if nargin<2 || isnan(E) || isnan(N)
        thickness=NaN;
        return;
    end
    DEM=[const.AccesoryDataFolder const.thiknessGPRmodel];
    [pathstr, name, ~] = fileparts(DEM);

    thicknessDEM=imread(DEM);

    %reading reoreferenciation data
    [imageH imageW]=size(thicknessDEM);
    tfw=load([pathstr '/' name '.tfw']);
%     xRes=abs(tfw(1));
%     yRes=abs(tfw(4));
    maxN=tfw(6);
    minN=maxN+tfw(4)*(imageH-1);
    minE=tfw(5);
    maxE=minE+tfw(1)*(imageW-1);

    [east, north]=meshgrid(linspace(minE,maxE,imageW),linspace(maxN,minN,imageH));

    thickness=double(interp2(east, north,thicknessDEM,E,N,'linear'));

    % figure;
    % imagesc(linspace(minE,maxE,imageW),linspace(maxN,minN,imageH),thicknessDEM)
    % axis xy
end