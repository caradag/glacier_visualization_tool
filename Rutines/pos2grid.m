function [grids dist]=pos2grid(pos,year,frac)
    nPos=size(pos,1);
    if nargin<3
        frac=0.25;
    end
    % Grid definition
    rotation=68.3264; % Respect to UTM grid north (a bit different from true north)
    gridSize=1000/16; % 62.5 m
    % Refrence coordinates for year 2011 and grid position R10C10
    Y0=2011;
    E10= 601766.785764602;
    N10=6743560.96855554;

    dE=gridSize*sind(rotation);
    dN=gridSize*cosd(rotation);

    % Computing position grid location
    C1=pos(:,1)-E10-5.356*(year-Y0);
    C2=pos(:,2)-N10+14.678*(year-Y0);

    row=(C2-(dN/dE)*C1)./((gridSize^2)/dE);
    col=(C1+dN*row)./dE;
    
    row=row+10;
    col=col+10;
    
    if frac>0
        rrow=round(row./frac)*frac;
        rcol=round(col./frac)*frac;
    else
        rrow=row;
        rcol=col;
    end

    if frac==0
        dist=0;
        grids=[rrow(:) rcol(:)];
    else
        dist=sqrt(((rrow-row).^2)+((rcol-col).^2))*gridSize;

        grids=cell(nPos,1);
        for i=1:nPos
            grids{i}=sprintf('R%gC%g',rrow(i),rcol(i));
        end
        if nPos==1
            grids=grids{1};
        end
    end
end