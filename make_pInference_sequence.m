
function stimuli = make_pInference_sequence(ns, mean_inter_change_length, trials, sigma, duration, ps)
stimuli = {};

% Course of experiment:
% 1. Training, exp only
% 2. fMRI, E Q E Q E Q E Q E
% 3. Training, exp only
% 4. fMRI, E Q E Q E Q E Q E
% 5. Training, exp only
% 6. fMRI, E Q E Q E Q E Q E

for s = 1:ns
    stimuli{s} = {};
    for p = 1:6 % This iterates over days.
        if mod(p, 2) == 1   % Training session
            block_types = {'E', 'E', 'E', 'E', 'E', 'E', 'E'};
        else
            block_types = {'E', 'QA', 'E', 'QB', 'E', 'QA', 'E', 'QB', 'E'};
        end
        blocks = {};
        for block = 1:length(block_types)
            type = block_types(block);
            if strcmp(type, 'E')
                es = 0;
                while abs(mean(es)-mean_inter_change_length) > 1
                  
                   [seq, es] = make_exp_sequence(mean_inter_change_length, trials, ps);

                end
            else
                %seq = make_Q_sequence(trials, type);
            end
            blocks{block} = seq; %#ok<AGROW>
            
        end
        stimuli{s}{p} = blocks; %#ok<AGROW>
    end
end

    function [seq, es] = make_exp_sequence(mean_inter_change_length, trials, ps)
        %% Makes a sequence of rules that change with a specific hazard rate.
        seq.type = 'EXP';
        seq.sigma = sigma;
        seq.sample = [];
        seq.mu = [];
        seq.stim = randi(2, 1, trials)-1;
        es = [];
        start = [0,1,2];
        nexts = [[1,2]; [0, 2]; [0,1]];
        
        while length(seq.sample)<trials
            e = round(exprnd(mean_inter_change_length));
            if e <= 5 || e > (mean_inter_change_length*2)
                continue
            end
            mu = (rand()*300 - 150);
            if numel(seq.sample)>0
                if sign(seq.sample(end)) == sign(mu)
                    mu = -1*mu;
                end
            end
            seq.sample = round([seq.sample, randn(1,e)*sigma + mu]);
            seq.mu = [seq.mu, repmat(mu, 1, e)];
            es = [es e]; %#ok<AGROW>
        end
        
        tt = mnrnd(1, ps, trials);
        seq.trial_type(tt(:, 1)==1) = 1;
        seq.trial_type(tt(:, 2)==1) = 2;
        seq.trial_type(tt(:, 3)==1) = 3;
        seq.sample = seq.sample(1:trials);
        seq.isi = duration(1) + (duration(2)-duration(1)).*rand(1, trials);
        seq.jitter = 0.3 + 0.7*rand(1, trials);
        seq.isi = seq.isi-seq.jitter;
    end

    function [seq, es] = make_Q_sequence(trials, type)
        %% Makes a sequence with one rule active

    end
end