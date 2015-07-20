function [p]=exp_AmbiPilot(subject,noise)
%[p]=exp_AmbiPilot(subject,csp,PainThreshold,nth)
%
%   Experiment for showing ambigous pictures to people :D.
%

%% %init all the variables
%Time Storage
TimeEndStim               = [];
TimeTrackerOff            = [];
TimeCrossOn               = [];
p_var_ExpPhase            = [];
p_var_event_count         = 0;
t                         = [];
nTrial                    = 0;
el                        = [];
p                         = [];
%
%% ListenChar(2);%disable pressed keys to be spitted around
commandwindow;
%clear everything
clear mex global functions
%%%%%%%%%%%load the GETSECS mex files so call them at least once
GetSecs;
WaitSecs(0.001);
%
SetParams;
debug = 1;%debug mode
SetPTB;

%%
InitEyeLink;
WaitSecs(2);
%calibrate if necessary
if strcmp(p.hostname,'etpc');
    CalibrateEL;
end
%save again the parameter file
save(p.path.path_param,'p');
%% RUN THE EXPERIMENT PROPER
% ShowInstruction(1,1);
% ShowInstruction(2,1);
PresentStimuli;
%%
%get the eyelink file back to this computer
StopEyelink(p.path.edf);

save(p.path.path_param,'p');
%
%move the file to its final location.
movefile(p.path.subject,p.path.finalsubject);
%close everything down
cleanup;


    function PresentStimuli
        %Enter the presentation loop and wait for the first pulse to
        %arrive.

        
        for nTrial  = 1:p.presentation.tTrial;
            %
            %stim_id is the image shown.
            stim_id  = p.presentation.stim_id(nTrial);            
            %                        
            fprintf('=======================\nTRIAL: %03d (%03d)\nImage being shown: %s\n',nTrial,p.presentation.tTrial,p.stim.files(stim_id,:));
            %                                    
            KbQueueStart(p.ptb.device);%monitor keypresses...
            
            %Start with the trial, here is time-wise sensitive must be
            %optimal
            Trial(nTrial, stim_id );
            %
            ShowInstruction(3,1);
            %
            AskStimRating;
            %
            [keypressed, firstPress]=KbQueueCheck(p.ptb.device);
            
            
        end
    end
    function Trial(nTrial, stim_id )
        
        %turn the eye tracker on
        StartEyelinkRecording(nTrial,stim_id);
        WaitSecs(.25);
        %% Fixation Onset        
        Screen('FillRect',  p.ptb.w, [255,255,255], p.presentation.FixCross);        
        Screen('Flip',p.ptb.w);        
        Eyelink('Message', 'FX Onset');
        WaitSecs(1.25);
        %        
        p.ptb.imrect  = [ p.ptb.midpoint(1)-p.stim.size(stim_id,2)/2 p.ptb.midpoint(2)-p.stim.size(stim_id,1)/2 p.stim.size(stim_id,2) p.stim.size(stim_id,1)];               
        %% send eyelink the marker
        Eyelink('Message', 'Stim Onset');
        Eyelink('Message', 'SYNCTIME');
        %% Draw the stimulus to the buffer
        keep = 1;
        p.out.StimOnset(nTrial) = GetSecs;
        while keep
            ShowStim;
            [keyIsDown, secs, keyCode,deltaSecs]               = KbCheck([]);
            keyCode = find(keyCode);
            if length(keyCode) == 1%this loop avoids crashes to accidential presses of meta keys
                if (keyCode == p.keys.confirm) 
                    keep                            = 0;
                    p.out.PressingTime(nTrial)      = secs;            
                    p.out.PressingTime_CI(nTrial)   = deltaSecs;
                    Eyelink('Message', 'KeyPressed');
                    Screen('Flip',p.ptb.w);
                    %send eyelink a marker
                    Eyelink('Message', 'Stim Offset');
                    Eyelink('Message', 'BLANK_SCREEN');
                end
            end                                            
        end
        %        
        %% STIM OFF immediately after key press        
        WaitSecs(.3);                
        %% record some more eye data after stimulus offset.
        StopEyelinkRecording;
        
        function ShowStim()
            
            [~, R2]        = histc(rand(p.stim.t_pixel(stim_id),1),cumsum([0;p.ptb.NoiseWeight(:)./sum(p.ptb.NoiseWeight)]));
            image          = p.stim.image{stim_id}(:,:);
            size(image)
            image(R2 == 2) = 0;
            image(R2 == 3) = 1;                        
            B = Screen('MakeTexture', p.ptb.w, double(image)*255);
            Screen('DrawTexture', p.ptb.w, B);            
%             Screen('DrawingFinished',p.ptb.w,0);
            % STIMULUS ONSET            
            Screen('Flip',p.ptb.w);%asap and dont clear            
        end
    end
    
    function SetParams
        
        %
        p.var.timings                 = zeros(1,10);
        p_var_event_count             = 0;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        %relative path to stim and experiments
        %Path Business.
        [~, hostname] = system('hostname');
        p.hostname                    = deblank(hostname);
        if strcmp(p.hostname,'triostim1')
            p.path.baselocation       = 'C:\USER\onat\Experiments\';
        elseif strcmp(p.hostname,'etpc')
            p.path.baselocation       = 'C:\Users\onat\Documents\Experiments\';
        else
            p.path.baselocation       = '~/Documents/BehavioralExperiments/2015_Ambipilote/';
        end
        
        p.path.experiment             = [p.path.baselocation 'AmbiPilot' filesep];
        p.path.stim                   = '~/Dropbox/SelimTimTim/AmbiPain/stimulus_selection/';
        %
        p.subID                       = sprintf('sub%02d',subject);
        p.path.edf                    = sprintf(p.subID);
        timestamp                     = datestr(now,30);
        p.path.subject                = [p.path.experiment 'data' filesep 'tmp' filesep p.subID '_' timestamp filesep];
        p.path.finalsubject           = [p.path.experiment 'data' filesep p.subID '_' timestamp filesep ];
        %create folder hierarchy
        mkdir(p.path.subject);
        mkdir([p.path.subject 'scr']);
        mkdir([p.path.subject 'eye']);
        mkdir([p.path.subject 'stimulation']);
        mkdir([p.path.subject 'midlevel']);
        p.path.path_param             = sprintf([p.path.subject, 'stimulation/param']);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        %get stim files
        [p.stim.files p.stim.label]   = FileMatrix([p.path.stim '*.png']);
        p.stim.tFile                  = size(p.stim.files,1);%number of different files (including the UCS symbol)        
        %
        display([mat2str(p.stim.tFile) ' found in the destination.']);
        %is all the captured bg values the same?
        
        p.stim.bg                   = 0;
        %
        %font size and background gray level
        p.text.fontname                = 'Times New Roman';
        p.text.fontsize                = 30;
        p.text.fixsize                 = 60;
        %
        p.stim.white                   = [255 255 255];
        %get the actual stim size (assumes all the same)        
        if strcmp(p.hostname,'triostim1')
            p.keys.confirm                 = KbName('7');
            p.keys.increase                = KbName('8');
            p.keys.decrease                = KbName('6');
            p.keys.space                   = KbName('space');
            p.keys.esc                     = KbName('esc');
        elseif ismac
            %All settings for laptop computer.
            p.keys.confirm                 = KbName('UpArrow');
            p.keys.increase                = KbName('RightArrow');
            p.keys.decrease                = KbName('LeftArrow');
            p.keys.space                   = KbName('space');
            p.keys.esc                     = KbName('ESCAPE');
        else
            p.keys.confirm                 = KbName('up');
            p.keys.increase                = KbName('right');
            p.keys.decrease                = KbName('left');
            p.keys.space                   = KbName('space');
            p.keys.esc                     = KbName('esc');
        end        
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %timing business
        %these are the intervals of importance
        %time2fixationcross->cross2onset->onset2shock->shock2offset
        %these (duration.BLA) are average duration values:
        p.duration.stim                = 5;%2;%s
        p.duration.keep_recording      = 0.25;%this is the time we will keep recording (eye data) after stim offset.
        p.duration.prestim_ori         = .95;        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %stimulus sequence                                
        p.presentation.repetition              = 10;
        p.presentation.tTrial                  = p.stim.tFile*p.presentation.repetition;        
        p.presentation.stim_id                 = Shuffle(repmat(1:p.stim.tFile,1,p.presentation.repetition));                
        
        
        p.rating.division                      = 5;
        %Save the stuff
        save(p.path.path_param,'p');
        %
        function [FM labels] = FileMatrix(path)
            %Takes a path with file extension associated to regexp (e.g.
            %C:\blabl\bla\*.bmp) returns the file matrix
            cd(fileparts(path))
            dummy = dir(path);
            FM    = strvcat(dummy(:).name);
            labels = {dummy(:).name};
        end
    end
    function ShowInstruction(nInstruct,waitforkeypress)
        %ShowInstruction(nInstruct,waitforkeypress)
        %if waitforkeypress is 1, then subject has to press a button to
        %make the instruction text dissappear. Otherwise you have to take
        %care of it later
        
        [text]= GetText(nInstruct);
        ShowText(text);
        %let subject read it and ask confirmation to proceed. But we don't
        %need that in the case of INSTRUCT = 5;
        if waitforkeypress
            if nInstruct ~= 10%this is for the Reiz kommnt
                KbStrokeWait;
            else
                WaitSecs(2.5+rand(1));
            end
            Screen('FillRect',p.ptb.w,p.stim.bg);
            t = Screen('Flip',p.ptb.w);            
        else
            if nInstruct ~= 10%this is for the Reiz kommnt
                KbStrokeWait;
            else
                WaitSecs(1+rand(1));
            end
        end
        
        
        function ShowText(text)
            
            Screen('FillRect',p.ptb.w,p.stim.bg);
            %DrawFormattedText(p.ptb.w, text, p.text.start_x, 'center',p.stim.white,[],[],[],2,[]);
            DrawFormattedText(p.ptb.w, text, 'center', 'center',p.stim.white,[],[],[],2,[]);
            t=Screen('Flip',p.ptb.w);                        
            %show the messages amaskt the experimenter screen            
            fprintf('Text shown to the subject:\n');            
            fprintf(text);            
        end
    end
    function [text]=GetText(nInstruct)
        if nInstruct == 0%Eyetracking calibration
            
            text = ['Um Ihre Augenbewegungen zu messen, \n' ...
                'm�ssen wir jetzt den Eye-Tracker kalibrieren.\n' ...
                'Dazu zeigen wir Ihnen einige Punkte auf dem Bildschirm, \n' ...
                'bei denen Sie sich wie folgt verhalten:\n' ...
                'Bitte fixieren Sie den kleinen wei�en Kreis und \n' ...
                'bleiben so lange darauf, wie es zu sehen ist.\n' ...
                'Bitte dr�cken Sie jetzt den oberen Knopf, \n' ...
                'um mit der Kalibrierung weiterzumachen.\n' ...
                ];
            
        elseif nInstruct == 1%first Instr. of the training phase.
            text = ['Herzlich Willkommen bei unserer Studie.\n' ...
                    'Bevor wir mit dem Experiment beginnen, einige Hinweise zum weiteren Ablauf.\n'...
                    'Die Steuerung des Experiments erfolgt mit 3 Tasten;\n'...
                    'Die ''Pfeiltaste oben'' entspricht weiter, links=ja und rechts=nein.\n'...
                    'Bitte drueck nun "Pfeiltaste oben" um zum naechsten Bildschirm zu kommen.\n'];
        
        
        elseif nInstruct == 2%second Instr. of the training phase.
            text = ['Du wirst gleich eine Reihe von Bildern gezeigt bekommen.\n'...
            'Bitte druecke die ''Pfeiltaste oben'' (weiter), sobald du etwas in dem Bild erkennst.\n'...
            '\n'...
            'Bitte sag uns im Anschluss daran, was du gesehen hast,\n'...
            'und wie sicher du dir mit deiner Erkennung bist.\n'...
            'Fuer die letzte Frage, benutze bitte die Tasten "rechts", "links" fuer deine Antwort.\n'...
            '\n'...
            'Bevor es jedoch mit dem Experiment losgeht, werden wir zuerst ein paar Probedurchlaeufe machen.\n'...
            '\n'...
            '(weiter mit der Pfeiltaste oben)\n'];
                
        elseif nInstruct == 3%third Instr. of the training phase.
            text = ['Bitte sag uns was du gesehen hast! (danach weiter mit der ''Pfeiltaste oben'')\n'];
            
        elseif nInstruct == 4%third Instr. of the training phase.
            text = ['Vielen Dank. Das waren die Probedurchgaenge.\n'...
                'Jetzt kommen wir zum Experiment. Der Ablauf ist genau wie in den Probedurchgaengen.\n'...
                '\n'...
                'Hast du noch Fragen, bevor wir mit dem Experiment beginnen?\n'...
                '\n'...
                '\n'...
                '(''Pfeiltaste oben'' zum Start des Experiments)\n'];                   
                        
        elseif nInstruct == 11;%rating
            text = ['Wie sicher bist Du dir auf einer Skala von 1-5?\n'];
                    
        elseif nInstruct == 12 %These two below are the possible responses to the question in 11
            text = {'sehr unsicher'};
        elseif nInstruct == 13
            text = {'sehr sicher'};
        elseif nInstruct == 14
            text = ['Bitte machen Sie eine kurze Pause.\n' ...
                'Sie k�nnen hierbei gern die Augen einen Moment schlie�en.\n'...
                'Dr�cken Sie anschlie�end die obere Taste um fortzufahren.\n'...
                'Wir werden dann den Eyetracker noch einmal kalibrieren.\n'...
                ];
        else
            text = {''};
        end
    end
    function SetPTB
        %Sets the parameters related to the PTB toolbox. Including
        %fontsizes, font names.
        %Find the number of the screen to be opened
        screens                     =  Screen('Screens');
        p.ptb.screenNumber          =  0;%the maximum is the second monitor
        %Make everything transparent for debugging purposes.
        if debug
            commandwindow;
            PsychDebugWindowConfiguration;
        end
        %Default parameters
        Screen('Preference', 'SkipSyncTests', 1);
        Screen('Preference', 'DefaultFontSize', p.text.fontsize);
        Screen('Preference', 'DefaultFontName', p.text.fontname);
        Screen('Preference', 'TextAntiAliasing',2);%enable textantialiasing high quality
        Screen('Preference', 'VisualDebuglevel', 0);
        Screen('Preference', 'SkipSyncTests', 1);
        Screen('Preference', 'SuppressAllWarnings', 1);
        %set the resolution correctly
        if strcmp(p.hostname,'triostim1')
            p.ptb.oldres = Screen('resolution',p.ptb.screenNumber,1280,960);
            %hide the cursor
            HideCursor(p.ptb.screenNumber);
        elseif strcmp(p.hostname,'etpc')
            p.ptb.oldres = Screen('resolution',p.ptb.screenNumber,1600,1200);
            %hide the cursor
            HideCursor(p.ptb.screenNumber);
        end
        
        %Open a graphics window using PTB
        p.ptb.w                     = Screen('OpenWindow', p.ptb.screenNumber, p.stim.bg);
        Screen('BlendFunction', p.ptb.w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        Screen('Flip',p.ptb.w);%make the bg
        p.ptb.slack                 = Screen('GetFlipInterval',p.ptb.w)./2;
        [p.ptb.width, p.ptb.height] = Screen('WindowSize', p.ptb.screenNumber);
        if sum([p.ptb.width p.ptb.height] - [1280 960]) ~= 0
            fprintf('SET THE CORRECT SCREEN RESOLUTION\n');
        end
        %find the mid position on the screen.
        p.ptb.midpoint              = [ p.ptb.width./2 p.ptb.height./2];
        p.ptb.CrossPosition_x       = p.ptb.midpoint(1);%bb(1);%always the same                
        [nx, ny bb]                 = DrawFormattedText(p.ptb.w,'+','center','center');
        p.presentation.CrossPosition           = p.ptb.midpoint;
        fix                                    = p.presentation.CrossPosition;%just for readability
        p.presentation.FixCross                = [fix(1)-1,fix(2)-20,fix(1)+1,fix(2)+20;fix(1)-20,fix(2)-1,fix(1)+20,fix(2)+1]';
        
        %%
        %priorityLevel=MaxPriority(['GetSecs'],['KbCheck'],['KbWait'],['GetClicks']);
        Priority(MaxPriority(p.ptb.w));
        %this is necessary for the Eyelink calibration
        InitializePsychSound(0)
        %sound('Open')
        Beeper(5000)                
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%Prepare the keypress queue listening.
        p.ptb.device        = -1;
        p.ptb.keysOfInterest=zeros(1,256);
        p.ptb.keysOfInterest(p.keys.confirm) = 1;
        KbQueueCreate(p.ptb.device,p.ptb.keysOfInterest);%default device.
        
        p.ptb.noise = noise;        
        p.ptb.NoiseWeight = [1-p.ptb.noise p.ptb.noise./2 p.ptb.noise./2];
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        %load the pictures to the memory.
        p.ptb.stim_sprites = CreateStimSprites(p.stim.files);%
        
        function [out]=CreateStimSprites(files)
            %loads all the stims to video memory
            for nStim = 1:p.stim.tFile
                filename       = files(nStim,:);
                [im , ~, ~]    = imread(deblank(filename));                
                im             = double(im)./255;
                if size(im,3) == 1
                    im = repmat(im,[1 1 3]);
                end
                out(nStim)               = Screen('MakeTexture', p.ptb.w, im );
                p.stim.size(nStim,:)     = size(im);
                p.stim.image{nStim}(:,:) = logical(im(:,:,1));
                p.stim.t_pixel(nStim)    = prod(p.stim.size(nStim,1:2));
            end
        end
    end
    function [t]=StopEyelinkRecording
        Eyelink('StopRecording');
        t = GetSecs;
        %this is the end of the trial scope.
        WaitSecs(0.01);
        Eyelink('Message', 'TRIAL_RESULT 0');
        %
        WaitSecs(0.01);
        Eyelink('Command', 'set_idle_mode');
        WaitSecs(0.01);
        Eyelink('Command', 'clear_screen %d', 0);
        Screen('Textsize', p.ptb.w,p.text.fontsize);        
    end
    function [t]=StartEyelinkRecording(nTrial,nStim)
        t = [];
        
        nStim = double(nStim);
        Eyelink('Message', 'TRIALID: %04d, FILE: %04d', nTrial, nStim);
        % an integration message so that an image can be loaded as
        % overlay background when performing Data Viewer analysis.
        WaitSecs(0.01);
        %return
        if nStim~=0
            Eyelink('Message', '!V IMGLOAD CENTER %s %d %d', p.stim.files(nStim,:), p.ptb.midpoint(1), p.ptb.midpoint(2));
        end
        % This supplies the title at the bottom of the eyetracker display
        Eyelink('Command', 'record_status_message "Stim: %02d"', nStim);
        %
        %Put the tracker offline and draw the stimuli.
        Eyelink('Command', 'set_idle_mode');
        WaitSecs(0.01);
        % clear tracker display and draw box at center
        Eyelink('Command', 'clear_screen %d', 0);
        %draw the image on the screen but also the two crosses
%         if (nStim <= 16 && nStim>0)
%             Eyelink('ImageTransfer',p.stim.files(nStim,:),p.ptb.imrect(1),p.ptb.imrect(2),p.ptb.imrect(3),p.ptb.imrect(4),p.ptb.imrect(1),p.ptb.imrect(2));            
%         end        
        Eyelink('Command', 'draw_cross %d %d 15',p.presentation.CrossPosition(1),p.presentation.CrossPosition(2));
        
        %
        %drift correction
        %EyelinkDoDriftCorrection(el,crosspositionx,crosspositiony,0,0);
        %start recording following mode transition and a short pause.
        Eyelink('Command', 'set_idle_mode');
        WaitSecs(0.01);
        Eyelink('StartRecording');
        t = GetSecs;
        
    end
    function shuffled = Shuffle(vector,N)
        %takes first N from the SHUFFLED before outputting. This function
        %could be used as a replacement for randsample
        if nargin < 2;N = length(vector);end
        [~, idx]        = sort(rand([1 length(vector)]));
        shuffled        = vector(idx(1:N));
        shuffled        = shuffled(:);
    end
    function InitEyeLink
        %
        if EyelinkInit(0)%use 0 to init normaly
            fprintf('=================\nEyelink initialized correctly...\n')
        else
            fprintf('=================\nThere is problem in Eyelink initialization\n')
            keyboard;
        end
        %
        WaitSecs(0.5);
        [~, vs] = Eyelink('GetTrackerVersion');
        fprintf('=================\nRunning experiment on a ''%s'' tracker.\n', vs );
        
        %
        el                          = EyelinkInitDefaults(p.ptb.w);
        %update the defaults of the eyelink tracker
        el.backgroundcolour         = p.stim.bg;
        el.msgfontcolour            = WhiteIndex(el.window);
        el.imgtitlecolour           = WhiteIndex(el.window);
        el.targetbeep               = 0;
        el.calibrationtargetcolour  = WhiteIndex(el.window);
        el.calibrationtargetsize    = 1.5;
        el.calibrationtargetwidth   = 0.5;
        el.displayCalResults        = 1;
        el.eyeimgsize               = 50;
        el.waitformodereadytime     = 25;%ms
        el.msgfont                  = 'Times New Roman';
        el.cal_target_beep          =  [0 0 0];%[1250 0.6 0.05];
        %shut all sounds off
        el.drift_correction_target_beep = [0 0 0];
        el.calibration_failed_beep      = [0 0 0];
        el.calibration_success_beep     = [0 0 0];
        el.drift_correction_failed_beep = [0 0 0];
        el.drift_correction_success_beep= [0 0 0];
        EyelinkUpdateDefaults(el);
        %PsychEyelinkDispatchCallback(el)
        
        % open file.
        res = Eyelink('Openfile', p.path.edf);
        %
        Eyelink('command', 'add_file_preamble_text ''Recorded by EyelinkToolbox FearCloud Experiment''');
        Eyelink('command', 'screen_pixel_coords = %ld %ld %ld %ld', 0, 0, p.ptb.width-1, p.ptb.height-1);
        Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, p.ptb.width-1, p.ptb.height-1);
        % set calibration type.
        Eyelink('command','auto_calibration_messages = YES');
        Eyelink('command', 'calibration_type = HV13');
        Eyelink('command', 'select_parser_configuration = 1');
        %what do we want to record
        Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT,HTARGET');
        Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        Eyelink('command', 'use_ellipse_fitter = no');
        % set sample rate in camera setup screen
        Eyelink('command', 'sample_rate = %d',1000);
    end
    function StopEyelink(filename)
        try
            fprintf('Trying to stop the Eyelink system with StopEyelink\n');
            Eyelink('StopRecording');
            WaitSecs(0.5);
            Eyelink('Closefile');
            display('receiving the EDF file...');
            Eyelink('ReceiveFile',filename,[p.path.subject '\eye\'],1);
            display('...finished!')
            % Shutdown Eyelink:
            Eyelink('Shutdown');
        catch
            display('StopEyeLink routine didn''t really run well');
        end
    end
    function cleanup
        
        % Close window:
        sca;
        %set back the old resolution
        if strcmp(p.hostname,'triostim1')
            Screen('Resolution',p.ptb.screenNumber, p.ptb.oldres.width, p.ptb.oldres.height );
            %show the cursor
            ShowCursor(p.ptb.screenNumber);
        end
        %        
        commandwindow;
        ListenChar(0);
        KbQueueRelease(p.ptb.device);
    end
    function CalibrateEL
        fprintf('=================\n=================\nEntering Eyelink Calibration\n')
        p_var_ExpPhase  = 0;
        ShowInstruction(0,1);
        EyelinkDoTrackerSetup(el);
        %Returns 'messageString' text associated with result of last calibration
        [~, messageString] = Eyelink('CalMessage');
        Eyelink('Message','%s',messageString);%
        WaitSecs(0.05);
        fprintf('=================\n=================\nNow we are done with the calibration\n')
    end    

    function AskStimRating
        fprintf('Subject is rating now\n');
        % Get the text to be show during rating                       
        message     = GetText(11);
        SliderTextL = GetText(12);
        SliderTextR = GetText(13);
        % Gray everything
        Screen('FillRect', p.ptb.w , p.stim.bg);
        Screen('Flip',p.ptb.w);
        WaitSecs(.6);
        % Show the instruction
%         ShowInstruction(11,1);
        rect        = [p.ptb.width*0.2  p.ptb.midpoint(2) p.ptb.width*0.6 100];        
        %save the rating sequence just for security
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        rate(nTrial)  = RatingSlider(rect, p.rating.division, Shuffle(1:p.rating.division,1), p.keys.increase, p.keys.decrease, p.keys.confirm, {SliderTextL{1} SliderTextR{1}},message,1);
        fprintf('Subject Rated: %03d\n',rate(nTrial));
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %Verbose the rating of the subject
    end
    function [rating] = RatingSlider(rect,tSection,position,up,down,confirm,labels,message,numbersOn)
        %
        %Detect the bounding boxes of the labels.
        for nlab = 1:2
            [~ , ~, bb(nlab,:)]=DrawFormattedText(p.ptb.w,labels{nlab}, 'center', 'center',  p.stim.white,[],[],[],2);
            Screen('FillRect',p.ptb.w,p.stim.bg);
        end
        bb = max(bb);
        bb_size = bb(3)-bb(1);%vertical size of the bb.
        %
        DrawSkala;
        ok = 1;
        while ok == 1
            [secs, keyCode, ~] = KbStrokeWait;
            keyCode = find(keyCode);
            
            if length(keyCode) == 1%this loop avoids crashes to accidential presses of meta keys
                if (keyCode == up) || (keyCode == down)
                    next = position + increment(keyCode);
                    if next < (tSection+1) && next > 0
                        position = position + increment(keyCode);
                        %rating   = tSection - position + 1;
                    end
                    DrawSkala;
                elseif keyCode == confirm
                    WaitSecs(0.1);
                    ok = 0;
                    Screen('FillRect',p.ptb.w,p.stim.bg);
                    t=Screen('Flip',p.ptb.w);
                end
            end
        end
        
        function DrawSkala
            %rating               = tSection - position + 1;
            rating               = position ;
            increment([up down]) = [1 -1];%delta
            tick_x               = linspace(rect(1),rect(1)+rect(3),tSection+1);%tick positions
            tick_size            = rect(3)./tSection;
            ss                   = tick_size/5*0.9;%slider size.
            %
            for tick = 1:length(tick_x)%draw ticks
                Screen('DrawLine', p.ptb.w, [255 0 0], tick_x(tick), rect(2), tick_x(tick), rect(2)+rect(4) , 3);
                if tick <= tSection && numbersOn
                    Screen('TextSize', p.ptb.w,p.text.fontsize./2);
                    DrawFormattedText(p.ptb.w, mat2str(tick) , tick_x(tick)+ss/2, rect(2)+rect(4),  p.stim.white);
                    Screen('TextSize', p.ptb.w,p.text.fontsize);
                end
                if tick == 1
                    DrawFormattedText(p.ptb.w, labels{1},tick_x(tick)-bb_size*1.4,rect(2), p.stim.white);
                elseif tick == tSection+1
                    DrawFormattedText(p.ptb.w, labels{2},tick_x(tick)+bb_size*0.4,rect(2), p.stim.white);
                end
            end
            %slider coordinates
            slider = [ tick_x(position)+tick_size*0.1 rect(2) tick_x(position)+tick_size*0.9 rect(2)+rect(4)];
            %draw the slider
            Screen('FillRect',p.ptb.w, p.stim.white, round(slider));            
            DrawFormattedText(p.ptb.w,message, 'center', p.ptb.midpoint(2)*0.2,  p.stim.white,[],[],[],2);            
            t = Screen('Flip',p.ptb.w);            
        end
    end
end
