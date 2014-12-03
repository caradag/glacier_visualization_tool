                        filename_read='TOA5_15945.OnIceLgr.dat'
                        chan_read=1;
                        monthlength = cumsum([0 31 28 31 30 31 30 31 31 30 31 30]);
                        monthlength_leap = cumsum([0 31 29 31 30 31 30 31 31 30 31 30]);
                        [timestamp_str,dummy,battvolt_str,temp_str,press1,press2,press3,press4,press5,press6]=...
                            textread(filename_read,'%s %u %s %s %s %s %s %s %s %s', 'delimiter', ',','emptyvalue',NaN,'headerlines',4);
                        press_str=[press1,press2,press3,press4,press5,press6];                        
                        press_str=press_str(:,chan_read);
                        n_data_in=length(timestamp_str)
                        year=zeros(n_data_in,1);
                        day=zeros(n_data_in,1);
                        time=zeros(n_data_in,1);
                        battvolt=zeros(n_data_in,1);
                        temp=zeros(n_data_in,1);
                        press=zeros(n_data_in,1);
                        for ii=1:n_data_in
                            time_temp=timestamp_str{ii}
                            year(ii)=str2num(time_temp(2:5));
                            month_temp=str2num(time_temp(7:8));
                            day_temp=str2num(time_temp(10:11));
                            if mod(year(ii),4==0)
                                day(ii)=monthlength_leap(month_temp)+day_temp;
                            else
                                day(ii)=monthlength(month_temp)+day_temp;
                            end
                            time(ii)=str2num(time_temp([13:14 16:17]));
                            if strcmp(battvolt_str{ii},'"NAN"')
                                battvolt(ii)=NaN;
                            else
                                battvolt(ii)=str2num(battvolt_str{ii});
                            end
                            if strcmp(temp_str{ii},'"NAN"')
                                temp(ii)=NaN;
                            else
                                temp(ii)=str2num(temp_str{ii});
                            end
                            if strcmp(press_str{ii},'"NAN"')
                                press(ii)=NaN;
                            else
                                ii
                                press_str{ii}
                                str2num(press_str{ii})
                            press(ii)=str2num(press_str{ii});
                            end
                        end
