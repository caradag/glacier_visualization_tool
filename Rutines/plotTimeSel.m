function plotTimeSel(cursor,mode)
    global displayStatus fHandles
    persistent timeSelHandles umenu lastMoved
    if nargin<2
        mode='replaceNearest';
    end
    if nargin<1
        cursor=[];
    end
    if isempty(lastMoved)
        lastMoved=1;
    end
    axes(fHandles.axis);
    
    for i=1:length(timeSelHandles)
        if ishandle(timeSelHandles(i))
            delete(timeSelHandles(i));
        end
    end
    if isempty(displayStatus.timeSel)
        mode='setFirst';
    end
    if ~isempty(cursor) && numel(cursor)==2
        switch mode
            case 'replaceNearest'
                [~,idx]=min(abs(displayStatus.timeSel(:,1)-cursor(1)));
            case 'replaceOther'
                idx=mod(lastMoved,2)+1;
            case 'setFirst'
                idx=1;
        end
        lastMoved=idx;
        displayStatus.timeSel(idx,1:2)=[cursor(1) cursor(2)];
        cTime=displayStatus.timeSel(idx,1);
        [cYear,~,~]=datevec(cTime);
        cDOY=floor(cTime-datenum([cYear 1 1])+1);
        set(fHandles.cursorInfo,'String',[datestr(cTime) ' (DOY ' num2str(cDOY) ')']);
    end
    handleCount=1;
    umenu=[];
    for i=1:size(displayStatus.timeSel,1)
        umenu(handleCount) = uicontextmenu;
        timeSelHandles(handleCount)=plot([1 1]*displayStatus.timeSel(i,1),[0 displayStatus.nPanels],'-.g','LineWidth',1,'UIContextMenu', umenu(handleCount));
        uimenu(umenu(handleCount), 'Label', 'Select all after', 'Callback', {@doSelect,1,[],'after_x',displayStatus.timeSel(i,1)});
        uimenu(umenu(handleCount), 'Label', 'Unselect all after', 'Callback', {@doSelect,0,[],'after_x',displayStatus.timeSel(i,1)});
        uimenu(umenu(handleCount), 'Label', 'Select all before', 'Callback', {@doSelect,1,[],'before_x',displayStatus.timeSel(i,1)});
        uimenu(umenu(handleCount), 'Label', 'Unselect all before', 'Callback', {@doSelect,0,[],'before_x',displayStatus.timeSel(i,1)});
        if size(displayStatus.timeSel,1)>1
            uimenu(umenu(handleCount), 'Label', 'Select between', 'Callback', {@doSelect,1,[],'between_points_x',displayStatus.timeSel(1:2,1)});
            uimenu(umenu(handleCount), 'Label', 'Unselect between', 'Callback', {@doSelect,0,[],'between_points_x',displayStatus.timeSel(1:2,1)});
            uimenu(umenu(handleCount), 'Label', 'Select box', 'Callback', {@doSelect,1,[],'box',displayStatus.timeSel(1:2,:)});            
            uimenu(umenu(handleCount), 'Label', 'Unselect box', 'Callback', {@doSelect,0,[],'box',displayStatus.timeSel(1:2,:)});            
        end
        uimenu(umenu(handleCount), 'Label', 'Select all', 'Callback', {@doSelect,1,[],'all'},'Separator','on');
        uimenu(umenu(handleCount), 'Label', 'Unselect all', 'Callback', {@doSelect,0,[],'all'});

        umenu(handleCount+1) = uicontextmenu;
        timeSelHandles(handleCount+1)=plot(displayStatus.tRange,[1 1]*displayStatus.timeSel(i,2),'-.g','LineWidth',1,'UIContextMenu', umenu(handleCount+1));
        uimenu(umenu(handleCount+1), 'Label', 'Select all above', 'Callback', {@doSelect,1,[],'above_point',displayStatus.timeSel(i,2)});
        uimenu(umenu(handleCount+1), 'Label', 'Unselect all above', 'Callback', {@doSelect,0,[],'above_point',displayStatus.timeSel(i,2)});
        uimenu(umenu(handleCount+1), 'Label', 'Select all under', 'Callback', {@doSelect,1,[],'below_point',displayStatus.timeSel(i,2)});
        uimenu(umenu(handleCount+1), 'Label', 'Unselect all under', 'Callback', {@doSelect,0,[],'below_point',displayStatus.timeSel(i,2)});
        if size(displayStatus.timeSel,1)>1
            uimenu(umenu(handleCount+1), 'Label', 'Select between', 'Callback', {@doSelect,1,[],'between_points_y',displayStatus.timeSel(1:2,2)});
            uimenu(umenu(handleCount+1), 'Label', 'Unselect between', 'Callback', {@doSelect,0,[],'between_points_y',displayStatus.timeSel(1:2,2)});
            uimenu(umenu(handleCount+1), 'Label', 'Select box', 'Callback', {@doSelect,1,[],'box',displayStatus.timeSel(1:2,:)});            
            uimenu(umenu(handleCount+1), 'Label', 'Unselect box', 'Callback', {@doSelect,0,[],'box',displayStatus.timeSel(1:2,:)});            
        end
        uimenu(umenu(handleCount+1), 'Label', 'Select all', 'Callback', {@doSelect,1,[],'all'},'Separator','on');
        uimenu(umenu(handleCount+1), 'Label', 'Unselect all', 'Callback', {@doSelect,0,[],'all'});
        handleCount=handleCount+2;
    end
end
