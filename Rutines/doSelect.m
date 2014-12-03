function doSelect(source,eventdata,setVal,panelIdx,mode,coords)
    global panels fHandles
    if isempty(panelIdx)
        [p d] = selectedSensor();
    else
        p=panelIdx(1);
        d=panelIdx(2);
    end    
    setVal=logical(setVal);
    if ~isfield(panels(p).data(d),'selection') || isempty(panels(p).data(d).selection)
        panels(p).data(d).selection=false(size(panels(p).data(d).time));
    end

    selection=false(size(panels(p).data(d).time));
    switch mode
        case {'point','after_point'}
            currentCursor=get(fHandles.axis,'CurrentPoint');
            cTime=currentCursor(1,1);
            cY=currentCursor(1,2)-p+1;
            [~,startPt]=min(((panels(p).data(d).time-cTime).^2)+((panels(p).data(d).yData-cY).^2));
            switch mode
                case 'point'
                    selection(startPt)=true;
                case 'after_point'
                    selection(startPt+1:end)=true;
            end
        case 'after_x'
            selection=panels(p).data(d).time>=coords;
        case 'before_x'
            selection=panels(p).data(d).time<=coords;
        case 'between_points_x'
            mint=min(coords(:));
            maxt=max(coords(:));
            selection=panels(p).data(d).time>=mint & panels(p).data(d).time<=maxt;
        case 'box'
            mint=min(coords(:,1));
            maxt=max(coords(:,1));
            miny=min(coords(:,2))-p+1;
            maxy=max(coords(:,2))-p+1;
            selection=panels(p).data(d).time>=mint & panels(p).data(d).time<=maxt & panels(p).data(d).yData>=miny & panels(p).data(d).yData<=maxy;
        case 'between_points_y'
            miny=min(coords(:))-p+1;
            maxy=max(coords(:))-p+1;
            selection= panels(p).data(d).yData>=miny & panels(p).data(d).yData<=maxy;
        case 'above_point'
            selection= panels(p).data(d).yData>=(coords-p+1);
        case 'below_point'
            selection= panels(p).data(d).yData<=(coords-p+1);
        case {'segment','segment_and_after'}
            if nargin<5
                warning('doSelect:Missing_Argument','For mode segment a 5th argument with segment ID has to be pass');
                return
            end
            switch mode
                case 'segment'
                    startPt=panels(p).data(d).breakes(coords,1);
                    endPt=panels(p).data(d).breakes(coords,2);
                    selection(startPt:endPt)=true;
                case'segment_and_after'
                    startPt=panels(p).data(d).breakes(coords+1,1);
                    selection(startPt:end)=true;
            end
        case 'all'
            selection(1:end)=true;
    end
    if any(selection)
        disp([num2str(sum(selection)) ' samples selected/unselected']);
        panels(p).data(d).selection(selection)=setVal;
        updatePlot;
    else
        disp(['No samples were selected with mode ' mode ' (panel: ' num2str(p) ' serie: ' num2str(d) ')']);
        coords
    end
end
    