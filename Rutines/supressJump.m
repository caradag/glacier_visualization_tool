function supressJump(source,eventdata,p,d)
    global panels displayStatus const
    persistent lastDelta
    
    if isempty(lastDelta)
        lastDelta=NaN;
    end
    
    if ~isfield(panels(p).data(d),'selection') || isempty(panels(p).data(d).selection) || ~any(panels(p).data(d).selection)
        disp('No point selected')
        return
    end
    selection=panels(p).data(d).selection;

    firstPt=find(selection,1,'first');
    lastPt=find(selection,1,'last');
    deltas=[NaN NaN NaN NaN NaN NaN];
    if firstPt>1
        firstPt
        panels(p).data.norm2y(panels(p).data(d).yData(firstPt-1:firstPt))
        deltas(1)=-diff(panels(p).data.norm2y(panels(p).data(d).yData(firstPt-1:firstPt)));
    end
    if lastPt<length(selection)
        deltas(2)=diff(panels(p).data.norm2y(panels(p).data(d).yData(lastPt:lastPt+1)));
    end
    deltas(3)=abs(diff(panels(p).data.norm2y(displayStatus.timeSel(:,2))));
    deltas(4)=-abs(diff(panels(p).data.norm2y(displayStatus.timeSel(:,2))));
    deltas(5)=-lastDelta;
    
    qStr={'Select adjustment value to use to supress the offset:';
         '';
         ['Automatic at start: Jump at the start of the selection (' sprintf('%.1f',deltas(1)) ' kPa)'];
         ['Automatic at end:   Jump at the end of the selection (' sprintf('%.1f',deltas(2)) ' kPa)'];
         ['Cursor difference up:  Add current difference between cursors (' sprintf('%.1f',deltas(3)) ' kPa)'];
         ['Cursor difference down:  Substract current difference between cursors (' sprintf('%.1f',deltas(4)) ' kPa)'];
         ['Revert last jump:   Use last value but in opposite dirrection (' sprintf('%.1f',deltas(5)) ' kPa)']};

    uisetpref('clearall');
    options={'Auto at start','Auto at end','Cursor diff. up','Cursor diff. down','Revert last','Cancel'};
    mode = uigetpref('None','None','Supress data offset',qStr,options,'DefaultButton','Cancel');
    delta=deltas(find(strcmpi(mode,options),1))*1000;% Selected delta in Pascals
    if isnan(delta)
        disp('User selection leads to NO adjustment.')
        return        
    else
        if ~isfield(panels(p).data(d),'offset');
            panels(p).data(d).offset=zeros(length(panels(p).data(d).time));
        end
        panels(p).data(d).offset(selection)=panels(p).data(d).offset(selection)+delta;
        
        offset=panels(p).data(d).offset;
        offsetFileName=[const.MasksFolder panels(p).data(d).ID '_offset.mat'];
        save(offsetFileName,'offset');
        disp(['Offset data saved to ' offsetFileName ' with ' num2str(sum(offset~=0)) ' samples with non-zero offsets.']);
        lastDelta=delta/1000;% Storing last delta in kPa
        updatePlot([],[],0,1);
    end
end