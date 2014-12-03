function swapPanels(source,eventdata,idx1,idx2)
global panels
%swapPanels swap the position of two panel
%   Swap the position of the panel at panels structure index idx1 with the
%   one at position idx2
%   If any of the indexes is empty, the panel at the other index is deleted

% if idx1 and idx2 are 1x2 arrays, the second element is considered the data
% field to swap with

% if idx1 and idx2 are equal we do nothing
if numel(idx1)==numel(idx2) && all(idx1(:)==idx2(:))
    return;
end

%we put in idx1 the first non empty index
if isempty(idx1)
    idx1=idx2;
    idx2=[];
end

if length(idx1)==1
    if isempty(idx2)
        panels(idx1)=[];
    else
        temp=panels(idx2);
        panels(idx2)=panels(idx1);
        panels(idx1)=temp;
    end
elseif length(idx1)==2
    if isempty(idx2)
        if isempty(panels(idx1(1)).data)
            panels(idx1(1))=[];
        else
            panels(idx1(1)).data(idx1(2))=[];
            if isempty(panels(idx1(1)).data)
                panels(idx1(1))=[];
            end
        end
    else
        temp=panels(idx2(1)).data(idx2(2));
        panels(idx2(1)).data(idx2(2))=panels(idx1(1)).data(idx1(2));
        panels(idx1(1)).data(idx1(2))=temp;
    end    
else
    error('Both indexed are empty or the wrong size');
end
if ishandle(source)
    updatePlot;
end
end

