%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Quick numbers for beh + export to Excel
%
% 29/01/2026
% Federico Ramirez-Torano
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear
clc
close all

%% Paths
config.path.beh = fullfile('..','..','data','sourcedata','beh');
config.path.out = fullfile('..','..','data','sourcedata','beh');

if ~exist(config.path.out, 'dir')
    mkdir(config.path.out);
end

output_excel = fullfile(config.path.out, 'beh.xlsx');

%% Config
index_load = [4, 6, 8];
num_blocks = 5;

%% Get the subjects' files
files = dir(fullfile(config.path.beh, '*_ColorK_MATLAB.mat'));

%% Preallocation
nsubj  = numel(files);
nloads = numel(index_load);

accuracy = nan(nsubj, num_blocks, nloads);
K        = nan(nsubj, num_blocks, nloads);
rt       = nan(nsubj, num_blocks, nloads);
IDs      = cell(nsubj, 1);

%% Estimate the behavioral information of interest
for ifile = 1:nsubj
    
    % Load current file
    current_file = fullfile(files(ifile).folder, files(ifile).name);
    S = load(current_file);
    
    % If the loaded file contains the variable "stim"
    stim = S.stim;
    
    % Extract ID from filename
    % Example: sub-001_ColorK_MATLAB.mat --> sub-001
    IDs{ifile} = erase(files(ifile).name, '_ColorK_MATLAB.mat');
    
    % Accuracy / RT / K per load and block
    for iblock = 1:num_blocks
        for iload = 1:nloads
            
            current_load = index_load(iload);
            
            % Data for current block
            current_accuracy  = stim.accuracy(:, iblock);
            current_rt        = stim.rt(:, iblock);
            current_task_load = stim.setSize(:, iblock) == current_load;
            
            % Accuracy
            accuracy(ifile, iblock, iload) = mean(current_accuracy(current_task_load), 'omitnan');
            
            % K coefficient
            K(ifile, iblock, iload) = computeK( ...
                current_load, ...
                stim.setSize(:, iblock), ...
                stim.response(:, iblock), ...
                stim.change(:, iblock));
            
            % Response time
            rt(ifile, iblock, iload) = mean(current_rt(current_task_load), 'omitnan');
            
        end
    end
end

%% Create output table
T = table(IDs, 'VariableNames', {'ID'});

% Add columns in the requested order:
% For each load: rt block1-5, accuracy block1-5, k block1-5
for iload = 1:nloads
    
    current_load = index_load(iload);
    
    % RT columns
    for iblock = 1:num_blocks
        var_name = sprintf('rt_load_%d_bloque_%d', current_load, iblock);
        T.(var_name) = rt(:, iblock, iload);
    end
    
    % Accuracy columns
    for iblock = 1:num_blocks
        var_name = sprintf('accuracy_load_%d_bloque_%d', current_load, iblock);
        T.(var_name) = accuracy(:, iblock, iload);
    end
    
    % K columns
    for iblock = 1:num_blocks
        var_name = sprintf('k_load_%d_bloque_%d', current_load, iblock);
        T.(var_name) = K(:, iblock, iload);
    end
end

%% Add mean columns by load
for iload = 1:nloads
    
    current_load = index_load(iload);
    
    T.(sprintf('ACCURACY_Load%d', current_load)) = mean(accuracy(:, :, iload), 2, 'omitnan');
    T.(sprintf('RT_Load%d', current_load))       = mean(rt(:, :, iload), 2, 'omitnan');
    T.(sprintf('K_Load%d', current_load))        = mean(K(:, :, iload), 2, 'omitnan');
    
end

%% Write Excel
writetable(T, output_excel);

fprintf('Behavioral summary saved in:\n%s\n', output_excel);

%% LOCAL FUNCTION
function K = computeK(load, setSize, response, change)
%
% Input:
%   load: Load of interest
%   setSize: Load in each trial
%   response: 162 = no change; 163 = change
%   change: 0 = no change ; 1 = change
%
% Output:
%   K    WM Capacity

    % Trials of the selected load
    load_index = setSize == load;
    current_response = response(load_index);
    current_change   = change(load_index);

    % Number of trials
    n_change    = sum(current_change == 1);
    n_nochange  = sum(current_change == 0);

    % Safety check
    if n_change == 0 || n_nochange == 0
        K = NaN;
        return
    end

    % Hit rate: "change" response when there is a change
    H = sum(current_response == 163 & current_change == 1) / n_change;

    % False alarm rate: "change" response when there is no change
    FA = sum(current_response == 163 & current_change == 0) / n_nochange;

    % Vogel's K
    K = load * (H - FA);
end