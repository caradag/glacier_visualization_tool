function varargout=grid2pos(grid,year)
    if ~iscell(grid)
        grid={grid};
    end
    nGrids=length(grid);
    E=nan(nGrids,1);
    N=nan(nGrids,1);

    % Grid definition
    rotation=68.3264; % Respect to UTM grid north (a bit different from true north)
    gridSize=1000/16; % 62.5 m
    % Refrence coordinates for year 2011 and grid position R10C10
    Y0=2011;
    E10= 601766.785764602;
    N10=6743560.96855554;

    dE=gridSize*sind(rotation);
    dN=gridSize*cosd(rotation);
    
    for k=1:nGrids
        [~,~,~,~,nums] = regexp(grid{k},'R([0-9\.]{2}[\.]{0,1}[0-9\.]{0,3})C([0-9\.]{2}[\.]{0,1}[0-9\.]{0,3}).?');
        if isempty(nums)
            error(['Invalid grid identifier: ' grid]);
        end
        row=str2double(nums{1}{1})-10;
        col=str2double(nums{1}{2})-10;

        % Computing position for 2011 and bringing it up to date
        E(k)=E10+dE*col-dN*row+5.356*(year-Y0);
        N(k)=N10+dN*col+dE*row-14.678*(year-Y0);
    end
    varargout={};
    switch nargout
        case 0
            fprintf('%.3f, %.3f\n',[E N]')
        case 1
            varargout{1}=[E N];
        case 2
            varargout{1}=E;
            varargout{2}=N;
    end
end