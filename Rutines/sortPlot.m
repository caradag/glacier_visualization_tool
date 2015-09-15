function sortPlot(source,eventdata,mode)
%sortPlot sort the panels plot by row or colum of the first line plot on it
global panels metadata

nPanels=length(panels);
RowCol=zeros(nPanels,2);
for p=1:nPanels
    %Geting grid of the first data in teh panel
    grid=metadata.sensors.(panels(p).data(1).ID).grid;
    %replacing underscores by points
    grid(grid=='_')='.';
    grid(grid=='C')=' ';
    grid(grid=='R')=' ';
    RowCol(p,1:2)=eval(['[' grid ']']);
end

switch mode
    case 'R'
        [~, order]=sort(RowCol(:,1),'descend');
    case 'C'
        [~, order]=sort(RowCol(:,2),'descend');
end

panels=panels(order);
updatePlot;
disp('Sorting done');
end

