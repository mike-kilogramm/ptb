function [p]=exp_Prime(subject,stim_id,prime_id)


debug = 1;%debug mode

%clear everything
clear mex global functions
%%%%%%%%%%%load the GETSECS mex files so call them at least once
GetSecs;
WaitSecs(0.001);
%
el                        = [];
p                         = [];
SetParams;
SetPTB;
%% init some variables so that they are global.
t                         = [];
nTrial                    = 0;
TimeEndStim               = [];
TimeStartShock            = [];
TimeTrackerOff            = [];
TimeCrossOn               = [];
p_var_ExpPhase            = [];
p_var_event_count         = 0;
%%
InitEyeLink;
WaitSecs(2);
%calibrate if we are at the scanner computer.
if strcmp(p.hostname,'triostim1') || strcmp(p.hostname,'etpc');
    CalibrateEL;
end
%save again the parameter file
save(p.path.path_param,'p');
% ShowInstruction(1,1);
%
PresentStimuli;
AskStimRating;%make sure that scanner doesnt stop prematurely asa the stim offset

%get the eyelink file back to this computer
StopEyelink(p.path.edf);
%trim the log file and save
p.out.log = p.out.log(sum(isnan(p.out.log),2) ~= size(p.out.log,2),:);
%shift the time so that the first timestamp is equal to zero
p.out.log(:,1) = p.out.log(:,1) - p.out.log(1);
p.out.log      = p.out.log;%copy it to the output variable.
save(p.path.path_param,'p');
%
%move the file to its final location.
movefile(p.path.subject,p.path.finalsubject);
%close everything down
cleanup;

    function PresentStimuli
        %Enter the presentation loop and wait for the first pulse to
        %arrive.        
        TimeEndStim                 = GetSecs;%this is now
        for nTrial  = 1:p.presentation.tTrial;
            %
            %Get the variables that Trial function needs.
            stim_id      = p.presentation.stim_id(nTrial);
            prime_id     = p.presentation.stim_id(nTrial);
            OnsetTime    = TimeEndStim + p.duration.ISI - p.duration.stim;%this is when the stimulus has to be ON.            
            KbQueueStart(p.ptb.device);%monitor keypresses...            
            
            %Start with the trial, here is time-wise sensitive must be optimal
            fprintf('Trial %d of %d; stim_id: %d, prime_id: %d\n',nTrial,p.presentation.tTrial,stim_id,prime_id);
            [TimeEndStim] = Trial( nTrial , OnsetTime, p.duration.prestimdur , stim_id , fix ,dist);
            %
            [keypressed, firstPress]=KbQueueCheck(p.ptb.device);
            
            %if the press was after stimulus onset and before stimulus offset
            if keypressed && (firstPress(p.keys.confirm) > OnsetTime) && (firstPress(p.keys.confirm) < TimeEndStim)
                p.out.response(nTrial) = 1;
                Log(firstPress(p.keys.confirm),7,NaN);%log the key press for hit detection.
                fprintf('Subject Pressed the Hit Key!!\n');
            end            
        end
    end
    function [TimeEndStim]=Trial(nTrial,TimeStimOnset , prestimdur, stim_id   , fix , dist )
        %% get all the times
        TimeCrossOnset     = TimeStimOnset  - p.duration.fixcross - p.duration.prime;%first a cross will be set.
        TimePrimeOnset     = TimeStimOnset  - p.duration.prime;%then the prime will be flashed
        TimeEndStim        = TimeStimOnset  + p.duration.stim;%
        TimeTrackerOff     = TimeStimOnset  + p.duration.keep_recording;%you want to record a bit more than necessary
        
        %% Fixation Onset
        FixCross     = [fix(1)-1,fix(2)-20,fix(1)+1,fix(2)+20;fix(1)-20,fix(2)-1,fix(1)+20,fix(2)+1];
        Screen('FillRect',  p.ptb.w, [255,255,255], FixCross');
        TimeCrossOn  = Screen('Flip',p.ptb.w,TimeCrossOnset,0);
        Eyelink('Message', 'FX Onset at %d %d',fix(1),fix(2));
        Log(TimeCrossOn,1,stim_id);%cross onset.
        %turn the eye tracker on
        StartEyelinkRecording(nTrial,stim_id,p_var_ExpPhase,dist,oddball,ucs,fix);
        
        %% Draw the prime to the buffer        
        Screen('DrawTexture', p.ptb.w, p.ptb.stim_sprites(prime_id));        
        Screen('DrawingFinished',p.ptb.w,0);
        
        %% PRIME ONSET        
        TimePrimeOnset  = Screen('Flip',p.ptb.w,TimePrimeOnset,0);%asap and dont clear
        %send eyelink and ced a marker asap
        Eyelink('Message', 'Stim Onset');
        Eyelink('Message', 'SYNCTIME');
        MarkCED( p.com.lpt.address, p.com.lpt.StimOnset );
        if oddball
            MarkCED( p.com.lpt.address, p.com.lpt.oddball );
        end
        Log(TimeStimOnset,2,stim_id);%log the stimulus onset
        
        
        if ucs == 1
            %%%%%%%%%%%%%%%%%%%%%%%
            %Deliver shock and stim off immediately
            TimeStartShock = WaitSecs('UntilTime',TimeStartShock);
            MarkCED( p.com.lpt.address, p.com.lpt.shock );
            Eyelink('Message', 'UCS Onset');
            
            while GetSecs < TimeEndStim;
                Buzz;%this is anyway sent to CED.
            end
            Eyelink('Message', 'UCS Offset');
        end
        
        %% STIM OFF immediately
        TimeEndStim = Screen('Flip',p.ptb.w,TimeEndStim,0);
        %send eyelink and ced a marker
        Eyelink('Message', 'Stim Offset');
        Eyelink('Message', 'BLANK_SCREEN');
        Screen('Textsize', p.ptb.w,p.text.fontsize);
        Log(TimeEndStim,-2,stim_id);%log the stimulus offset
        %
        %% record some more eye data after stimulus offset.
        WaitSecs('UntilTime',TimeTrackerOff);
        TimeTrackerOff    = StopEyelinkRecording;
        
        
        if oddball == 1
            fprintf('This was an oddball trial!\n');
        end
        if ucs == 1
            fprintf('This was a UCS trial!\n');
            Log(TimeStartShock,4,NaN);%UCS delivery...This is done here to not waste time there
        end
        
    end
    function SetParams
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %relative path to stim and experiments
        %Path Business.
        [~, hostname]             = system('hostname');
        p.hostname                = deblank(hostname);
        p.path.experiment         = '/Users/onat/Documents/PrimeAfford/';
        if exist(p.path.experiment) == 0
            fprintf('Baselocation:\n %s doesn''t exist\n will create it\n',p.path.baselocation);
            keyboard
        end
        p.path.stim                   = [p.path.experiment 'stim' filesep];
        %
        p.subID                       = sprintf('sub%03d',subject);
        p.path.edf                    = sprintf('sub%03d.edf',subject);
        timestamp                     = datestr(now,30);
        p.path.subject                = [p.path.experiment 'data' filesep 'tmp' filesep p.subID '_' timestamp filesep];
        p.path.finalsubject           = [p.path.experiment 'data' filesep p.subID '_' timestamp filesep ];
        %create folder hierarchy
        mkdir(p.path.subject);
        mkdir([p.path.subject 'scr']);
        mkdir([p.path.subject 'eye']);
        mkdir([p.path.subject 'stimulation']);
        mkdir([p.path.subject 'midlevel']);
        p.path.path_param             = [p.path.subject 'stimulation' filesep 'data.mat'];
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %get stim files names
        [p.stim.files p.stim.label]   = FileMatrix([p.path.stim '*.bmp']);
        p.stim.tFile                  = size(p.stim.files,1);%number of different files (including the UCS symbol)
        p.stim.tFace                  = p.stim.tFile - 1;%number of faces.
        display([mat2str(p.stim.tFile) ' found in the destination.']);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        p.stim.bg                      = [100 100 100];%background color
        p.stim.bg_rating               = [0 128 0];%bg of the rating screen.
        p.stim.white                   = [255 255 255];
        %get the actual stim size (assumes all the same)
        info                           = imfinfo(p.stim.files(1,:));
        p.stim.width                   = info.Width;
        p.stim.height                  = info.Height;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %font size and background gray level
        p.text.fontname                = 'Times New Roman';
        p.text.fontsize                = 18;%30;
        p.text.fixsize                 = 60;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %rating business
        p.rating.division              = 10;%number of divisions for the rating slider
        p.rating.repetition            = 2;%how many times a given face has to be repeated...
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % will set the resolution of the display
        p.param.resolution             = [3360 2100];
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %All settings for laptop computer.
        try
            p.keys.confirm                 = KbName('UpArrow');
            p.keys.increase                = KbName('RightArrow');
            p.keys.decrease                = KbName('LeftArrow');
            p.keys.space                   = KbName('space');
            p.keys.esc                     = KbName('ESCAPE');
        catch
            fprintf('you need to change the key names coz your system doesn''t operate the same as mine\n You can do that by calling the KbName function and \n pressing the key you want, it will output the correct keyname.\n And then replace on the code above.\n Kapisch?\n');
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %duration of different events.
        p.duration.stim                = 0.6;%2;%second
        p.duration.ISI                 = 1;%second
        p.duration.keep_recording      = 0.25;%this is the time we will keep recording (eye data) after stim offset.        
        p.duration.prime               = .25;
        p.duration.fixcross            = .25;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %stimulus presentation
        p.presentation.stim_id             = stim_id;%SEQ is one of the inputs.                
        p.presentation.prime_id            = prime_id;
        p.presentation.tTrial              = length(stim_id);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        p.out.response                     = zeros(p.presentation.tTrial,1);
        %Save the stuff for safety
        save(p.path.path_param,'p');
        %
        function [FM labels] = FileMatrix(path)
            %Takes a path with file extension associated to regexp (e.g.
            %C:\blabl\bla\*.bmp) returns the file matrix
            dummy = dir(path);
            FM    = [repmat([fileparts(path) filesep],length(dummy),1) vertcat(dummy(:).name)];
            labels = {dummy(:).name};
        end
    end
    function AskStimRating
        
        MarkCED( p.com.lpt.address, p.com.lpt.InitExperiment);
        %
        p_var_ExpPhase = 5;
        BG             = p.stim.bg;%
        p.stim.bg      = p.stim.bg_rating;
        nseq           = 0;
        rating_seq     = [];
        pos1_seq       = [];
        %
        while nseq < p.rating.repetition
            nseq            = nseq + 1;
            rating_seq      = [ rating_seq     Shuffle(1:p.stim.tFile-2)'];
        end
        message     = GetText(11);
        SliderTextL = GetText(13);
        SliderTextR = GetText(12);
        %
        Screen('FillRect', p.ptb.w , p.stim.bg);
        Screen('Flip',p.ptb.w);
        WaitSecs(2);
        %
        ShowInstruction(7,1);
        rect        = [p.ptb.width*0.2  p.ptb.midpoint(2) p.ptb.width*0.6 100];
        tRatend     = length(rating_seq);
        %save the rating sequence just for security
        p.out.rating_seq = rating_seq;
        
        for nRatend = 1:tRatend;
            %
            %the variable that are used by Trial function
            stim_id          = rating_seq(nRatend);
            
            fix             = p.presentation.CrossPosition(nRatend,:);
            %
            next_stim_id = [];%this is a trick, otherwise a fixation cross appears right before the rating :(
            next_pos1    = [];
            
            %to send know the distance here, little dummy setup:
            dummy = -135:45:180;
            dist  = dummy(stim_id);
            %We will turn on the fixation cross and start the tracker
            %for the first trial. These have to be done before the main
            %for loop.
            FixCross = [fix(1)-1,fix(2)-20,fix(1)+1,fix(2)+20;fix(1)-20,fix(2)-1,fix(1)+20,fix(2)+1];
            Screen('FillRect',  p.ptb.w, [255,255,255], FixCross');
            t  = Screen('Flip',p.ptb.w);
            Screen('Textsize', p.ptb.w,p.text.fontsize);
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Mark the onset
            Eyelink('Message', 'FX Onset at %d %d',fix(1),fix(2));
            Log(t,1,fix(1));%log the mark onset...
            Log(t,1,fix(2))
            
            %
            Trial(1000+nRatend,GetSecs+1,0.5,stim_id,0,fix,0,dist);
            rate(nRatend,1)  = RatingSlider(rect, p.rating.division, Shuffle(1:p.rating.division,1), p.keys.increase, p.keys.decrease, p.keys.confirm, {SliderTextL{1} SliderTextR{1}},message,1);
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Verbose the rating of the subject
            fprintf('============\nRating Results %d (%d/%d):\n', stim_id, nRatend, tRatend);
            dummy = rating_seq(1:nRatend);%trials shown so far
            for iii = 1:p.stim.tFile-2
                r = round(mean(rate(dummy == iii)));
                if isnan(r)
                    r = 0;
                end
                if iii == p.stim.cs_plus
                    fprintf('Stimulus %02d: * %s \n',iii,repmat('+',1,1+r));
                else
                    fprintf('Stimulus %02d:   %s \n',iii,repmat('+',1,1+r));
                end
            end
        end
        %sort the stim_ids and then sort the same the rates and make a
        %matrix out of that to store
        [~, i]       = sort(rating_seq);
        rate         = reshape(rate(i),p.rating.repetition,p.stim.tFile-2)';
        p.out.rating = rate;
        save(p.path.path_param,'p');
        Screen('FillRect',p.ptb.w,p.stim.bg);
        p.stim.bg = BG;
        %
        save(p.path.path_param,'p');
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
            Log(secs,7,keyCode);
            if length(keyCode) == 1%this loop avoids crashes to accidential presses of meta keys
                if (keyCode == up) || (keyCode == down)
                    next = position + increment(keyCode);
                    if next < (tSection+1) && next > 0
                        position = position + increment(keyCode);
                        %rating   = tSection - position + 1;
                    end
                    DrawSkala;
                elseif keyCode == confirm
                    MarkCED( p.com.lpt.address, p.com.lpt.keypress);
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
            Screen('TextSize', p.ptb.w,p.text.fontsize./2);
            DrawFormattedText(p.ptb.w,message, 'center', p.ptb.midpoint(2)*0.2,  p.stim.white,[],[],[],2);
            Screen('TextSize', p.ptb.w,p.text.fontsize);
            t = Screen('Flip',p.ptb.w);
            Log(t,6,NaN);
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
            Log(t,-5,nInstruct);
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
            Log(t,5,nInstruct);
            %show the messages at the experimenter screen
            fprintf('=========================================================\n');
            fprintf('Text shown to the subject:\n');
            fprintf('=========================================================\n');
            fprintf(text);
            fprintf('=========================================================\n');
            
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
            text = ['Wir werden nun als erstes einen �bungsdurchgang machen,\n' ...
                'damit Sie sich an Ihre Aufgabe gew�hnen k�nnen.\n' ...
                'In diesem Durchgang k�nnen Sie sich vollkommen sicher f�hlen,\n' ...
                'es werden keine elektrischen Reize verabreicht.\n' ...
                'Eine wichtige grunds�tzliche Regel ist, dass Sie das Fixationskreuz (das �+�)\n' ...
                'wenn es zu sehen ist, mit Ihren Augen fixieren. \n' ...
                'Dr�cken Sie die obere Taste um fortzufahren.\n' ...
                ];
        elseif nInstruct == 101%first Instr. of the training phase.
            text = ['Willkommen zum zweiten Teil des Experiments.\n'...
                'Eine wichtige grunds�tzliche Regel ist auch hier,\n'...
                'dass Sie das Fixationskreuz (das �+�)\n' ...
                'wenn es zu sehen ist, mit Ihren Augen fixieren. \n' ...
                'Dr�cken Sie die obere Taste um fortzufahren.\n' ...
                ];
        elseif nInstruct == 2%second Instr. of the training phase.
            text = ['Ein paar Bemerkungen zu den Zielreizen: \n' ...
                'Zur Erinnerung: Zielreize sind die verschwommenen Gesichter.\n' ...
                'Sobald ein solcher Zielreiz erscheint, \n' ...
                'sollen Sie schnellstm�glich die obere Taste dr�cken, \n' ...
                'und zwar bevor der Reiz wieder verschwunden ist \n' ...
                '(Sie m�ssen also sehr schnell und aufmerksam sein).' ...
                ];
        elseif nInstruct == 3%third Instr. of the training phase.
            text = ['Es ist sehr wichtig, dass Sie Ihren Kopf w�hrend \n' ...
                'des Experiments nicht bewegen. \n' ...
                'Das ist besonders wichtig f�r die Qualit�t der Messung.\n' ...
                ];
        elseif nInstruct == 4%third Instr. of the training phase.
            text = ['Vor dem Experiment legen wir nun \n' ...
                'die Schockintensit�t f�r den Rest des Experiments fest. \n' ...
                'Dr�cken Sie die obere Taste um fortzufahren.' ...
                ];
            
        elseif nInstruct == 5%Baseline Phase
            %
            %
            %=================================================================================================================%
            text = ['Jetzt geht es mit dem Experiment los.\n' ...
                'Ihre Aufgabe ist es jetzt, die Gesichter, \n' ...
                'die Ihnen gezeigt werden aufmerksam zu betrachten und \n' ...
                'den oberen Knopf zu dr�cken, sobald Sie einen Zielreiz sehen.\n' ...
                '\n'...
                'Hin und wieder erscheint ein Symbol (ein Blitzpfeil, der vor Strom warnt), \n' ...
                'das einen elektrischen Reiz ank�ndigt. \n' ...
                'Die Reize erfolgen aber nur bei diesem Symbol, nicht bei den Gesichtern! \n' ...
                'Bei Gesichtern k�nnen Sie sich also sicher f�hlen.\n' ...
                'Bitte denken Sie daran: 1. Fixationskreuz fixieren und 2. nicht bewegen!\n\n' ...
                'Sie k�nnen das Experiment nun durch Dr�cken der oberen Taste starten. \n' ...
                ];
            
        elseif nInstruct == 6%Test and Conditioning Phase
            %=================================================================================================================%
            text = ['Auch im nun folgenden Teil des Experiments \n' ...
                'sollen Sie die Gesichter aufmerksam betrachten und \n' ...
                'den oberen Knopf dr�cken, sobald Sie einen Zielreiz sehen. \n' ...
                'Wie im ersten Teil des Experiments sollen Sie \n' ...
                'das Fixationskreuz immer fixieren. \n' ...
                'In dieser Phase des Experiments werden Sie\n' ...
                'gelegentlich elektrische Reize bekommen.\n\n' ...
                'Die elektrischen Reize folgen jetzt auf bestimmte Gesichter. \n' ...
                
                ];
            
            
        elseif nInstruct == 7;%rating
            text = ['In dieser Phase h�tten wir gerne, dass Sie die Gesichter\n'...
                'im Hinblick auf folgende Frage bewerten:\n'...
                '�Wie wahrscheinlich ist es, bei dem gerade gesehenen Gesicht \n'...
                'einen elektrischen Schock zu erhalten?�\n'...
                'Bewegen Sie den Zeiger mit der rechten und linken Pfeiltaste \n'...
                'und best�tigen Sie Ihre Einsch�tzung mit der oberen Pfeiltaste.\n'...
                ];
            
        elseif nInstruct == 8 %CS+ detection
            text = ['Du bekommen nun eine Reihe von Gesichtern gezeigt.\n' ...
                'Bitte w�hlen Sie das Gesicht aus bei dem der Schock verabreicht wurde.\n'...
                'Dr�cken Sie die obere Taste um fortzufahren.\n'...
                ];
        elseif nInstruct == 9%
            %=================================================================================================================%
            text = ['Bitte geben Sie an, ob die Reizst�rke des folgenden Schocks\n f�r Sie ertr�glich ist.\n'...
                '\n'...
                'Dr�cken Sie bitte die obere Taste um den Reiz zu bekommen.\n'...
                ];
            
        elseif nInstruct == 10%just before the shock
            text = ['Reiz kommt...\n'];
        elseif nInstruct == 11%this is the rating question
            text = ['Wie wahrscheinlich ist es, bei dem gerade gesehenen Gesicht \n'...
                'einen elektrischen Schock zu erhalten?�\n' ...
                'Bewegen Sie den "Zeiger" mit der rechten und linken Pfeiltaste\n' ...
                'und best�tigen Sie Ihre Einsch�tzung mit der mit der oberen Pfeiltaste'...
                ];
        elseif nInstruct == 12 %These two below are the possible responses to the question in 11
            text = {'Sehr\nwahrscheinlich'};
        elseif nInstruct == 13
            text = {'�berhaupt\nnicht\nwahrscheinlich'};
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
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %Find the number of the screen to be opened
        screens                     =  Screen('Screens');
        p.ptb.screenNumber          =  max(screens);%the maximum is the second monitor
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %Use the debug feature of PTB
        if debug
            PsychDebugWindowConfiguration;%transparent Screen
        else
            commandwindow;
            ListenChar(2);%disable pressed keys to be spitted around
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %Default parameters
        Screen('Preference', 'SkipSyncTests', 1);
        Screen('Preference', 'DefaultFontSize', p.text.fontsize);
        Screen('Preference', 'DefaultFontName', p.text.fontname);
        Screen('Preference', 'TextAntiAliasing',2);%enable textantialiasing high quality
        Screen('Preference', 'VisualDebuglevel', 0);        
        Screen('Preference', 'SuppressAllWarnings', 1);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %set the resolution correctly
%         p.ptb.oldres = Screen('resolution',p.ptb.screenNumber,p.param.resolution(1),p.param.resolution(2));
        %Open a graphics window using PTB
        p.ptb.w                     = Screen('OpenWindow', p.ptb.screenNumber, p.stim.bg);
        Screen('BlendFunction', p.ptb.w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        Screen('Flip',p.ptb.w);%make the bg
        p.ptb.slack                 = Screen('GetFlipInterval',p.ptb.w)./2;
        [p.ptb.width, p.ptb.height] = Screen('WindowSize', p.ptb.screenNumber);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %find the mid position on the screen.
        p.ptb.midpoint              = [ p.ptb.width./2 p.ptb.height./2];
        p.ptb.imrect                = [ p.ptb.midpoint(1)-p.stim.width/2 p.ptb.midpoint(2)-p.stim.height/2 p.stim.width p.stim.height];
        [nx, ny bb]                  = DrawFormattedText(p.ptb.w,'+','center','center');
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %this is necessary for the Eyelink calibration for some obscure
        %reasons.
        InitializePsychSound(0);
        Beeper(5000)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %Prepare the keypress queue listening.
        p.ptb.device                         = -1;
        p.ptb.keysOfInterest=zeros(1,256);
        p.ptb.keysOfInterest(p.keys.confirm) = 1;
        KbQueueCreate(p.ptb.device,p.ptb.keysOfInterest);%default device.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %load the pictures to the memory.
        p.ptb.stim_sprites = CreateStimSprites(p.stim.files);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        Priority(MaxPriority(p.ptb.w));
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [out]=CreateStimSprites(files)
            %loads all the stims to video memory
            for nStim = 1:p.stim.tFile
                filename       = files(nStim,:);
                [im , ~, ~]    = imread(filename);
                out(nStim)     = Screen('MakeTexture', p.ptb.w, im );
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
        Log(t,-8,NaN);
    end
    function [t]=StartEyelinkRecording(nTrial,nStim,phase,dist,oddball,ucs,fix)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        t = [];
        if isnan(dist)
            dist=3000;
        end
        nStim = double(nStim);
        Eyelink('Message', 'TRIALID: %04d, PHASE: %04d, FILE: %04d, DELTACSP: %04d, ODDBALL: %04d, UCS: %04d, FIXX: %04d, FIXY %04d', nTrial, phase, nStim, dist, double(oddball), double(ucs),fix(1),fix(2));
        % an integration message so that an image can be loaded as
        % overlay background when performing Data Viewer analysis.
        WaitSecs(0.01);
        %return
        if nStim~=0
            Eyelink('Message', '!V IMGLOAD CENTER %s %d %d', p.stim.files(nStim,:), p.ptb.midpoint(1), p.ptb.midpoint(2));
        end
        % This supplies the title at the bottom of the eyetracker display
        Eyelink('Command', 'record_status_message "Stim: %02d, Phase: %d"', nStim, phase);
        %
        %Put the tracker offline and draw the stimuli.
        Eyelink('Command', 'set_idle_mode');
        WaitSecs(0.01);
        % clear tracker display and draw box at center
        Eyelink('Command', 'clear_screen %d', 0);
        %draw the image on the screen but also the two crosses
        if (nStim <= 16 && nStim>0)
            Eyelink('ImageTransfer',p.stim.files(nStim,:),p.ptb.imrect(1),p.ptb.imrect(2),p.ptb.imrect(3),p.ptb.imrect(4),p.ptb.imrect(1),p.ptb.imrect(2));
            
        end
        %         Eyelink('Command', 'draw_cross %d %d 15',p_ptb_CrossPositionET_x(1),p_ptb_CrossPositionET_y(1) );
        %         Eyelink('Command', 'draw_cross %d %d 15',p_ptb_CrossPositionET_x(2),p_ptb_CrossPositionET_y(2) );
        Eyelink('Command', 'draw_cross %d %d 15',fix(1),fix(2));
        
        %
        %drift correction
        %EyelinkDoDriftCorrection(el,crosspositionx,crosspositiony,0,0);
        %start recording following mode transition and a short pause.
        Eyelink('Command', 'set_idle_mode');
        WaitSecs(0.01);
        Eyelink('StartRecording');
        t = GetSecs;
        Log(t,8,NaN);
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
        %will init the eyelink connection
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if EyelinkInit(0)%use 0 to init normaly
            fprintf('=================\nEyelink initialized correctly...\n')
        else
            fprintf('=================\nThere is problem in Eyelink initialization\n')
            keyboard;
        end
        WaitSecs(0.5);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        [~, vs]                         = Eyelink('GetTrackerVersion');
        fprintf('=================\nRunning experiment on a ''%s'' tracker.\n', vs );
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        el                              = EyelinkInitDefaults(p.ptb.w);
        %update the defaults of the eyelink tracker
        el.backgroundcolour             = p.stim.bg;
        el.msgfontcolour                = WhiteIndex(el.window);
        el.imgtitlecolour               = WhiteIndex(el.window);
        el.targetbeep                   = 0;
        el.calibrationtargetcolour      = WhiteIndex(el.window);
        el.calibrationtargetsize        = 1.5;
        el.calibrationtargetwidth       = 0.5;
        el.displayCalResults            = 1;
        el.eyeimgsize                   = 50;
        el.waitformodereadytime         = 25;%ms
        el.msgfont                      = 'Times New Roman';
        el.cal_target_beep              =  [0 0 0];%[1250 0.6 0.05];%shut all sounds off
        el.drift_correction_target_beep = [0 0 0];
        el.calibration_failed_beep      = [0 0 0];
        el.calibration_success_beep     = [0 0 0];
        el.drift_correction_failed_beep = [0 0 0];
        el.drift_correction_success_beep= [0 0 0];
        EyelinkUpdateDefaults(el);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        % open EDF file and write information on it.
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
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
        IOPort('ConfigureSerialPort', p.com.serial,' StopBackgroundRead');
        IOPort('Close',p.com.serial);
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
    function Log(ptb_time, event_type, event_info)
        %Phases:
        %Instruction          :     1
        %Baseline             :     2
        %Conditioning         :     3
        %Test                 :     4
        %Rating               :     5
        %Calibration          :     0
        %
        %event types are as follows:
        %
        %Scan Detection       :     0    info: NaN;
        %Cross Onset          :     1    info: position
        %Stimulus Onset/Offset:     2/-2 info: stim_id
        %Cross Movement       :     3    info: NaN;
        %Stimulus Offset      :     -2   info: NaN;
        %UCS Delivery         :     4    info: NaN;
        %Key Presses          :     7    info: NaN;
        %Tracker Onset/Offset :     8    info: NaN;
        %
        %Text on the screen   :     5    info: Which Text?
        %RatingScreen Onset   :     6    info: NaN;
        
        p_var_event_count                = p_var_event_count + 1;
        %%
        %
        %   for x = 1:10
        %       disp(x)
        %   end
        %
        p.out.log(p_var_event_count,:)   = [ptb_time event_type event_info p_var_ExpPhase];
        % %         p.out.log(p.out.event_counter,:)
        %logstring([ 'Logged: ' mat2str(p.out.log(p.out.event_counter,:)) ' - Type: ' p.verbose.eventtype{abs(event_type)} ' - Phase: ' p.verbose.eventphase{CurrentExperimentalPhase}])
        %for i = 1:3;subplot(3,1,i);plot(p.out.log(1:p.out.event_counter ,i),'o-');drawnow;end
        %
        
    end


end
