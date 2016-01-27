%Contextual Modulation of old/new effects%
%11-Jan-2016, n.herweg@uke.de

%% Initialization
%Timestamp
fileX.timestamp.(thephase{phasei}).(thepart{parti}) = datestr(now,30);

%Preallocation
thescene{n.(thephase{phasei}).(thepart{parti}).trials} = 0;
fileX.(thephase{phasei}).(thepart{parti})(n.(thephase{phasei}).(thepart{parti}).trials,19)=0;

%Counterbalance keys
key = counterkeys(init,fileX,thephase,phasei);

%Load images for first block
[thescenepath,thescene] = LoadStimuli(1,thephase,phasei,thepart,parti,thecat,n,fileX,init);

%Get text length to center text position
texttodraw{1,1} = 'Kurze Pause!';
texttodraw{2,1} = 'Achtung!';

for k = 1:size(texttodraw,1)
    [newx, ~]       = Screen('DrawText', init.(thephase{phasei}).expWin,texttodraw{k,1},init.(thephase{phasei}).mx, init.(thephase{phasei}).my, [0.5 0.5 0.5]);
    texttodraw{k,2} = init.(thephase{phasei}).mx-(newx-init.(thephase{phasei}).mx)/2;
    texttodraw{k,3} = init.(thephase{phasei}).my-60;
end
Screen('Close')

clear Inst insttexture trial newx newy k

%Create cover (needed due to incremental drawing of stimuli)
thecover = zeros(size(thescene{1}))+0.5;

%% Instruction
for k = inst2load.(thephase{phasei}).(thepart{parti})
    insttexture = Screen('MakeTexture',init.(thephase{phasei}).expWin,uint8(imread(fullfile(init.(thephase{phasei}).thepath.inst,['keycond',fileX.keycond],['Folie', num2str(k), '.png']))));
    Screen('DrawTexture',init.(thephase{phasei}).expWin,insttexture);
    Screen('Flip', init.(thephase{phasei}).expWin);
    Screen('Close')
    KbWait([], 2);
    clear insttexture
end

%Display the target
if strcmp(thephase{phasei},'p1')
    targstim  = unique(fileX.(thephase{phasei}).(thepart{parti})(fileX.(thephase{phasei}).(thepart{parti})(:,3)==1,[2,6]),'rows');
    targtrial{1} = fileX.(thephase{phasei}).(thepart{parti})(fileX.(thephase{phasei}).(thepart{parti})(:,2) == targstim(1,1) & fileX.(thephase{phasei}).(thepart{parti})(:,6) == targstim(1,2),1);
    targtrial{2} = fileX.(thephase{phasei}).(thepart{parti})(fileX.(thephase{phasei}).(thepart{parti})(:,2) == targstim(2,1) & fileX.(thephase{phasei}).(thepart{parti})(:,6) == targstim(2,2),1);
    targtexture = Screen('MakeTexture',init.(thephase{phasei}).expWin,[thescene{targtrial{1}(1)},uint8(ones(300,20,3).*255/2),thescene{targtrial{2}(1)}]);
    Screen('DrawTexture',init.(thephase{phasei}).expWin,targtexture);
    DrawFormattedText(init.(thephase{phasei}).expWin,'Dies sind deine Zielbilder. Dr�cke die Leertaste, sobald du eines dieser Bilder siehst!','center',init.(thephase{phasei}).my+200,[1 1 1]);
    t_targ = Screen('Flip', init.(thephase{phasei}).expWin);
    Screen('Close')
else
    t_targ = GetSecs-12;
end

if phasei == 2 && parti == 2 && strcmp(init.p2.hostname,'triostim')
%Wait for dummy scans
fileX.MRtiming.start = WaitPulse(init.mr.ndummy+1,init.(thephase{phasei}).device);%Waits for 6 dummys scans, the 7th is the first scan for analysis
end
if phasei ~= 3
%Create Queue for button presses
KbQueueCreate(init.(thephase{phasei}).device);%uses the default device
end

%Show fix cross
fixcross = Screen('MakeTexture',init.(thephase{phasei}).expWin,FixCr);
Screen('DrawTexture',init.(thephase{phasei}).expWin,fixcross);
t_fix = Screen('Flip', init.(thephase{phasei}).expWin,t_targ+12);
Screen('Close')

clear targstim targtrial targettexture t_targ

%% Start trial loop
for trial=1:n.p2.test.t2b*2%n.(thephase{phasei}).(thepart{parti}).trials
    
    %Break
    if (phasei==2 && rem(trial,n.(thephase{phasei}).test.tpb)==1 && trial>1) || (phasei ~= 2 && rem(trial,n.(thephase{phasei}).test.t2b)==1 && trial>1)%short break after every nth trial
        
        coverTexture                                        = Screen('MakeTexture',init.(thephase{phasei}).expWin,thecover);%cover the fixation cross
        Screen('DrawTexture',init.(thephase{phasei}).expWin,coverTexture);
        
        if rem(trial,n.(thephase{phasei}).test.t2b)==1
            Screen('DrawText', init.(thephase{phasei}).expWin, texttodraw{1,1},texttodraw{1,2},texttodraw{1,3}, [1 1 1]);
            fileX.(thephase{phasei}).(thepart{parti})(trial,11) = Screen('Flip', init.(thephase{phasei}).expWin, t_fix+time.(thephase{phasei}).fix-init.(thephase{phasei}).slack);%t_pause
        else
            fixcross = Screen('MakeTexture',init.(thephase{phasei}).expWin,FixCr);
            Screen('DrawTexture',init.(thephase{phasei}).expWin,fixcross);
            fileX.(thephase{phasei}).(thepart{parti})(trial,11) = Screen('Flip', init.(thephase{phasei}).expWin, t_fix+time.(thephase{phasei}).fix-init.(thephase{phasei}).slack);%t_pause
        end
        
        Screen('Close')
        clear t_fix %this has been saved during the end of the last trial
        
        if rem(trial,n.(thephase{phasei}).test.t2b)==1
            %Load images for next block (timing & memory issue)
            [thescenepath,thescene] = LoadStimuli(trial,thephase,phasei,thepart,parti,thecat,n,fileX,init);
            
            Screen('DrawText', init.(thephase{phasei}).expWin, texttodraw{2,1},texttodraw{2,2},texttodraw{2,3}, [1 1 1]);
            save(fullfile(init.(thephase{phasei}).thepath.results,fileX.fileName),'fileX');
            save(fullfile(init.(thephase{phasei}).thepath.results,[fileX.fileName(1:end-4),'_init.mat']),'init');
            Screen('Flip', init.(thephase{phasei}).expWin,fileX.(thephase{phasei}).(thepart{parti})(trial,11)+37-init.(thephase{phasei}).slack);
            Screen('Close')
            time2flip = 40;
        else
            time2flip = 20;
        end
        
        fixcross = Screen('MakeTexture',init.(thephase{phasei}).expWin,FixCr);
        Screen('DrawTexture',init.(thephase{phasei}).expWin,fixcross);
        t_fix    = Screen('Flip', init.(thephase{phasei}).expWin,fileX.(thephase{phasei}).(thepart{parti})(trial,11)+time2flip-init.(thephase{phasei}).slack);
        Screen('Close')
    end
    
    %Instruction
    if phasei == 2 && rem(trial,n.(thephase{phasei}).(thepart{parti}).tpb)==1 %if this is the first trial of a block in phase 2 show instruction for the next block
        
        insttexture                                         = Screen('MakeTexture',init.(thephase{phasei}).expWin,uint8(imread(fullfile(init.(thephase{phasei}).thepath.inst,['keycond',fileX.keycond],['Folie',num2str((9+fileX.(thephase{phasei}).(thepart{parti})(trial,4))),'.png']))));%4 encret 1 = enc; 2 = ret
        Screen('DrawTexture',init.(thephase{phasei}).expWin,insttexture);
        fileX.(thephase{phasei}).(thepart{parti})(trial,12) = Screen('Flip', init.(thephase{phasei}).expWin, t_fix+time.(thephase{phasei}).fix-init.(thephase{phasei}).slack);%t_instr
        Screen('Close')
        
        clear t_fix
                  
        fixcross = Screen('MakeTexture',init.(thephase{phasei}).expWin,FixCr);
        Screen('DrawTexture',init.(thephase{phasei}).expWin,fixcross);
        t_fix    = Screen('Flip', init.(thephase{phasei}).expWin,fileX.(thephase{phasei}).(thepart{parti})(trial,12)+3-init.(thephase{phasei}).slack);
        if parti == 2
        Eyelink('Message', 'FX Onset at %d %d',init.(thephase{phasei}).mx,init.(thephase{phasei}).my);
        end
        Screen('Close')
    end
    
    if phasei == 2 && parti == 2
    %Turn the eye tracker on prior to stimulus onset
    t_trackerOn = StartEyelinkRecording(trial,init,fileX,thescenepath,thephase,phasei,thepart,parti,t_fix,time);     
    end
    
    %Scene presentation
    scenetexture         = Screen('MakeTexture',init.(thephase{phasei}).expWin,thescene{trial});
    Screen('DrawTexture',init.(thephase{phasei}).expWin,scenetexture);
    [t_scene,sceneOnset] = Screen('Flip', init.(thephase{phasei}).expWin,t_fix+time.(thephase{phasei}).fix-init.(thephase{phasei}).slack,1);%show scene and keep it in the back buffer for presentation with analogue scale
    if phasei == 2 && parti == 2
    Eyelink('Message', 'Stim Onset');
    Eyelink('Message', 'SYNCTIME');
    end
    Screen('Close')
    clear scenetexture t_fix
    
    %Collect input
    if phasei ~= 3
        %start collecting input
        KbQueueStart(init.(thephase{phasei}).device);
    else
        SetMouse(init.(thephase{phasei}).mx,init.(thephase{phasei}).my+250,init.(thephase{phasei}).screenNumber);
        ShowCursor('Hand');
        
        VASscale_mouse(init,0,fileX.keycond);
        
        while GetSecs<sceneOnset+time.(thephase{phasei}).pic
            [Xmouse,Ymouse,Bmouse]         = GetMouse(init.(thephase{phasei}).expWin);
            if Bmouse(1) && ~exist('rating','var')%rating does not exist at first call because no rating output is queried above
                while Bmouse(1) && GetSecs<sceneOnset+time.(thephase{phasei}).pic %check position until mouse button is released again and keep that final position
                    [Xmouse,Ymouse,Bmouse] = GetMouse(init.(thephase{phasei}).expWin);
                    rating                 = VASscale_mouse(init,Xmouse,fileX.keycond);
                end
                if exist('rating','var') && ~Bmouse(1)
                    fin                    = GetSecs; %rating is finished
                end
            end
        end
    end
    
    %Scene offset
    coverTexture = Screen('MakeTexture',init.(thephase{phasei}).expWin,thecover);%cover image in the backbufer to display just the fix cross (and rating scale) with next flip
    fixcross     = Screen('MakeTexture',init.(thephase{phasei}).expWin,FixCr);
    Screen('DrawTextures',init.(thephase{phasei}).expWin,[coverTexture,fixcross]);
    t_fix        = Screen('Flip', init.(thephase{phasei}).expWin,t_scene+time.(thephase{phasei}).pic-init.(thephase{phasei}).slack, 1);
    if phasei == 2 && parti == 2
    Eyelink('Message', 'FX Onset at %d %d',init.(thephase{phasei}).mx,init.(thephase{phasei}).my);         
    %record some more eye data after stimulus offset
    WaitSecs('UntilTime',t_fix+time.trackerOff);
    t_trackerOff    = StopEyelinkRecording;
    end
    Screen('Close')
    
    %If necessary go on collecting input
    if phasei == 3 && exist('rating','var') && ~exist('fin','var') % if rating has been started but not finished
        while Bmouse(1) && GetSecs<sceneOnset+time.(thephase{phasei}).resp %check position until mouse button is released again and keep that final position
            [Xmouse,Ymouse,Bmouse] = GetMouse(init.(thephase{phasei}).expWin, Xmouse);
            rating                 = VASscale_mouse(init,Xmouse,fileX.keycond);
        end
        if exist('rating','var') && ~Bmouse(1)
            fin                    = GetSecs; %rating is finished
        end
    elseif phasei == 3 && ~exist('rating','var') % if rating has not been started
        
        VASscale_mouse(init,0,fileX.keycond);
        
        while GetSecs<sceneOnset+time.(thephase{phasei}).resp
            [Xmouse,Ymouse,Bmouse]         = GetMouse(init.(thephase{phasei}).expWin);
            if Bmouse(1) && ~exist('rating','var')
                while Bmouse(1) && GetSecs<sceneOnset+time.(thephase{phasei}).resp %check position until mouse button is released again and keep that final position
                    [Xmouse,Ymouse,Bmouse] = GetMouse(init.(thephase{phasei}).expWin);
                    rating                 = VASscale_mouse(init,Xmouse,fileX.keycond);
                end
                if exist('rating','var') && ~Bmouse(1)
                    fin                    = GetSecs; %rating is finished
                    break
                end
            end
        end
    end

    WaitSecs('UntilTime',t_fix+time.(thephase{phasei}).resp);
    [keyIsDown, firstPress, firstRelease, lastPress, lastRelease] = KbQueueCheck(init.(thephase{phasei}).device);
    KbQueueStop(init.(thephase{phasei}).device);%Although a call to KbQueueStart should suffice to flush a queue that is not actively receiving events, KbQueueFlush should be used preferentially to flush events from an actively running queue. 
    KbQueueFlush(init.(thephase{phasei}).device);
 
    %Save everything
    fileX.(thephase{phasei}).(thepart{parti})(trial,13) = t_fix;
    fileX.(thephase{phasei}).(thepart{parti})(trial,14) = t_scene;
    
    if phasei == 2 && parti == 2
    fileX.(thephase{phasei}).(thepart{parti})(trial,15) = t_trackerOn;
    fileX.(thephase{phasei}).(thepart{parti})(trial,16) = t_trackerOff;
    
    %Erase pulses from button press data
    firstPress(KbName('5%'))   = 0;
    firstRelease(KbName('5%')) = 0;
    lastPress(KbName('5%'))    = 0;
    lastRelease(KbName('5%'))  = 0;
    if size(find(firstPress),2) == 0
        keyIsDown = 0;
    end
    end
    
    if (phasei == 3 && ~exist('fin','var')) || (phasei ~= 3 && keyIsDown == 0) %if still no button has been pressed
        fileX.(thephase{phasei}).(thepart{parti})(trial,8)  = NaN;%no response
    elseif phasei ~=3 && size(find(firstPress),2) == 1
        fileX.(thephase{phasei}).(thepart{parti})(trial,8)  = find(firstPress);
        fileX.(thephase{phasei}).(thepart{parti})(trial,9)  = firstPress(find(firstPress));%RT
        fileX.(thephase{phasei}).(thepart{parti})(trial,10) = firstPress(find(firstPress))-sceneOnset;%reaction time
    elseif phasei == 3 && exist('fin','var')
        fileX.(thephase{phasei}).(thepart{parti})(trial,8)  = rating;% -1 certainly old, 1 certainly new
        fileX.(thephase{phasei}).(thepart{parti})(trial,9)  = fin;
        fileX.(thephase{phasei}).(thepart{parti})(trial,10) = fin-sceneOnset;%reaction time
    elseif phasei ~= 3
        fileX.(thephase{phasei}).(thepart{parti})(trial,8)  = 888;%two buttons
    end
    
    clearvars -except fileX FixCr init inst2load key n parti phasei relnew t_fix thecat thecond thepart thescene time trial thephase texttodraw thecover thescenepath
    thescene{trial}=[];
end

if phasei == 2 && parti == 2
    %Wait for last scans and shut down eyelink
    if strcmp(init.p2.hostname,'triostim')
        disp('Waiting for dummy pulses...');
        fileX.MRtiming.end = WaitPulse(KbName('5%'),init.mr.ndummy+1);
    end
    try
        disp('Trying to stop the Eyelink system with StopEyelink');
        Eyelink('StopRecording');
        WaitSecs(0.5);
        Eyelink('Closefile');
        disp('receiving the EDF file...');
        Eyelink('ReceiveFile',[fileX.fileName(8:end-3),'edf'],init.(thephase{phasei}).thepath.results,1);
        disp('...finished!')
        % Shutdown Eyelink:
        Eyelink('Shutdown');
    catch
        disp('StopEyeLink routine didn''t really run well');
    end
end

%% Finish this phase
save(fullfile(init.(thephase{phasei}).thepath.results,fileX.fileName),'fileX');
save(fullfile(init.(thephase{phasei}).thepath.results,[fileX.fileName(1:end-4),'_init.mat']),'init');

Screen('Flip', init.(thephase{phasei}).expWin);
if parti == 1;
    RestrictKeysForKbCheck(KbName('c'));
    insttexture = Screen('MakeTexture',init.(thephase{phasei}).expWin,uint8(imread(fullfile(init.(thephase{phasei}).thepath.inst,['keycond',fileX.keycond],'Folie12.png'))));
else
    RestrictKeysForKbCheck(KbName('m'));
    insttexture = Screen('MakeTexture',init.(thephase{phasei}).expWin,uint8(imread(fullfile(init.(thephase{phasei}).thepath.inst,['keycond',fileX.keycond],'Folie13.png'))));
end
Screen('DrawTexture',init.(thephase{phasei}).expWin,insttexture);
Screen('Flip', init.(thephase{phasei}).expWin);
Screen('Close')

KbWait([], 2);
RestrictKeysForKbCheck([]);

clearvars -except fileX FixCr init inst2load key n parti phasei relnew thecat thecond thepart time thephase