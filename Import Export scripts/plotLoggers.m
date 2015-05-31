figure;
hold on
nLoggers=length(loggers.time);
mint=Inf;
maxt=-Inf;
for i=1:nLoggers
    nFiles=length(loggers.fileNames{i});
    for j=1:nFiles
        cmenu = uicontextmenu; %creating right-click contextual menu
        lineHandle=plot(loggers.time{i}(loggers.fileLimits{i}(j,1):loggers.fileLimits{i}(j,2)),loggers.temperature{i}(loggers.fileLimits{i}(j,1):loggers.fileLimits{i}(j,2)),'UIContextMenu', cmenu);
        cmint=min(loggers.time{i});
        cmaxt=max(loggers.time{i});
        if cmint<mint
            mint=cmint;
            minLogger=i;
        end
        if cmaxt>maxt
            maxt=cmaxt;
            maxLogger=i;
        end
        % Configuring right-click contextual menu
        uimenu(cmenu, 'Label', ['Logger ' loggers.loggerID{i} ', file: ' loggers.fileNames{i}{j}],'Callback', ['clipboard(''copy'',''' loggers.fileNames{i}{j} ''');']);
        uimenu(cmenu, 'Label', 'Select', 'Callback', sprintf('set(%.20f,''Color'',''r'');',lineHandle));
        uimenu(cmenu, 'Label', 'Unselect', 'Callback', sprintf('set(%.20f,''Color'',''b'');',lineHandle));
    end
    
end
[ticks labels] = smartDateTick(mint,maxt,'d','m');
set(gca,'XTick',ticks,'XTickLabel',labels,'XLim',[mint maxt]);
