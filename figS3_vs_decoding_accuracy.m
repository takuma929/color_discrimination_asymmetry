%% figS3_vs_decoding_accuracy.m
% Figure S3: aggregate relationship between MEG decoding accuracy, fitted
% discrimination performance, and absolute DKL distance.
%
% This script saves four independent one-column figure panels:
%   a. fitted proportion correct vs decoding accuracy for the main MEG color
%      experiment and task-comparison color experiment, pooled across purple
%      hue, purple chroma, orange hue, and orange chroma;
%   b. fitted proportion correct vs decoding accuracy for the
%      task-comparison orientation experiment, pooled across the same stimulus
%      conditions;
%   c. DKL distance from reference vs decoding accuracy for the main MEG color
%      experiment and task-comparison color experiment, pooled across all four
%      color conditions;
%   d. DKL distance from reference vs decoding accuracy for the
%      task-comparison orientation experiment, pooled across all four stimulus
%      conditions.
%
% Paths are resolved by local_meg_prop_correct_decoding_plot.m relative to this
% repository, so this script can be run from any working directory.

clear; clc; close all

scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

% Set this to true only when the subject-level bootstrap comparison is needed.
% The figure panels and Pearson correlations do not require the bootstrap.
runBootstrapStats = false;

local_meg_prop_correct_decoding_plot("s5_vs_decoding_accuracy", runBootstrapStats);
