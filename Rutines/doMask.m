function doMask(source,eventdata,maskType,value)
% Set elements of a mask "maskType" to value
    global panels const
    doButton='Unmask';
    if value
        doButton='Mask';
    end
    availableMasks={const.dataMasks{const.dataMaskIsLogical}};
    if isempty(maskType)
        selection = listdlg('Name','Mask data points','PromptString','Select mask type','ListString',availableMasks,'SelectionMode','single','OKString',doButton,'InitialValue',1);
        if isempty(selection)
            return;
        else
            maskType=availableMasks{selection};
        end
    end
    [p d] = selectedSensor();
    % Creating mask if it doesn't exist
    if ~isfield(panels(p).data(d),maskType) || isempty(panels(p).data(d).(maskType))
        panels(p).data(d).deleted=false(size(panels(p).data(d).time));
    end
    % Adding selected points to deleted mask and clearing selected
    if ~isempty(panels(p).data(d).selection)
        panels(p).data(d).(maskType)(panels(p).data(d).selection)=value;
        panels(p).data(d).selection(1:end)=false;
    end
    % Saving deleted mask in Masks folder
    tmpDel=panels(p).data(d).(maskType);
    maskFileName=[const.MasksFolder panels(p).data(d).ID '_' maskType '.mat'];
    save(maskFileName,'tmpDel');
    disp([maskType ' mask saved to ' maskFileName ' with ' num2str(sum(tmpDel)) ' flagged samples out of ' num2str(length(tmpDel))]);
    updatePlot();
end