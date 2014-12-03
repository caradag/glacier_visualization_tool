function saveHistory()
    global panels displayStatus const
    global historyRecallPointer displayHistory
    
    currentHistory=displayStatus;
    currentHistory.panels=unpopulatePanels(panels);
    if isempty(displayHistory)
        displayHistory=currentHistory;
    else
        displayHistory(end+1)=currentHistory;
    end
    
    if length(displayHistory)>const.maxMemorizedHistorySteps
        displayHistory(1)=[];
    end
    
    historyRecallPointer=length(displayHistory);
end
    
    