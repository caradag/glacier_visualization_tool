function saveRestoreCurrentView(source,eventdata,action)
    global panels displayStatus
    switch action
        case 'save'
            lightPanels=unpopulatePanels(panels);
            [dataFile dataPath]=uiputfile('*.gph','Save graph visualization');            
            if dataFile
                save([dataPath dataFile],'displayStatus','lightPanels');
            end
        case 'load'
            [dataFile dataPath]=uigetfile('*.gph','Load graph visualization');            
            if dataFile
                load([dataPath dataFile],'-mat');
                panels=lightPanels;
                updatePlot();
            end
    end    
end