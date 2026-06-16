%% figS4_log_odds_ratio_meg.m
% Supplementary version of fig6_human_meg.m showing INDIVIDUAL participant data.
%
% This script is a focused subset of fig6_human_meg.m. It produces four
% human-vs-MEG scatter figures in log10 hue/chroma odds-ratio space, each
% overlaying participant-level human psychophysics with participant-matched
% MEG log odds ratios:
%   a. small step  (MEG decoding step 1)
%   b. medium step (MEG decoding step 2)
%   c. large step  (MEG decoding step 3)
%   d. task-comparison experiment (color + orientation task individuals)
%
% Unlike fig6, this script does NOT produce the group-mean time-course figure,
% the mean-only control panel, or the console distance report. Every panel here
% shows the individual participants.
%
% The script is self-contained and operating-system independent:
%   - all paths are built with fullfile and resolved relative to this script;
%   - no path depends on the current MATLAB working directory.

clear; clc; close all

%% ------------------------- PATHS AND OPTIONS ----------------------------

scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

% Human psychophysics CSV used to compute each participant's hue/chroma index.
human_csv = fullfile(scriptDir, 'data', 'human', 'human_thresholds.csv');

% MEG log-odds-ratio MAT file (plural and singular historical filenames).
meg_mat = fullfile(scriptDir, 'data', 'meg_log_odds_ratios.mat');

% Decoding accuracy MAT file used for the task-comparison panel. This file
% stores accuracies, not precomputed log odds ratios, so accuracy is averaged
% over the chosen time window before the odds-ratio transform.
decoding_acc_mat = fullfile(scriptDir, 'data', 'meg_decoding_accuracies.mat');

outdir = fullfile(scriptDir, 'figs');
doSave = true;
twocolumn = 17.8;

% Average MEG points for the individual scatter plots over this time interval.
meg_time_window = [0.35 0.65];

% Human-readable labels and panel letters for the three MEG steps.
stepNames = {'small step', 'medium step', 'large step'};
stepPanelLetters = {'a', 'b', 'c'};
stepFileTags = {'smallstep', 'medstep', 'largestep'};

%% ------------------------- LOAD HUMAN DATA ------------------------------

assert(isfile(human_csv), 'Human CSV not found: %s', human_csv);

T = readtable(human_csv, 'TextType','string');
T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);

% Keep the same behavioral filter used in the human-threshold scripts.
if ismember('orange_hue_focused', T.Properties.VariableNames)
    T = T(T.orange_hue_focused==1, :);
end

T.ptID     = string(T.ptID);
T.axis     = lower(string(T.hue_chroma));
T.refLabel = lower(string(T.quadrant));
T.sign     = lower(string(T.direction));

% Convert human thresholds to log10 hue/chroma sensitivity ratio coordinates.
[H_HSI, xHuman, yHuman] = humanSensitivityHSI(T);

%% ------------------------- MAKE FIGURES --------------------------------

nMegSteps = megStepCount(meg_mat);
assert(nMegSteps >= 3, ...
    'Expected at least 3 MEG steps (small/medium/large) but found %d.', nMegSteps);

if doSave && ~exist(outdir, 'dir')
    mkdir(outdir);
end

% Panels a-c: one individual-participant scatter per MEG step.
figScatterByStep = cell(1, 3);
for iStep = 1:3
    [xMEGStep, yMEGStep, hasMEGStep] = loadMegLogOdds(meg_mat, H_HSI.ptID, meg_time_window, iStep);
    figScatterByStep{iStep} = plotMegScatterFigure(xHuman, yHuman, xMEGStep, yMEGStep, hasMEGStep, ...
        twocolumn, sprintf('MEG %s', stepNames{iStep}));
end

% Panel d: task-comparison experiment, individual participants from the raw
% decoding accuracies (color task and orientation task).
[controlColorMEG, controlOrientationMEG] = loadDecodingAccuracyControlLogOdds(decoding_acc_mat, meg_time_window);
figTaskComp = plotTaskComparisonFigure(xHuman, yHuman, controlColorMEG, controlOrientationMEG, twocolumn);

%% ------------------------- SAVE FIGURES --------------------------------

if doSave
    pause(0.1)
    for iStep = 1:3
        stepName = sprintf('figS4%s_log_odds_ratio_meg_individual_%s.pdf', ...
            stepPanelLetters{iStep}, stepFileTags{iStep});
        exportgraphics(figScatterByStep{iStep}, fullfile(outdir, stepName), ...
            'ContentType', 'vector', 'BackgroundColor', 'none');
        fprintf('%s successfully saved.\n', stepName);
    end

    exportgraphics(figTaskComp, ...
        fullfile(outdir, 'figS4d_log_odds_ratio_meg_individual_taskcomp.pdf'), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
    fprintf('%s successfully saved.\n', 'figS4d_log_odds_ratio_meg_individual_taskcomp.pdf');
end

%% ========================= LOCAL FUNCTIONS ==============================

function [H_HSI, xHuman, yHuman] = humanSensitivityHSI(T)
    % Compute participant-level log10 hue/chroma sensitivity ratios.
    %
    % Thresholds are first averaged within participant/reference/axis. Sensitivity
    % is the inverse of threshold, so hue/chroma sensitivity is equivalent to
    % chroma threshold divided by hue threshold.

    Hgrp = groupsummary(T, {'ptID','refLabel','axis'}, 'mean', 'JND');
    Hwide = unstack(Hgrp, 'mean_JND', 'axis');

    epsDen = 1e-12;
    hueSensitivity = 1 ./ max(Hwide.hue, epsDen);
    chromaSensitivity = 1 ./ max(Hwide.chroma, epsDen);
    Hwide.HSI = hueSensitivity ./ max(chromaSensitivity, epsDen);

    H_HSI = unstack(Hwide(:, {'ptID','refLabel','HSI'}), 'HSI', 'refLabel');
    H_HSI = rmmissing(H_HSI, 'DataVariables', {'purple','orange'});

    % x-axis is purple; y-axis is orange.
    xHuman = log10(H_HSI.purple);
    yHuman = log10(H_HSI.orange);
end

function [xMEG, yMEG, hasMEG] = loadMegLogOdds(meg_mat, humanIDs, timeWindow, stepIdx)
    % Load participant-level MEG log-odds ratios for a time window and step.
    %   xMEG = purple hue/chroma ratio; yMEG = orange hue/chroma ratio.

    M = loadMegMat(meg_mat);
    logoddsratios = M.logoddsratios;

    if isempty(stepIdx)
        stepIdx = 1:size(logoddsratios, 4);
    end

    timeIdx = M.timeWin(:,1) >= timeWindow(1) & M.timeWin(:,2) <= timeWindow(2);
    assert(any(timeIdx), 'No MEG time windows found within %.3f-%.3f s', timeWindow(1), timeWindow(2));

    % Data layout is subject x color x time x step. Color index 1 is orange and
    % color index 2 is purple.
    megOrange = squeeze(mean(mean(logoddsratios(:,1,timeIdx,stepIdx), 3, 'omitnan'), 4, 'omitnan'));
    megPurple = squeeze(mean(mean(logoddsratios(:,2,timeIdx,stepIdx), 3, 'omitnan'), 4, 'omitnan'));

    humanIDs = string(humanIDs);
    megIDs = string(M.subs(:));
    xMEG = nan(size(humanIDs));
    yMEG = nan(size(humanIDs));
    [hasMEG, loc] = ismember(humanIDs, megIDs);
    xMEG(hasMEG) = megPurple(loc(hasMEG));
    yMEG(hasMEG) = megOrange(loc(hasMEG));
    hasMEG = hasMEG & isfinite(xMEG) & isfinite(yMEG);
end

function M = loadMegMat(meg_mat)
    % Load and validate the MEG MAT file.
    assert(isfile(meg_mat), 'MEG log odds ratio MAT not found: %s', meg_mat);
    M = load(meg_mat);

    if isfield(M, 'logoddsratios')
        M.logoddsratios = M.logoddsratios;
    elseif isfield(M, 'logoddsratio')
        M.logoddsratios = M.logoddsratio;
    else
        error('No logoddsratios/logoddsratio variable found in %s', meg_mat);
    end
    assert(isfield(M, 'subs'), 'No subs variable found in %s', meg_mat);
    assert(isfield(M, 'timeWin'), 'No timeWin variable found in %s', meg_mat);
end

function nSteps = megStepCount(meg_mat)
    % The fourth dimension of logoddsratios indexes MEG processing steps.
    M = loadMegMat(meg_mat);
    nSteps = size(M.logoddsratios, 4);
end

function [controlColorMEG, controlOrientationMEG] = loadDecodingAccuracyControlLogOdds(decoding_acc_mat, timeWindow)
    % Load raw decoding accuracies and convert them into log odds ratios.
    %
    % Accuracy values are averaged across the requested time window before the
    % odds-ratio transform, matching fig6_human_meg.m.

    assert(isfile(decoding_acc_mat), 'Decoding accuracy MAT not found: %s', decoding_acc_mat);
    S = load(decoding_acc_mat, 'dec');
    assert(isfield(S, 'dec'), 'Variable dec not found in %s', decoding_acc_mat);
    dec = S.dec;

    % Experiment-indexed fields are 1x3 cells: supplementary, main, control.
    expIdx.supplementary = 1;
    expIdx.main = 2;
    expIdx.control = 3;


    % Task-comparison controls use step 3: supplementary = color task;
    % control = orientation task.
    [controlColorX, controlColorY] = decodingAccuracyLogOddsForExperiment(dec, expIdx.supplementary, timeWindow, 3);
    [controlOrientationX, controlOrientationY] = decodingAccuracyLogOddsForExperiment(dec, expIdx.control, timeWindow, 3);

    controlColorMEG.x = controlColorX;
    controlColorMEG.y = controlColorY;
    controlOrientationMEG.x = controlOrientationX;
    controlOrientationMEG.y = controlOrientationY;
end

function [xVals, yVals] = decodingAccuracyLogOddsForExperiment(dec, expIdx, timeWindow, stepLevel)
    % Compute participant-level purple/orange log odds ratios from one
    % experiment's decoding accuracy array.

    acc = getExperimentCellValue(dec.acc_agg, expIdx);
    acc = double(acc);

    accDims = string(getDecodingMetadata(dec, expIdx, ["accDims", "dims", "Dims"]));
    dimLevsRaw = getDecodingMetadata(dec, expIdx, ["accDimLevs", "DimLevs", "dimLevs", "DimLevels", "dimLevels"]);
    dimLevs = normalizeDecodingDimLevels(dimLevsRaw, accDims);
    accTime = double(getDecodingMetadata(dec, expIdx, ["accTime", "time", "times"]));

    % Average raw accuracies across the requested time window.
    timeDim = findTimeDimension(acc, accTime);
    timeIdx = accTime >= timeWindow(1) & accTime <= timeWindow(2);
    assert(any(timeIdx), 'No decoding accuracy time points found within %.3f-%.3f s', timeWindow(1), timeWindow(2));
    acc = selectAlongDimension(acc, timeDim, timeIdx);
    acc = mean(acc, timeDim, 'omitnan');

    refDim = findDimensionWithLevels(dimLevs, ["purple", "orange"]);
    axisDim = findDimensionWithLevels(dimLevs, ["hue", "chroma"]);
    participantDim = ndims(acc);

    if ~isempty(stepLevel)
        stepDim = findDimensionByName(accDims, "step");
        stepIdx = findLevelIndex(dimLevs{stepDim}, stepLevel);
        acc = selectAlongDimension(acc, stepDim, stepIdx);
    end

    purpleIdx = findLevelIndex(dimLevs{refDim}, "purple");
    orangeIdx = findLevelIndex(dimLevs{refDim}, "orange");
    hueIdx = findLevelIndex(dimLevs{axisDim}, "hue");
    chromaIdx = findLevelIndex(dimLevs{axisDim}, "chroma");

    purpleHue = extractParticipantAccuracy(acc, refDim, axisDim, participantDim, purpleIdx, hueIdx);
    purpleChroma = extractParticipantAccuracy(acc, refDim, axisDim, participantDim, purpleIdx, chromaIdx);
    orangeHue = extractParticipantAccuracy(acc, refDim, axisDim, participantDim, orangeIdx, hueIdx);
    orangeChroma = extractParticipantAccuracy(acc, refDim, axisDim, participantDim, orangeIdx, chromaIdx);

    % Log10 hue/chroma odds ratio computed per participant: each input is one
    % participant's time-averaged accuracy, so the ratio is formed per
    % participant and only later averaged across participants (this matches the
    % statistics).
    xVals = log10(localOdds(purpleHue) ./ localOdds(purpleChroma));
    yVals = log10(localOdds(orangeHue) ./ localOdds(orangeChroma));
end

function v = getDecodingMetadata(dec, expIdx, fieldNames)
    % Return one experiment's metadata from either dec.FIELD or dec.acc.FIELD.

    containers = {dec};
    for nestedName = ["acc", "accuracy"]
        nestedName = char(nestedName);
        if isfield(dec, nestedName)
            containers{end+1} = dec.(nestedName); %#ok<AGROW>
        end
    end

    for iContainer = 1:numel(containers)
        container = containers{iContainer};

        if iscell(container)
            if numel(container) >= expIdx
                container = container{expIdx};
            else
                continue
            end
        end

        if isstruct(container) && numel(container) > 1 && numel(container) >= expIdx
            container = container(expIdx);
        end

        if ~isstruct(container)
            continue
        end

        for iField = 1:numel(fieldNames)
            fieldName = char(fieldNames(iField));
            if isfield(container, fieldName)
                v = container.(fieldName);
                if isExperimentCellArray(v, expIdx)
                    v = v{expIdx};
                end
                return
            end
        end
    end

    error('None of these metadata fields were found in dec or dec.acc: %s', strjoin(string(fieldNames), ', '));
end

function tf = isExperimentCellArray(v, expIdx)
    % True for 1x3 experiment cell arrays such as acc_agg, but false for cell
    % arrays of labels such as accDims.
    tf = false;
    if ~iscell(v) || numel(v) < expIdx
        return
    end

    cellClasses = cellfun(@class, v, 'UniformOutput', false);
    allTextCells = all(cellfun(@(x) ischar(x) || (isstring(x) && isscalar(x)), v));
    if allTextCells
        return
    end

    tf = numel(v) == 3 && numel(unique(cellClasses)) >= 1;
end

function dimLevs = normalizeDecodingDimLevels(dimLevsRaw, accDims)
    % Convert dec.accDimLevs into a cell array aligned to accDims.
    if iscell(dimLevsRaw)
        dimLevs = dimLevsRaw;
        return
    end

    assert(isstruct(dimLevsRaw), 'accDimLevs/DimLevs must be a struct or cell array.');
    dimLevs = cell(1, numel(accDims));
    for iDim = 1:numel(accDims)
        dimName = char(accDims(iDim));
        if isfield(dimLevsRaw, dimName)
            dimLevs{iDim} = dimLevsRaw.(dimName);
        else
            dimLevs{iDim} = {};
        end
    end
end

function v = getExperimentCellValue(v, expIdx)
    % Extract one experiment from cell-array or direct numeric/string fields.
    if iscell(v)
        v = v{expIdx};
    end
end

function dim = findTimeDimension(acc, accTime)
    % Identify the time dimension by matching its length to accTime.
    sz = size(acc);
    dim = find(sz == numel(accTime), 1, 'first');
    assert(~isempty(dim), 'Could not identify time dimension from accTime.');
end

function dim = findDimensionWithLevels(dimLevs, requestedLevels)
    % Find the dimension whose level labels contain all requested strings.
    requestedLevels = lower(string(requestedLevels));
    dim = [];
    for iDim = 1:numel(dimLevs)
        levs = lower(string(dimLevs{iDim}));
        hasAll = true;
        for iLev = 1:numel(requestedLevels)
            hasAll = hasAll && any(contains(levs, requestedLevels(iLev)));
        end
        if hasAll
            dim = iDim;
            return
        end
    end
    error('Could not find dimension with levels: %s', strjoin(requestedLevels, ', '));
end

function idx = findLevelIndex(levels, requestedLevel)
    % Find a level index using case-insensitive substring matching.
    levels = lower(string(levels));
    requestedLevel = lower(string(requestedLevel));
    idx = find(contains(levels, requestedLevel), 1, 'first');
    assert(~isempty(idx), 'Could not find level "%s".', requestedLevel);
end

function dim = findDimensionByName(accDims, requestedName)
    % Find a dimension by its accDims label.
    accDims = lower(string(accDims));
    requestedName = lower(string(requestedName));
    dim = find(accDims == requestedName, 1, 'first');
    assert(~isempty(dim), 'Could not find dimension "%s" in accDims.', requestedName);
end

function A = selectAlongDimension(A, dim, idx)
    % Index an array along one dimension while preserving other dimensions.
    subs = repmat({':'}, 1, ndims(A));
    subs{dim} = idx;
    A = A(subs{:});
end

function odds = localOdds(acc)
    % Convert decoding accuracy to odds with finite clipping.
    epsAcc = 1e-6;
    acc = min(max(acc, epsAcc), 1 - epsAcc);
    odds = acc ./ (1 - acc);
end

function vals = extractParticipantAccuracy(A, refDim, axisDim, participantDim, refIdx, axisIdx)
    % Return one per-participant, time-averaged accuracy value for a
    % reference/axis pair. Every dimension except the participant dimension is
    % selected or averaged, so the participant dimension is retained and ratios
    % can be computed per participant.

    A = selectAlongDimension(A, refDim, refIdx);
    A = selectAlongDimension(A, axisDim, axisIdx);

    for d = ndims(A):-1:1
        if d ~= participantDim
            A = mean(A, d, 'omitnan');
        end
    end

    vals = squeeze(A);
end

function fig = plotMegScatterFigure(xHuman, yHuman, xMEG, yMEG, hasMEG, twocolumn, plotTitle)
    % Plot one participant-level human-vs-MEG scatter for a single MEG step.
    %
    % Human participants are gray circles, MEG participants are cyan triangles,
    % aligned by participant ID where available.

    if nargin < 7
        plotTitle = '';
    end

    [minlim, maxlim] = plotLimits();

    fig = figure('Color', 'w');
    hold on;
    axis([minlim maxlim minlim maxlim]);

    addBackgroundGuides(minlim, maxlim);

    xHumanMean = mean(xHuman, 'omitnan');
    yHumanMean = mean(yHuman, 'omitnan');
    scatter(xHuman, yHuman, 36, [0.45 0.45 0.45], 'o', 'filled', ...
        'MarkerFaceAlpha', 0.45, 'DisplayName', 'Humans');

    if ~isempty(hasMEG) && any(hasMEG)
        scatter(xMEG(hasMEG), yMEG(hasMEG), 42, [0.00 0.75 0.85], '^', 'filled', ...
            'MarkerFaceAlpha', 0.45, 'MarkerEdgeColor', 'none', 'DisplayName', 'MEG');

        xMEGMean = mean(xMEG(hasMEG), 'omitnan');
        yMEGMean = mean(yMEG(hasMEG), 'omitnan');
    end

    scatter(xHumanMean, yHumanMean, 75, 'o', 'filled', ...
        'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w', ...
        'DisplayName', 'Human mean');

    if ~isempty(hasMEG) && any(hasMEG)
        scatter(xMEGMean, yMEGMean, 70, '^', 'filled', ...
            'MarkerFaceColor', [0.00 0.75 0.85], 'MarkerEdgeColor', 'k', ...
            'LineWidth', 0.5, 'MarkerFaceAlpha', 1.0, ...
            'DisplayName', 'MEG mean');
    end

    xlabel('log_1_0 hue / chroma (purple)', 'FontWeight', 'bold');
    ylabel('log_1_0 hue / chroma (orange)', 'FontWeight', 'bold');
    if strlength(string(plotTitle)) > 0
        % Titles are suppressed to match the compact manuscript style.
        %title(plotTitle, 'FontWeight', 'normal');
    end
    styleScatterAxes(fig, twocolumn, minlim, maxlim);
end

function fig = plotTaskComparisonFigure(xHuman, yHuman, controlColorMEG, controlOrientationMEG, twocolumn)
    % Plot the task-comparison panel with INDIVIDUAL participant points for the
    % color task and orientation task, plus their means and the psychophysics
    % mean. This mirrors fig6's control panel with showIndividuals = true.

    [minlim, maxlim] = plotLimits();
    fig = figure('Color', 'w');
    hold on;
    axis([minlim maxlim minlim maxlim]);
    addBackgroundGuides(minlim, maxlim);

    % Psychophysics-only mean from the human behavioral thresholds.
    xHumanMean = mean(xHuman, 'omitnan');
    yHumanMean = mean(yHuman, 'omitnan');
    scatter(xHumanMean, yHumanMean, 75, 'o', 'filled', ...
        'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w', ...
        'DisplayName', 'Psychophysics-only');

    colorCol = [1.00 0.45 0.45];
    orientationCol = [0.35 0.55 1.00];

    % Individual task-comparison MEG participants.
    scatter(controlColorMEG.x, controlColorMEG.y, 36, colorCol, '^', 'filled', ...
        'MarkerFaceAlpha', 0.35, 'MarkerEdgeColor', 'none', ...
        'DisplayName', 'Task-comp. MEG: color');
    scatter(controlOrientationMEG.x, controlOrientationMEG.y, 70, orientationCol, 'p', 'filled', ...
        'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', 'none', ...
        'DisplayName', 'Task-comp. MEG: orientation');

    % Means.
    xControlColorMean = mean(controlColorMEG.x, 'omitnan');
    yControlColorMean = mean(controlColorMEG.y, 'omitnan');
    scatter(xControlColorMean, yControlColorMean, 70, colorCol, '^', 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'MarkerFaceAlpha', 1.0, ...
        'DisplayName', 'Task-comp. MEG: color mean');
    xControlOrientationMean = mean(controlOrientationMEG.x, 'omitnan');
    yControlOrientationMean = mean(controlOrientationMEG.y, 'omitnan');
    scatter(xControlOrientationMean, yControlOrientationMean, 120, orientationCol, 'p', 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'MarkerFaceAlpha', 1.0, ...
        'DisplayName', 'Task-comp. MEG: orientation mean');

    xlabel('log_1_0 hue / chroma (purple)', 'FontWeight', 'bold');
    ylabel('log_1_0 hue / chroma (orange)', 'FontWeight', 'bold');
    styleScatterAxes(fig, twocolumn, minlim, maxlim);
end

function addBackgroundGuides(minlim, maxlim)
    % Add shared ratio-space guides: two triangular regions, diagonal equality,
    % and zero reference lines.
    patch([minlim maxlim maxlim], [minlim minlim maxlim], [0.80 0.20 0.90], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.08);
    patch([minlim minlim maxlim], [minlim maxlim maxlim], [0.85 0.33 0.10], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.08);
    plot([minlim maxlim], [minlim maxlim], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
    line([0 0], [minlim maxlim], 'LineStyle', ':', 'Color', 'k', 'LineWidth', 1);
    line([minlim maxlim], [0 0], 'LineStyle', ':', 'Color', 'k', 'LineWidth', 1);
end

function styleScatterAxes(fig, twocolumn, minlim, maxlim)
    % Apply common figure size, axis size, ticks, and styling to every output.
    ax = gca;
    ax.XTick = [-0.10 0.00 0.10 0.20 0.30 0.40];
    ax.YTick = [-0.10 0.00 0.10 0.20 0.30 0.40];
    ax.XLim = [minlim maxlim];
    ax.YLim = [minlim maxlim];
    ax.XTickLabel = {'-0.10','0.00','0.10','0.20','0.30','0.40'};
    ax.YTickLabel = {'-0.10','0.00','0.10','0.20','0.30','0.40'};

    fig.PaperType = 'a4';
    fig.PaperUnits = 'centimeters';
    fig.Units = 'centimeters';
    fig.InvertHardcopy = 'off';
    fig.PaperPosition = [0, 10, 8.5, 8.5];
    fig.Position = [10, 10, twocolumn/2*0.9, twocolumn/2*0.9];

    ax.FontName = 'Arial';
    ax.FontSize = 7;
    ax.Units = 'centimeters';
    ax.Position = [1.1 1.0 6.6 6.6];
    ax.LineWidth = 0.5;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.Color = 'none';

    axis square
    box on
    grid minor
end

function [minlim, maxlim] = plotLimits()
    % Shared axis limits for all human/MEG ratio-space figures.
    minlim = -0.17;
    maxlim = 0.4;
end
