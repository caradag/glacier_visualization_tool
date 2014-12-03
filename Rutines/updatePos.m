function updatePos(source,eventdata,tZoomLims)
    global displayStatus fHandles
    persistent prevNpanels prevTLims prevTRange

    switch source
        case 'updatePlot'
            %################ INICIALIZATION AND VALIDATION ###############
            % If the limits to use on the current plot window are not defined
            if ~isfield(displayStatus,'tLims')
                % we intialize them as tRange (the whole dataset time range)
                displayStatus.tLims=displayStatus.tRange;
                % and apply to current window
                set(fHandles.axis,'XLim',displayStatus.tRange,'YLim',[0 displayStatus.nPanels]);
            end
            
            
            % ADJUSTING TIME LIMITS OF VIEW WINDOW
            if ~isempty(prevTRange) && ~all(prevTRange==displayStatus.tRange)
                disp('Chaged!!')
                displayStatus.tLims=displayStatus.tRange;
                %assesing situation between previous time limits in the plot and new tRange
                [wLims situation]=windowInRange(prevTLims,displayStatus.tRange);
                disp(situation)
                switch situation
                    case 'in'
                        % in: the previous time window inside new one
                        % -> in the new range we zoom to the previous time window
                        applyZoom(prevTLims);
                    case 'part'
                        % part: the previous time window cover part of the new tRange
                        % -> we zoom to the overlaping area (keeping the width of the window in time)
                        applyZoom(wLims);
                    case {'out','more'}
                        % out: the previous time window different than the new one
                        % -> we reset the view to the new tRange
                        % more: the previous time window included more to both sides than the new tRange
                        % -> we reset the view to the new tRange
                        displayStatus.tLims=displayStatus.tRange;
                end
            else
                % We retrive time limits from current window and correct them if not inside tRange
                displayStatus.tLims=windowInRange(diff(displayStatus.tLims),mean(displayStatus.tLims),displayStatus.tRange);
            end            
            prevTLims=displayStatus.tLims;
            prevTRange=displayStatus.tRange;
            
            % ADJUSTING NUMBER OF PANELS ON SCREEN VALUES AND CONTROL
            % If nPanelsOnScreen is not defined, out of range or nPanels has changed
            if ~isfield(displayStatus,'nPanelsOnScreen') || displayStatus.nPanelsOnScreen>displayStatus.nPanels || (~isempty(prevNpanels) && prevNpanels~=displayStatus.nPanels)
                % we initialize/reset to its maximum value = nPanels
                displayStatus.nPanelsOnScreen=displayStatus.nPanels;
            end
            
            % if there is only one panel we disable the vertical control
            if displayStatus.nPanels==1
                set(fHandles.nPanelsOnScreen,'Enable','off');
            else % But if there is more one panel we adjust values
                set(fHandles.nPanelsOnScreen,'Value',displayStatus.nPanelsOnScreen,'Min',1,'Max',displayStatus.nPanels,'SliderStep',[1/(displayStatus.nPanels-1) 1/(displayStatus.nPanels-1)],'Enable','on');
            end
            prevNpanels=displayStatus.nPanels;
            
            % ADJUSTING firstPanelShown (VERTICAL SCROLL) VALUES AND CONTROL
            if ~isfield(displayStatus,'firstPanelShown')
                displayStatus.firstPanelShown=0;
            end
                maxVal=displayStatus.nPanels-displayStatus.nPanelsOnScreen;
                if maxVal==0 %Case when all panels are displayed on screen
                    set(fHandles.vScroll,'Enable','off');
                else
                    displayStatus.nPanels
                    displayStatus.nPanelsOnScreen
                    displayStatus.firstPanelShown=min(displayStatus.firstPanelShown,maxVal);
                    set(fHandles.vScroll,'Value',displayStatus.firstPanelShown,'Max',maxVal,'SliderStep',[1/maxVal 1/maxVal],'Enable','on');
                end        
            %end
            
            applyDisplay();
            
        case fHandles.nPanelsOnScreen
            displayStatus.nPanelsOnScreen=get(fHandles.nPanelsOnScreen,'Value');
            maxVal=displayStatus.nPanels-displayStatus.nPanelsOnScreen;
            if displayStatus.firstPanelShown>maxVal
                set(fHandles.vScroll,'Value',maxVal);
                displayStatus.firstPanelShown=maxVal;
            end               
            if maxVal>0             
                set(fHandles.vScroll,'Max',maxVal,'SliderStep',[1/maxVal 1/maxVal],'Enable','on');
            else
                set(fHandles.vScroll,'Enable','off');
            end    
            applyDisplay();
            saveHistory();
            
        case fHandles.vScroll           
            displayStatus.firstPanelShown=get(fHandles.vScroll,'Value');     
            applyDisplay();
            saveHistory();
            
        case fHandles.hScroll
            % GETING RELATIVE POSITION OF THE CENTER OF THE VIEW WINDOW ON THE DATA TIME SPAN
            xp=get(fHandles.hScroll,'Value');

            %getting full data time span
            xwidthfull=diff(displayStatus.tRange);
            xwidth=diff(get(fHandles.axis,'XLim'));
            xcenter=xp*(xwidthfull-xwidth)+displayStatus.tRange(1)+xwidth/2;
            displayStatus.tLims=windowInRange(xwidth,xcenter,displayStatus.tRange);
            
            applyDisplay();
            saveHistory();
            
        case {fHandles.timeZoomButton, 'figureKeyPress'}
            if nargin<3
                tZoomLims=displayStatus.timeSel(:,1);
            end
            if numel(tZoomLims)==1
                hafWidth = inputdlg('Only one time reference (green lines) has been set. You can cancel and select a second reference or enter here the width of the window. (y,m,w are shorcuts for 365, 30 and 7 days)','Zoom window span',1,{'y'});
                if isempty(hafWidth)
                    return;
                end
                hafWidth=hafWidth{1};
                if isempty(str2num(hafWidth))
                    switch hafWidth
                        case {double('y'), double('Y')} %Y/y zoom a year around first click
                            tZoomLims=[-0.5 +0.5]*366+tZoomLims(1);
                        case {double('m'), double('M')} %M/m zoom a month around first click
                            tZoomLims=[-0.5 +0.5]*30+tZoomLims(1);
                        case {double('w'), double('W')} %W/w zoom a week around first click
                            tZoomLims=[-0.5 +0.5]*7+tZoomLims(1);
                        case {double('d'), double('D')} %D/d zoom a day around first click
                            tZoomLims=[-0.5 +0.5]*1+tZoomLims(1);
                        case {double('a'), double('A')} %A/a zoom to whole data set
                            tZoomLims=displayStatus.tRange;
                        otherwise
                            return;
                    end
                else
                    tZoomLims=[-0.5 +0.5]*str2num(hafWidth)+tZoomLims(1);
                end
            end
            if applyZoom(tZoomLims)
                applyDisplay();
                saveHistory();
            end
    end
%     % set focus to main figure
%     set(findobj(fHandles.browsefig, 'Type', 'uicontrol'), 'Enable', 'off');
%     drawnow;
%     set(findobj(fHandles.browsefig, 'Type', 'uicontrol'), 'Enable', 'on');
end
function applyDisplay()
    global displayStatus fHandles
    set(fHandles.axis,'YLim',[displayStatus.firstPanelShown displayStatus.firstPanelShown+displayStatus.nPanelsOnScreen]);
    set(fHandles.axis,'XLim',displayStatus.tLims);    
    if all(displayStatus.tLims==displayStatus.tRange)
        set(fHandles.hScroll,'Enable','off');
    else
        set(fHandles.hScroll,'Enable','on');
    end
end
function [wLims situation]=windowInRange(wWidth,center,range)
    
    % if there is only two inputs we assume they are two time ranges [min max]
    if nargin==2
        if numel(wWidth)<2
            error('Wrong number of inputs')
        end
        init=min(wWidth);
        fint=max(wWidth);
        range=center;
    % if there is three inputs we assume they are a width a center and a range
    elseif nargin==3
        init=center-wWidth/2;
        fint=center+wWidth/2;
    else
        error('Wrong number of inputs')
    end
    range=[min(range) max(range)];
    
    if all([init fint]<=range(1))
        %case window way to the left
        situation='out';
    elseif all([init fint]>=range(2))
        %case window way to the right
        situation='out';
    elseif all([init fint]==range)
        %case window equal to range
        situation='in';
    elseif init>=range(1) && fint<=range(2)
        %case window inside range
        situation='in';
    elseif init<=range(1) && fint>=range(2)
        %case window cover the whole range and maybe more
        situation='more';
    else
        %case window partially overlaps
        situation='part';
    end
    % if the window start to de left of the range:
    % we set the start of the window at the start of the range and move the
    % end of the window to keep the same width
    if init<range(1)
        fint=fint+range(1)-init;
        init=range(1);
    end
    % if the window end to de right of the range:
    % we set the end of the window at the end of the range and move the
    % start of the window to keep the same width
    if fint>range(2)
        init=init-(fint-range(2));
        fint=range(2);
    end
    % we double check init and fint are within range this could be because:
    % 1.- Window width is bigger than range width
    % 2.- Tiny differences due to rounding errors
    init=max(init,range(1));
    fint=min(fint,range(2));
    
    wLims=[init fint];
end


function status=applyZoom(tZoomLims)
    global displayStatus fHandles
    status=false;
    if numel(tZoomLims)==2
        tZoomLims=windowInRange(tZoomLims,displayStatus.tRange);
        xwidth=diff(tZoomLims);
        xcenter=mean(tZoomLims);
        
        xwidthfull=diff(displayStatus.tRange);
        if isnan(xwidthfull)
            warning('NaN time range!!!')
            return
        end
        if xwidth<(1/24)
            disp('Zoom range too small');
            return
        end
        
        xp=(xcenter-displayStatus.tRange(1)-(xwidth/2))/(xwidthfull-xwidth);
        xp=max(min(xp,1),0);
        if all(tZoomLims==displayStatus.tRange)
            set(fHandles.hScroll,'Enable','off');
        else
            set(fHandles.hScroll,'Value',xp,'SliderStep',[0.1 0.1]*(xwidth/xwidthfull),'Enable','on');
        end
        displayStatus.tLims=tZoomLims;
        status=true;
    end
end
