function outPanels=unpopulatePanels(panels)
%unpopulatePanels Remove time series data to panels structure
%   unpopulatePanels browse trough the panels structure and remove data leaving only info and structure
global const
    outPanels=[];
    for p=1:length(panels)
        for d=1:length(panels(p).data)
           outPanels(p).data(d)=removeField(panels(p).data(d),[{'yData','time','sections','breakes','norm2y','y2norm','lines','pos','lineHandle'}, const.dataMasks]);
        end
    end    
end
function s = removeField(s,fields)
    for i=1:length(fields)
        if isfield(s,fields{i})
            s=rmfield(s,fields{i});
        end
    end
end
