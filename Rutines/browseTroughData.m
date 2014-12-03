function browseTroughData(source,eventdata,jump)
    global panels gps fHandles metadata displayStatus const
    
    % finding selected data serie
    [p d]=selectedSensor();
    if numel([p d])==2
        type=panels(p).data(d).type;
        ID=panels(p).data(d).ID;

        % setting the right list depending on data type
        switch type
            case 'sensors'
                list=fieldnames(metadata.sensors);
            case 'gps'
                list=fieldnames(gps);
            otherwise
                return
        end
        % finding position of current sensor in list
        maxPos=length(list);
        pos=find(strcmp(ID,list));
        % jumping in the list to the next data serie
        for i=1:maxPos
            pos=mod(pos+(sign(jump)*i)-1,maxPos)+1;
            if any(strcmp(metadata.sensors.(list{pos}).flag,const.sensorFlags) & displayStatus.sensorFlags)
                break;
            end
        end

        % assigning new data serie to panel element and recomputing values
        for i=1:length(panels(p).data)
            if strcmp(panels(p).data(i).ID,ID)
                panels(p).data(i).ID=list{pos};
                panels(p).data(i).yData=[];
                %panels(p).data(i).normMode=[];
                panels(p).data(i).filter=[];
                if strcmp(panels(p).data(i).variable,'pressure')
                    panels(p).data(i).selected=1;
                else
                    panels(p).data(i).selected=0;
                end
                panels(p).data(i).style=[];
            end
        end
        set(fHandles.cursorInfo,'String',['Sensor: ' ID]);
        updatePlot();
        figureKeyPress([],[],[],[],'o')
    end
end