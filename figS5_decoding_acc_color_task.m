%% figS5_decoding_acc_color_task.m
% Plot Fig. S5 decoding accuracy panels for the task-comparison color task.

clear; clc; close all

scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

% decodingAccuracies stores:
%   1 = task-comparison color experiment
%   2 = main MEG experiment
%   3 = task-comparison orientation experiment
local_decoding_acc_panels(1, 'figS5', 'decoding_acc_color_task');

