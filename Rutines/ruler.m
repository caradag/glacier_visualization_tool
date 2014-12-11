function [p d] = ruler(source,eventdata)
    persistent prevLine ;
    
    if isempty(prevLine)
        prevLine = selectedSensor();
        return
    else
        sensorDistance(prevLine,selectedSensor());
        prevLine=[];
    end
end

function sensorDistance(l1, l2)
    global panels
    p1=panels(l1(1)).data(l1(2)).pos;
    p2=panels(l2(1)).data(l2(2)).pos;
    d=sqrt((p1.east-p2.east)^2+(p1.north-p2.north)^2);
    dh=abs(p1.elev-p2.elev);
    ID1=panels(l1(1)).data(l1(2)).ID;
    ID2=panels(l2(1)).data(l2(2)).ID;
    msg=sprintf('Distance from %s to %s is %.2f meters and a height difference of %.1f meters.',ID1,ID2,d,dh);
    msgbox(msg,'Ruler');
    disp(msg);
end