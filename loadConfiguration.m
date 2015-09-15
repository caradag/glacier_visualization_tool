% Load configuration file subfunction
function conf=loadConfiguration()
    conf=struct;
    config;
    vars=who;
    for i=1:length(vars)
        if strcmp(vars{i},'conf') || strcmp(vars{i},'vars')
            continue;
        end
        conf.(vars{i})=eval(vars{i});
    end
    path(path,conf.routinesFolder);
    path(path,conf.imporExportFolder);
end