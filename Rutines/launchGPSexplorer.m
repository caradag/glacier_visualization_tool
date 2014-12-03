function launchGPSexplorer(source,eventdata,panel,d)
    global fHandles panels
    currentCursor=get(fHandles.axis,'CurrentPoint');
    time=currentCursor(1,1);
    ID=panels(panel).data(d).ID;
    GPScleaner(ID,time,'explore')
end