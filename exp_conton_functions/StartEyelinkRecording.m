function [tpre, tpost]=StartEyelinkRecording(thetrial,init,fileX,thescenepath,thephase,phasei,thepart,parti,t_fix,time)%change this if we only record during testing TBD

Eyelink('Message', 'TRIALID: %04d, NEWOLD: %d, ENCRET: %d, FIXX: %04d, FIXY %04d', thetrial, fileX.p2.(thepart{parti})(thetrial,3), fileX.p2.(thepart{parti})(thetrial,4), init.(thephase{phasei}).mx, init.(thephase{phasei}).my);
% an integration message so that an image can be loaded as
% overlay background when performing Data Viewer analysis.
WaitSecs(0.01);

Eyelink('Message', '!V IMGLOAD CENTER %s %d %d', fullfile('C:\Users\herweg\Documents\_Projekte\07_conton',char(regexp(thescenepath{thetrial},'\MR.+','match'))), init.(thephase{phasei}).mx, init.(thephase{phasei}).my);

% This supplies the title at the bottom of the eyetracker display
Eyelink('Command', 'record_status_message "Stim: %02d"', thetrial);

%Put the tracker offline and draw the stimuli.
Eyelink('Command', 'set_idle_mode');
WaitSecs(0.01);

%clear tracker display and draw box at center
Eyelink('Command', 'clear_screen %d', 0);

%draw the image on the screen
Eyelink('ImageTransfer',thescenepath{thetrial},round(init.(thephase{phasei}).mx-init.(thephase{phasei}).imgsizepix(2)/2), round(init.(thephase{phasei}).my-init.(thephase{phasei}).imgsizepix(1)/2), round(init.(thephase{phasei}).imgsizepix(2)), round(init.(thephase{phasei}).imgsizepix(1)),round(init.(thephase{phasei}).mx-init.(thephase{phasei}).imgsizepix(2)/2), round(init.(thephase{phasei}).my-init.(thephase{phasei}).imgsizepix(1)/2),0);    

%start recording following mode transition and a short pause.
Eyelink('Command', 'set_idle_mode');
WaitSecs(0.01);

WaitSecs('UntilTime',t_fix+time.p2.fix-0.3);
tpre = GetSecs;
Eyelink('StartRecording');
tpost = GetSecs;
