function setYAxis(source,eventdata)
    global fHandles displayStatus const
    selectedAxis=const.axisIDs{get(fHandles.yAxisList,'value')};
    set(fHandles.axis,'YTick',displayStatus.availableAxes.(selectedAxis).ticks,'YTickLabel',displayStatus.availableAxes.(selectedAxis).labels,'Layer','top');
    if strcmp(selectedAxis,'ID')
        set(fHandles.axis,'FontSize',10);
    else
        set(fHandles.axis,'FontSize',12);
    end    
end