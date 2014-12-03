function [p d] = selectedSensor(source,eventdata,panelIdx)
    global panels
    [p d] = getSelection();
    % if panelIdx is not given we just return the current selection 
    if nargin<3
        return;
    end    
    
    % if there is a selected line we unselect it
    if ~isempty(p) && ~isempty(d)
        panels(p).data(d).selected=false;
        % There is lineHandle data
        if isfield(panels(p).data(d),'lineHandle')
            % We iterate over all the handles (usually one per section)
            for i=1:length(panels(p).data(d).lineHandle)
                % And an individual hadle is valid
                if ishandle(panels(p).data(d).lineHandle(i))
                    % We set the LineWidth to 1
                    set(panels(p).data(d).lineHandle(i),'LineWidth',1);
                end
            end
        end
        p=[];
        d=[];
    end
    
    % if panelIdx is empty we exit after unselecting surrent selection
    if isempty(panelIdx)
        displayMap();
        return        
    end
    
    % if there is panelIdx and has the right size, we select the corresponding panel
    if nargin==3 && numel(panelIdx)>=2
        p=panelIdx(1);
        d=panelIdx(2);
        s=1;
        if numel(panelIdx)>2
            s=panelIdx(3);
        end
        panels(p).data(d).selected=true;
        if isfield(panels(p).data(d),'lineHandle')
            set(panels(p).data(d).lineHandle(s),'LineWidth',2);
        end
        yAxis(p,d);
    end
    displayMap();
    setYAxis();
end

function [panel idx] = getSelection()
% Return the panel and data index of the selected time serie
    global panels
    npanels=length(panels);
    % If there is only one time series we return that one no mater if is selected or not
    if npanels==1 && length(panels.data)==1
        panel=1;
        idx=1;
        return
    end
    % We now find which panel is selected
    panel=[];
    idx=[];
    for p=1:npanels
        nDataFields=length(panels(p).data);
        for d=1:nDataFields
            if panels(p).data(d).selected==true;
                panel=p;
                idx=d;
            end
        end
    end
end