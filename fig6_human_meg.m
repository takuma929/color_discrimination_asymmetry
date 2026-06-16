%% fig6_human_meg.m
% Make human psychophysics + MEG comparison figures.
%
% This script produces separate figures, not a single combined figure:
%   1. MEG time-course trajectory in hue/chroma ratio space.
%   2. One human-vs-MEG scatter plot for each MEG decoding step.
%
% The code is intentionally self-contained and operating-system independent:
%   - all paths are built with fullfile;
%   - data and output folders are resolved relative to this script;
%   - no path depends on the current MATLAB working directory;
%   - both PDF and PNG files are saved for each figure.

clear; clc; close all

%% ------------------------- PATHS AND OPTIONS ----------------------------

% Locate the folder containing this script. This is more robust than using pwd,
% because the script can then be launched from any current folder.
scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    % Fallback for command-window or copied-code execution.
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

% Human psychophysics CSV used to compute each participant's hue/chroma index.
human_csv = fullfile(scriptDir, 'data', 'human', 'human_thresholds.csv');

% MEG log-odds-ratio MAT file. Support both plural and singular historical
% filenames so the script remains compatible with older local data exports.
meg_mat = fullfile(scriptDir, 'data', 'meg_log_odds_ratios.mat');

% Decoding accuracy MAT file used for the control comparison panel. This file
% stores accuracies, not precomputed log odds ratios, so this script averages
% accuracy over the chosen time window before computing the odds ratio.
decoding_acc_mat = fullfile(scriptDir, 'data', 'meg_decoding_accuracies.mat');

% Save all outputs into a figure-specific folder.
outdir = fullfile(scriptDir, 'figs');
doSave = true;
twocolumn = 17.8;

%% ------------------------- LOAD HUMAN DATA ------------------------------

% Fail early if the expected human CSV cannot be found.
assert(isfile(human_csv), 'Human CSV not found: %s', human_csv);

% Load the table and normalize variable names so the rest of the code can use
% valid MATLAB field names even if the CSV headers contain punctuation/spaces.
T = readtable(human_csv, 'TextType','string');
T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);

% Keep the same behavioral filter used in the previous human-threshold scripts.
if ismember('orange_hue_focused', T.Properties.VariableNames)
    T = T(T.orange_hue_focused==1, :);
end

% Standardize the categorical columns used in grouping and plotting.
T.ptID     = string(T.ptID);
T.axis     = lower(string(T.hue_chroma));
T.refLabel = lower(string(T.quadrant));
T.sign     = lower(string(T.direction));

% Convert human thresholds to log10 hue/chroma sensitivity ratio coordinates.
[H_HSI, xHuman, yHuman] = humanSensitivityHSI(T);

%% ------------------------- LOAD MEG SUMMARIES ---------------------------

% Average MEG points for individual scatter plots over this time interval.
meg_time_window = [0.35 0.65];

% Extract group-mean MEG trajectory points across selected time windows.
[xMEGTimeByStep, yMEGTimeByStep, megTimeLabels, stepLabels] = loadMegTimecourseAllSteps(meg_mat, 0.00, 0.60);

% Count all available MEG steps for the separate step-wise scatter plots.
nMegSteps = megStepCount(meg_mat);

% Print the participant-matched MEG-vs-psychophysics distance comparison across
% shift magnitudes (Fig. S4 statistics). Console report only; does not affect
% the saved figures.
reportMegParticipantDistanceAcrossSteps(meg_mat, H_HSI.ptID, xHuman, yHuman, meg_time_window);

% Create the output directory only if saving is enabled.
if doSave && ~exist(outdir, 'dir')
    mkdir(outdir);
end

%% ------------------------- MAKE SEPARATE FIGURES ------------------------

% Individual-participant scatter figures (per MEG step) now live in
% figS4_log_odds_ratio_meg.m. fig6 keeps only the group-level figures below.

% Group-mean MEG time-course trajectory figure.
figTimecourse = plotMegTimecourseStepsFigure(xHuman, yHuman, xMEGTimeByStep, yMEGTimeByStep, megTimeLabels, stepLabels, twocolumn);

% Control-comparison panel from the raw decoding accuracies. Following the
% collaborator's note, this averages accuracies across meg_time_window first,
% then computes log odds ratios exactly once for that window. Only the
% mean-symbol version is produced here; the individual-participant version is in
% figS4_log_odds_ratio_meg.m.
[xMEGStep3, yMEGStep3, hasMEGStep3] = loadMegLogOdds(meg_mat, H_HSI.ptID, meg_time_window, 3);
[controlColorMEG, controlOrientationMEG] = loadDecodingAccuracyControlLogOdds(decoding_acc_mat, meg_time_window);
figControlMeanOnly = plotDecodingAccuracyControlFigure(xHuman, yHuman, xMEGStep3, yMEGStep3, hasMEGStep3, ...
    controlColorMEG, controlOrientationMEG, twocolumn, false);

% Save all figures as PDFs for vector editing.
if doSave
    pause(0.1)

    % fig6a: group-mean MEG time-course trajectory (large step).
    exportgraphics(figTimecourse, fullfile(outdir, 'fig6a_scatter_human_meg_timelapse_all_steps.pdf'), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
    fprintf('%s successfully saved.\n', 'fig6a_scatter_human_meg_timelapse_all_steps.pdf');

    % fig6b: task-comparison experiment (mean symbols only).
    exportgraphics(figControlMeanOnly, fullfile(outdir, 'fig6b_control.pdf'), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
    fprintf('%s successfully saved.\n', 'fig6b_control.pdf');
end

%% ------------------------------------------------------------------------
function [controlColorMEG, controlOrientationMEG] = loadDecodingAccuracyControlLogOdds(decoding_acc_mat, timeWindow)
    % Load raw decoding accuracies and convert them into log odds ratios.
    %
    % Important: the accuracy values are averaged across the requested time
    % window before the odds-ratio transform is applied. This follows the
    % collaborator's note and avoids averaging log odds ratios that were computed
    % from different time windows.

    assert(isfile(decoding_acc_mat), 'Decoding accuracy MAT not found: %s', decoding_acc_mat);
    S = load(decoding_acc_mat, 'dec');
    assert(isfield(S, 'dec'), 'Variable dec not found in %s', decoding_acc_mat);
    dec = S.dec;

    % Most fields are 1x3 cell arrays: supplementary experiment, main
    % experiment, and control experiment.
    expIdx.supplementary = 1;
    expIdx.main = 2;
    expIdx.control = 3;

    % The odds ratio uses the standard transform acc/(1-acc), formed after
    % time-window averaging.

    % Task-comparison controls use step 3 in two different experiments:
    % supplementary experiment = color task; control experiment = orientation.
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
    %
    % The collaborator's file describes acc_agg as:
    %   time x condition x condition x singleton x condition x participant
    % but this function uses accDims and DimLevs to find the meaningful axes so
    % it is not tied to those exact dimension positions.

    acc = getExperimentCellValue(dec.acc_agg, expIdx);
    acc = double(acc);

    accDims = string(getDecodingMetadata(dec, expIdx, ["accDims", "dims", "Dims"]));
    dimLevsRaw = getDecodingMetadata(dec, expIdx, ["accDimLevs", "DimLevs", "dimLevs", "DimLevels", "dimLevels"]);
    dimLevs = normalizeDecodingDimLevels(dimLevsRaw, accDims);
    accTime = double(getDecodingMetadata(dec, expIdx, ["accTime", "time", "times"]));

    % Select the desired time points and average raw accuracies in that window.
    timeDim = findTimeDimension(acc, accTime);
    timeIdx = accTime >= timeWindow(1) & accTime <= timeWindow(2);
    assert(any(timeIdx), 'No decoding accuracy time points found within %.3f-%.3f s', timeWindow(1), timeWindow(2));
    acc = selectAlongDimension(acc, timeDim, timeIdx);
    acc = mean(acc, timeDim, 'omitnan');

    % Find the reference-color and hue/chroma axes from the labels supplied in
    % the MAT file. These labels are safer than relying on hard-coded dimension
    % numbers.
    refDim = findDimensionWithLevels(dimLevs, ["purple", "orange"]);
    axisDim = findDimensionWithLevels(dimLevs, ["hue", "chroma"]);
    participantDim = ndims(acc);

    % Optionally select one numeric step level. If empty, all steps are averaged
    % as nuisance dimensions later.
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
    % statistics). Accuracy is clipped away from 0 and 1 so the odds transform
    % remains finite.
    xVals = log10(localOdds(purpleHue) ./ localOdds(purpleChroma));
    yVals = log10(localOdds(orangeHue) ./ localOdds(orangeChroma));
end

function fig = plotDecodingAccuracyControlFigure(xHuman, yHuman, xMEGStep3, yMEGStep3, hasMEGStep3, ...
    controlColorMEG, controlOrientationMEG, twocolumn, showIndividuals)
    % Plot the fig5d control panel matching the supplied reference figure.

    if nargin < 9
        showIndividuals = false;
    end

    % Use the same axis range as the step-3 (large shift) time-lapse figure.
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

    % Task-comparison control means.
    colorCol = [1.00 0.45 0.45];
    orientationCol = [0.35 0.55 1.00];
    if showIndividuals
        scatter(controlColorMEG.x, controlColorMEG.y, 36, colorCol, '^', 'filled', ...
            'MarkerFaceAlpha', 0.35, 'MarkerEdgeColor', 'none', ...
            'DisplayName', 'Task-comp. MEG: color');
        scatter(controlOrientationMEG.x, controlOrientationMEG.y, 70, orientationCol, 'p', 'filled', ...
            'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', 'none', ...
            'DisplayName', 'Task-comp. MEG: orientation');
    end

    % Mean symbols use the same polished style as fig5a's MEG mean: filled
    % marker, black edge, full opacity, and slightly larger size.
    xControlColorMean = mean(controlColorMEG.x, 'omitnan');
    yControlColorMean = mean(controlColorMEG.y, 'omitnan');
    scatter(xControlColorMean, yControlColorMean, ...
        70, colorCol, '^', 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'MarkerFaceAlpha', 1.0, ...
        'DisplayName', 'Task-comp. MEG: color mean');
    xControlOrientationMean = mean(controlOrientationMEG.x, 'omitnan');
    yControlOrientationMean = mean(controlOrientationMEG.y, 'omitnan');
    scatter(xControlOrientationMean, yControlOrientationMean, ...
        120, orientationCol, 'p', 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'MarkerFaceAlpha', 1.0, ...
        'DisplayName', 'Task-comp. MEG: orientation mean');

    xlabel('log_1_0 hue / chroma (purple)', 'FontWeight', 'bold');
    ylabel('log_1_0 hue / chroma (orange)', 'FontWeight', 'bold');
    % Keep the default tick set from styleScatterAxes so the range and ticks
    % match the step-3 (large shift) time-lapse figure.
    styleScatterAxes(fig, twocolumn, minlim, maxlim);
end

function v = getDecodingMetadata(dec, expIdx, fieldNames)
    % Return one experiment's metadata from either dec.FIELD or dec.acc.FIELD.
    %
    % The collaborator described the level labels as acc.DimLevs, so this helper
    % checks both the top-level dec struct and nested metadata containers such as
    % dec.acc. It also accepts either 1x3 cell arrays or 1x3 struct arrays.

    containers = {dec};
    for nestedName = ["acc", "accuracy"]
        nestedName = char(nestedName);
        if isfield(dec, nestedName)
            containers{end+1} = dec.(nestedName); %#ok<AGROW>
        end
    end

    for iContainer = 1:numel(containers)
        container = containers{iContainer};

        % A nested metadata container can itself be a 1x3 cell array.
        if iscell(container)
            if numel(container) >= expIdx
                container = container{expIdx};
            else
                continue
            end
        end

        % A nested metadata container can also be a 1x3 struct array, one struct
        % per experiment. Index before field access to avoid comma-separated
        % lists from container.FIELD.
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
    % arrays of labels such as accDims = {'time','quad','hc','direc','step','pt'}.
    tf = false;
    if ~iscell(v) || numel(v) < expIdx
        return
    end

    cellClasses = cellfun(@class, v, 'UniformOutput', false);
    allTextCells = all(cellfun(@(x) ischar(x) || (isstring(x) && isscalar(x)), v));
    if allTextCells
        return
    end

    % The colleague's experiment-indexed fields have three entries:
    % supplementary, main, and control.
    tf = numel(v) == 3 && numel(unique(cellClasses)) >= 1;
end

function dimLevs = normalizeDecodingDimLevels(dimLevsRaw, accDims)
    % Convert dec.accDimLevs into a cell array aligned to accDims.
    %
    % In the current file, dec.accDimLevs is a struct with fields named after
    % accDims. Older/local variants may already provide a cell array.
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
            % Continuous/sample dimensions such as time and pt are described by
            % accTime and pts, so accDimLevs may omit them.
            dimLevs{iDim} = {};
        end
    end
end

function v = getExperimentCellValue(v, expIdx)
    % Extract one experiment from fields that may be either cell arrays or direct
    % numeric/string arrays.
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
    % Index an array along one dimension while preserving all other dimensions.
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

function [H_HSI, xHuman, yHuman] = humanSensitivityHSI(T)
    % Compute participant-level log10 hue/chroma sensitivity ratios.
    %
    % Thresholds are first averaged within participant/reference/axis. Sensitivity
    % is the inverse of threshold, so hue/chroma sensitivity is equivalent to
    % chroma threshold divided by hue threshold.

    % Average repeated measurements within each participant and condition.
    Hgrp = groupsummary(T, {'ptID','refLabel','axis'}, 'mean', 'JND');

    % Put hue and chroma means into separate table columns.
    Hwide = unstack(Hgrp, 'mean_JND', 'axis');

    % Avoid division by zero if a threshold is zero or missing.
    epsDen = 1e-12;
    hueSensitivity = 1 ./ max(Hwide.hue, epsDen);
    chromaSensitivity = 1 ./ max(Hwide.chroma, epsDen);
    Hwide.HSI = hueSensitivity ./ max(chromaSensitivity, epsDen);

    % Put purple and orange ratios into one row per participant, then keep only
    % participants with both reference colors.
    H_HSI = unstack(Hwide(:, {'ptID','refLabel','HSI'}), 'HSI', 'refLabel');
    H_HSI = rmmissing(H_HSI, 'DataVariables', {'purple','orange'});

    % x-axis is purple; y-axis is orange.
    xHuman = log10(H_HSI.purple);
    yHuman = log10(H_HSI.orange);
end

function [xMEG, yMEG, hasMEG] = loadMegLogOdds(meg_mat, humanIDs, timeWindow, stepIdx)
    % Load participant-level MEG log-odds ratios for a time window and step.
    %
    % Output coordinates are ordered to match the human scatter:
    %   xMEG = purple hue/chroma ratio
    %   yMEG = orange hue/chroma ratio

    % Load the MAT file and normalize legacy variable names.
    M = loadMegMat(meg_mat);
    logoddsratios = M.logoddsratios;

    % If no step is requested, average over all steps.
    if isempty(stepIdx)
        stepIdx = 1:size(logoddsratios, 4);
    end

    % Select MEG windows fully contained inside the requested time interval.
    timeIdx = M.timeWin(:,1) >= timeWindow(1) & M.timeWin(:,2) <= timeWindow(2);
    assert(any(timeIdx), 'No MEG time windows found within %.3f-%.3f s', timeWindow(1), timeWindow(2));

    % Data layout is subject x color x time x step. In this file, color index 1
    % is orange and color index 2 is purple.
    megOrange = squeeze(mean(mean(logoddsratios(:,1,timeIdx,stepIdx), 3, 'omitnan'), 4, 'omitnan'));
    megPurple = squeeze(mean(mean(logoddsratios(:,2,timeIdx,stepIdx), 3, 'omitnan'), 4, 'omitnan'));

    % Align MEG subjects to the human participant order so paired scatter plots
    % and participant-matched tests use the same rows.
    humanIDs = string(humanIDs);
    megIDs = string(M.subs(:));
    xMEG = nan(size(humanIDs));
    yMEG = nan(size(humanIDs));
    [hasMEG, loc] = ismember(humanIDs, megIDs);
    xMEG(hasMEG) = megPurple(loc(hasMEG));
    yMEG(hasMEG) = megOrange(loc(hasMEG));
    hasMEG = hasMEG & isfinite(xMEG) & isfinite(yMEG);
end

function reportMegParticipantDistanceAcrossSteps(meg_mat, humanIDs, xHuman, yHuman, timeWindow)
    % Print a participant-matched distance report for all MEG steps.
    %
    % This is useful for checking which MEG processing step is closest to the
    % human psychophysics mean and whether participant-level distances differ
    % across steps.

    nSteps = megStepCount(meg_mat);
    nHuman = numel(humanIDs);
    xByStep = nan(nHuman, nSteps);
    yByStep = nan(nHuman, nSteps);
    hasByStep = false(nHuman, nSteps);

    % Load one participant-aligned MEG coordinate set per step.
    for iStep = 1:nSteps
        [xStep, yStep, hasStep] = loadMegLogOdds(meg_mat, humanIDs, timeWindow, iStep);
        xByStep(:, iStep) = xStep(:);
        yByStep(:, iStep) = yStep(:);
        hasByStep(:, iStep) = hasStep(:);
    end

    % Keep only participants with valid human values and MEG values for every
    % step, so all pairwise step comparisons are paired.
    validHumanForMean = isfinite(xHuman(:)) & isfinite(yHuman(:));
    validMegAllSteps = validHumanForMean & all(hasByStep, 2) & all(isfinite(xByStep), 2) & all(isfinite(yByStep), 2);
    psychX = xHuman(validMegAllSteps);
    psychY = yHuman(validMegAllSteps);
    megX = xByStep(validMegAllSteps, :);
    megY = yByStep(validMegAllSteps, :);

    % Participant-matched distance between each MEG step point and that
    % participant's own psychophysical point, in log10 hue/chroma ratio space.
    participantDist = sqrt((megX - psychX).^2 + (megY - psychY).^2);

    % Two-tailed paired t-tests comparing the participant-matched distances
    % across MEG shift magnitudes (Fig. S4 statistics).
    for iStep = 1:nSteps
        for jStep = iStep+1:nSteps
            diffDist = participantDist(:, iStep) - participantDist(:, jStep);
            [p, ci, stats] = pairedTTestLocal(diffDist);
            fprintf('MEG step %d vs step %d: mean diff = %.4f, 95%% CI [%.4f, %.4f], t(%d) = %.2f, p = %.4g\n', ...
                iStep, jStep, mean(diffDist, 'omitnan'), ci(1), ci(2), stats.df, stats.tstat, p);
        end
    end
end

function [p, ci, stats] = pairedTTestLocal(vals)
    % Paired one-sample t-test on step-distance differences.
    %
    % vals contains participant-wise distance differences between two MEG steps.
    % The null hypothesis is that the mean difference is zero.

    % Remove missing values before computing the test.
    vals = vals(:);
    vals = vals(isfinite(vals));
    n = numel(vals);
    stats.df = n - 1;
    stats.tstat = NaN;
    p = NaN;
    ci = [NaN; NaN];
    if n < 2
        return
    end

    % Standard t statistic for a one-sample test of difference scores.
    meanVal = mean(vals, 'omitnan');
    sdVal = std(vals, 0, 'omitnan');
    seVal = sdVal ./ sqrt(n);

    % Handle the degenerate case where every participant has the same
    % difference, which makes the standard error zero.
    if seVal == 0
        stats.tstat = sign(meanVal) .* Inf;
        if meanVal == 0
            stats.tstat = 0;
            p = 1;
        else
            p = 0;
        end
        ci = [meanVal; meanVal];
        return
    end

    % Two-tailed p value and 95% confidence interval.
    stats.tstat = meanVal ./ seVal;
    p = 2 .* tTailProbabilityLocal(abs(stats.tstat), stats.df);
    tCrit = tInverseCdfLocal(0.975, stats.df);
    ci = meanVal + [-1; 1] .* tCrit .* seVal;
end

function p = tTailProbabilityLocal(t, df)
    % Upper-tail probability for Student's t distribution.
    % Uses the incomplete beta representation available in base MATLAB.
    if ~isfinite(t)
        p = double(t < 0);
        return
    end
    if df <= 0 || ~isfinite(df)
        p = NaN;
        return
    end

    t = abs(t);
    x = df ./ (df + t.^2);
    p = 0.5 .* betainc(x, df ./ 2, 0.5);
end

function t = tInverseCdfLocal(p, df)
    % Numeric inverse CDF for Student's t distribution using bisection.
    % This is used only for the 95% confidence interval in the console report.
    if p <= 0 || p >= 1 || df <= 0 || ~isfinite(df)
        t = NaN;
        return
    end
    if p == 0.5
        t = 0;
        return
    end
    if p < 0.5
        % Use symmetry of the t distribution.
        t = -tInverseCdfLocal(1 - p, df);
        return
    end

    % Expand the upper bound until it covers the requested probability.
    lo = 0;
    hi = 1;
    while tCdfLocal(hi, df) < p && hi < 1e6
        hi = hi .* 2;
    end

    % Bisection search for a stable inverse value.
    for i = 1:80
        mid = (lo + hi) ./ 2;
        if tCdfLocal(mid, df) < p
            lo = mid;
        else
            hi = mid;
        end
    end
    t = (lo + hi) ./ 2;
end

function p = tCdfLocal(t, df)
    % CDF wrapper built from the upper-tail helper and t-distribution symmetry.
    if t >= 0
        p = 1 - tTailProbabilityLocal(t, df);
    else
        p = tTailProbabilityLocal(-t, df);
    end
end

function [xByStep, yByStep, timeLabels, stepLabels] = loadMegTimecourseAllSteps(meg_mat, minTime, maxTime)
    % Load group-mean MEG trajectory points for selected time windows.
    %
    % Rows correspond to time windows. Columns correspond to MEG steps. The
    % returned values are already averaged across participants.

    M = loadMegMat(meg_mat);
    logoddsratios = M.logoddsratios;

    % Use time-window centers for selection and millisecond labels.
    nSteps = size(logoddsratios, 4);
    timeCenters = mean(M.timeWin, 2);
    timeLabelsAll = round(1000 * timeCenters);

    % Keep windows in the requested range and thin to 200 ms spacing so the
    % trajectory markers remain readable.
    timeIdx = timeCenters >= minTime & timeCenters <= maxTime & mod(timeLabelsAll, 200) == 0;
    assert(any(timeIdx), 'No MEG time windows found with centers from %.3f to %.3f s', minTime, maxTime);

    timeLabels = timeLabelsAll(timeIdx);
    nTimes = nnz(timeIdx);
    xByStep = nan(nTimes, nSteps);
    yByStep = nan(nTimes, nSteps);

    % Average over subjects for each selected time window. Color index 2 is
    % purple/x, and color index 1 is orange/y.
    for iStep = 1:nSteps
        xByStep(:, iStep) = squeeze(mean(logoddsratios(:,2,timeIdx,iStep), 1, 'omitnan'));
        yByStep(:, iStep) = squeeze(mean(logoddsratios(:,1,timeIdx,iStep), 1, 'omitnan'));
    end

    stepLabels = arrayfun(@(s) sprintf('Step %d', s), 1:nSteps, 'UniformOutput', false);

    % The time-course figure shows only step 3.
    stepKeep = intersect(3, 1:nSteps, 'stable');
    xByStep = xByStep(:, stepKeep);
    yByStep = yByStep(:, stepKeep);
    stepLabels = stepLabels(stepKeep);
end

function M = loadMegMat(meg_mat)
    % Load and validate the MEG MAT file.
    assert(isfile(meg_mat), 'MEG log odds ratio MAT not found: %s', meg_mat);
    M = load(meg_mat);

    % Normalize legacy variable names to M.logoddsratios.
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

function fig = plotMegTimecourseStepsFigure(xHuman, yHuman, xMEGTimeByStep, yMEGTimeByStep, timeLabels, stepLabels, twocolumn)
    % Plot MEG group-mean trajectories across time for selected steps.
    %
    % Each step is a line in hue/chroma ratio space. Markers show selected time
    % windows, and the black circle shows the human psychophysics mean.

    [minlim, maxlim] = plotLimits();
    fig = figure('Color', 'w');
    hold on;
    axis([minlim maxlim minlim maxlim]);

    addBackgroundGuides(minlim, maxlim);

    xHumanMean = mean(xHuman, 'omitnan');
    yHumanMean = mean(yHuman, 'omitnan');
    stepColors = [0.00 0.75 0.85];
    timeMarkers = {'^','s','d','v'};

    % Draw one trajectory per selected MEG step.
    nSteps = size(xMEGTimeByStep, 2);
    for iStep = 1:nSteps
        col = stepColors(min(iStep, size(stepColors,1)), :);
        plot(xMEGTimeByStep(:,iStep), yMEGTimeByStep(:,iStep), ...
            '-', 'Color', col, 'LineWidth', 1.0, 'HandleVisibility', 'off');
        for iTime = 1:size(xMEGTimeByStep, 1)
            marker = timeMarkers{min(iTime, numel(timeMarkers))};
            if iTime == 1
                % Only the first marker for each step gets a legend label.
                displayName = stepLabels{iStep};
            else
                displayName = '';
            end
            scatter(xMEGTimeByStep(iTime,iStep), yMEGTimeByStep(iTime,iStep), 50, col, ...
                marker, 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 0.35, 'DisplayName', displayName);
        end
    end

    scatter(xHumanMean, yHumanMean, 75, 'o', 'filled', ...
        'MarkerFaceColor', 'k', ...
        'MarkerEdgeColor', 'w', ...
        'DisplayName', 'Human mean');

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
