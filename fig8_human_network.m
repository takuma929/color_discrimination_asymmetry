%% fig8_human_network.m
% Plot human psychophysics, MEG, neural-network models, and task-comparison
% MEG controls in one hue/chroma ratio summary figure.
%
% One figure is produced (fig8_human_network): one point per network, averaged
% across all layers/depths (with SE bars).
%
% Coordinates are computed as:
%   sensitivity = 1 / threshold
%   plotted value = log10(hue sensitivity / chroma sensitivity)
%
% For the decoding-accuracy task-comparison data, accuracies are averaged over
% the selected MEG time window first, then converted to odds ratios:
%   odds = accuracy / (1 - accuracy)
%   plotted value = log10(odds_hue / odds_chroma)
%
% The script is operating-system independent: all input/output paths are built
% with fullfile and resolved relative to this file.

clear; clc; close all

%% ------------------------- PATHS AND OPTIONS ----------------------------

% Resolve the repository/script folder from this file rather than relying on
% MATLAB's current working directory.
scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

% Networks included in the model summary.
allNetworks = {'resnet50','resnet50_flips', ...
               'places365_resnet50','places365_resnet18', ...
               'resnet18', ...
               'keypointrcnn_resnet50_fpn_coco_scratch', ...
               'fasterrcnn_resnet50_fpn_coco_scratch'};

% Input files.
human_csv = fullfile(scriptDir, 'data', 'human', 'human_thresholds.csv');
meg_mat = fullfile(scriptDir, 'data', 'meg_log_odds_ratios.mat');
decoding_acc_mat = fullfile(scriptDir, 'data', 'meg_decoding_accuracies.mat');

% Output folder and figure sizing.
outdir = fullfile(scriptDir, 'figs');
doSave = true;
twocolumn = 17.8;

% MEG settings shared with fig5.
meg_time_window = [0.35 0.65];
meg_step_idx = 3;

%% ------------------------- HUMAN DATA -----------------------------------

% Load human JND data and normalize categories.
assert(isfile(human_csv), 'Human CSV not found: %s', human_csv);
T = readtable(human_csv, 'TextType','string');
T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);

% Keep the same participant/trial filter as the other human scripts.
if ismember('orange_hue_focused', T.Properties.VariableNames)
    T = T(T.orange_hue_focused == 1, :);
end

T.ptID = string(T.ptID);
T.axis = lower(string(T.hue_chroma));
T.refLabel = lower(string(T.quadrant));
T.sign = lower(string(T.direction));

% Human x/y coordinates: purple and orange log10 hue/chroma sensitivity ratios.
[H_HSI, xHuman, yHuman] = humanSensitivityHSI(T);

%% ------------------------- MEG AND NETWORK DATA -------------------------

% Participant-aligned MEG log-odds ratios from the main MEG analysis.
[xMEG, yMEG, hasMEG] = loadMegLogOdds(meg_mat, H_HSI.ptID, meg_time_window, meg_step_idx);

% One point per neural network, averaged across model layers/depths.
HSI_all = struct;
for k = 1:numel(allNetworks)
    network = allNetworks{k};
    HSI_all.(network) = networkSensitivityHSI(network, scriptDir);
end

% Task-comparison controls from raw decoding accuracies. As in fig5d:
% supplementary experiment step 3 = color task; control experiment step 3 =
% orientation task.
[controlColorMEG, controlOrientationMEG] = loadDecodingAccuracyControlLogOdds(decoding_acc_mat, meg_time_window);

%% ------------------------- PLOT AND SAVE --------------------------------

if doSave && ~exist(outdir, 'dir')
    mkdir(outdir);
end

% labelTasks: when true, write each point's task name next to its marker.
plotOptions = struct('wideLayout', false, 'labelTasks', false);

% One network point averaged across all layers/depths.
fig = plotFig8Summary(xHuman, yHuman, xMEG, yMEG, hasMEG, ...
    HSI_all, allNetworks, controlColorMEG, controlOrientationMEG, ...
    twocolumn, plotOptions);

if doSave
    pause(0.1)
    exportgraphics(fig, fullfile(outdir, 'fig8_human_network.pdf'), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
    fprintf('%s successfully saved.\n', 'fig8_human_network.pdf');
end

%% ------------------------- HUMAN HELPERS --------------------------------

function [H_HSI, xHuman, yHuman] = humanSensitivityHSI(T)
    % Average repeated human measurements within participant/reference/axis and
    % convert thresholds to log10 hue/chroma sensitivity ratios.
    Hgrp = groupsummary(T, {'ptID','refLabel','axis'}, 'mean', 'JND');
    Hwide = unstack(Hgrp, 'mean_JND', 'axis');

    epsDen = 1e-12;
    hueSensitivity = 1 ./ max(Hwide.hue, epsDen);
    chromaSensitivity = 1 ./ max(Hwide.chroma, epsDen);
    Hwide.HSI = hueSensitivity ./ max(chromaSensitivity, epsDen);

    H_HSI = unstack(Hwide(:, {'ptID','refLabel','HSI'}), 'HSI', 'refLabel');
    H_HSI = rmmissing(H_HSI, 'DataVariables', {'purple','orange'});

    xHuman = log10(H_HSI.purple);
    yHuman = log10(H_HSI.orange);
end

%% ------------------------- NETWORK HELPERS ------------------------------

function H = networkSensitivityHSI(network, scriptDir)
    % Load one network's threshold summary and average ratio coordinates across
    % its available layers/depths.
    D = networkDepthHSI(network, scriptDir);

    H.type = D.type;
    H.color = D.color;
    H.x = mean(D.x, 'omitnan');
    H.y = mean(D.y, 'omitnan');
    H.xSE = std(D.x, 'omitnan') / sqrt(numel(D.x));
    H.ySE = std(D.y, 'omitnan') / sqrt(numel(D.y));
end

function D = networkDepthHSI(network, scriptDir)
    % Load one network's threshold summary and return per-layer/depth ratio
    % coordinates (one (purple, orange) point per available depth), preserving
    % stem-first / fully-connected-last layer ordering.
    network_csv = fullfile(scriptDir, 'data', 'network', [network, '_thresholds.csv']);
    assert(isfile(network_csv), 'Network CSV not found: %s', network_csv);

    N = readtable(network_csv, 'TextType', 'string');
    N.Properties.VariableNames = matlab.lang.makeValidName(N.Properties.VariableNames);

    if ~ismember("threshold_se", N.Properties.VariableNames)
        N.threshold_se = nan(height(N), 1);
    end

    N.depth = lower(string(N.depth));
    N.refLabel = lower(string(N.quadrant));
    N.axis = lower(string(N.hue_chroma));
    N.sign = lower(string(N.direction));

    % Preserve useful layer ordering: first layer first, final layer last.
    depths = unique(N.depth, 'stable');
    dmid = setdiff(depths, ["layer_1","final_layer"], 'stable');
    if any(depths == "layer_1"), dmid = ["layer_1"; dmid]; end
    if any(depths == "final_layer"), dmid = [dmid; "final_layer"]; end
    depths = dmid;

    xVals = [];
    yVals = [];
    depthsKept = strings(0, 1);
    epsDen = 1e-12;

    for d = 1:numel(depths)
        % Build a threshold struct for this layer, average positive/negative
        % directions, then convert thresholds to sensitivities.
        rows = N(N.depth == depths(d), :);
        S = networkThresholdStruct(rows);

        mp = meanOfTwo(S.purple.chroma.pos.mean, S.purple.chroma.neg.mean);
        hp = meanOfTwo(S.purple.hue.pos.mean, S.purple.hue.neg.mean);
        mo = meanOfTwo(S.orange.chroma.pos.mean, S.orange.chroma.neg.mean);
        ho = meanOfTwo(S.orange.hue.pos.mean, S.orange.hue.neg.mean);

        purpleHueSensitivity = 1 / max(hp, epsDen);
        purpleChromaSensitivity = 1 / max(mp, epsDen);
        orangeHueSensitivity = 1 / max(ho, epsDen);
        orangeChromaSensitivity = 1 / max(mo, epsDen);

        xi = log10(purpleHueSensitivity / max(purpleChromaSensitivity, epsDen));
        yi = log10(orangeHueSensitivity / max(orangeChromaSensitivity, epsDen));

        if isfinite(xi) && isfinite(yi)
            xVals(end+1) = xi; %#ok<AGROW>
            yVals(end+1) = yi; %#ok<AGROW>
            depthsKept(end+1) = depths(d); %#ok<AGROW>
        end
    end

    [typeStr, netColor] = netTypeAndColor(network);
    D.type = typeStr;
    D.color = netColor;
    D.depths = depthsKept(:);
    D.x = xVals(:);
    D.y = yVals(:);
end

function Sdepth = networkThresholdStruct(Nrows)
    % Convert rows for one network layer into a nested threshold struct.
    refs = unique(Nrows.refLabel);
    Sdepth = struct();
    for i = 1:numel(refs)
        r = refs(i);
        R = Nrows(Nrows.refLabel == r, :);
        Sdepth.(r).chroma.pos = getDirStats(R, "chroma", "pos");
        Sdepth.(r).chroma.neg = getDirStats(R, "chroma", "neg");
        Sdepth.(r).hue.pos = getDirStats(R, "hue", "pos");
        Sdepth.(r).hue.neg = getDirStats(R, "hue", "neg");
    end
end

function st = getDirStats(T, axisName, signName)
    % Extract the mean threshold for one hue/chroma axis and pos/neg sign.
    idx = T.axis == axisName & T.sign == signName;
    st.mean = mean(T.threshold_mean(idx), 'omitnan');
end

function m = meanOfTwo(m1, m2)
    % Average positive and negative directions for one axis.
    m = mean([m1, m2], 'omitnan');
end

%% ------------------------- MEG HELPERS ----------------------------------

function [xMEG, yMEG, hasMEG] = loadMegLogOdds(meg_mat, humanIDs, timeWindow, stepIdx)
    % Load participant-level MEG log-odds ratios for a chosen time window and
    % step, aligned to the human participant order.
    assert(isfile(meg_mat), 'MEG log odds ratio MAT not found: %s', meg_mat);
    M = load(meg_mat);
    if isfield(M, 'logoddsratios')
        logoddsratios = M.logoddsratios;
    elseif isfield(M, 'logoddsratio')
        logoddsratios = M.logoddsratio;
    else
        error('No logoddsratios/logoddsratio variable found in %s', meg_mat);
    end
    assert(isfield(M, 'subs'), 'No subs variable found in %s', meg_mat);
    assert(isfield(M, 'timeWin'), 'No timeWin variable found in %s', meg_mat);

    if isempty(stepIdx)
        stepIdx = 1:size(logoddsratios, 4);
    end
    timeIdx = M.timeWin(:,1) >= timeWindow(1) & M.timeWin(:,2) <= timeWindow(2);
    assert(any(timeIdx), 'No MEG time windows found within %.3f-%.3f s', timeWindow(1), timeWindow(2));

    % Color index 1 is orange/y; color index 2 is purple/x.
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

function [controlColorMEG, controlOrientationMEG] = loadDecodingAccuracyControlLogOdds(decoding_acc_mat, timeWindow)
    % Load raw decoding accuracies and convert them into task-comparison log
    % odds ratios. Accuracies are averaged over time before the odds transform.
    assert(isfile(decoding_acc_mat), 'Decoding accuracy MAT not found: %s', decoding_acc_mat);
    S = load(decoding_acc_mat, 'dec');
    assert(isfield(S, 'dec'), 'Variable dec not found in %s', decoding_acc_mat);
    dec = S.dec;

    expIdx.supplementary = 1;
    expIdx.control = 3;

    % fig5d mapping: supplementary experiment step 3 = color task; control
    % experiment step 3 = orientation task.
    [controlColorMEG.x, controlColorMEG.y] = decodingAccuracyLogOddsForExperiment(dec, expIdx.supplementary, timeWindow, 3);
    [controlOrientationMEG.x, controlOrientationMEG.y] = decodingAccuracyLogOddsForExperiment(dec, expIdx.control, timeWindow, 3);
end

function [xVals, yVals] = decodingAccuracyLogOddsForExperiment(dec, expIdx, timeWindow, stepLevel)
    % Compute participant-level purple/orange log odds ratios from one
    % experiment's decoding accuracy array.
    acc = double(dec.acc_agg{expIdx});
    accDims = string(dec.accDims);
    dimLevs = normalizeDecodingDimLevels(dec.accDimLevs, accDims);
    accTime = double(dec.accTime);

    % Average raw accuracies across the requested time window before odds.
    timeDim = findDimensionByName(accDims, "time");
    timeIdx = accTime >= timeWindow(1) & accTime <= timeWindow(2);
    assert(any(timeIdx), 'No decoding accuracy time points found within %.3f-%.3f s', timeWindow(1), timeWindow(2));
    acc = selectAlongDimension(acc, timeDim, timeIdx);
    acc = mean(acc, timeDim, 'omitnan');

    refDim = findDimensionWithLevels(dimLevs, ["purple","orange"]);
    axisDim = findDimensionWithLevels(dimLevs, ["hue","chroma"]);
    participantDim = findDimensionByName(accDims, "pt");

    % Keep only the requested step, then average all remaining nuisance
    % dimensions while retaining participant identity.
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

function dimLevs = normalizeDecodingDimLevels(dimLevsRaw, accDims)
    % Convert dec.accDimLevs struct into a cell array aligned with accDims.
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

function odds = localOdds(acc)
    % Convert decoding accuracy to finite odds.
    epsAcc = 1e-6;
    acc = min(max(acc, epsAcc), 1 - epsAcc);
    odds = acc ./ (1 - acc);
end

%% ------------------------- PLOTTING HELPERS -----------------------------

function fig = plotFig8Summary(xHuman, yHuman, xMEG, yMEG, hasMEG, HSI_all, allNetworks, controlColorMEG, controlOrientationMEG, twocolumn, plotOptions, humanMean)
    % Draw humans, MEG, networks, and task-comparison controls in one panel.
    %
    % If humanMean (a [purple orange] pair) is supplied, HSI_all is treated as a
    % per-depth struct and each network is drawn at the single layer/depth whose
    % point is closest to the human mean. Otherwise HSI_all is the averaged
    % per-network struct and each network is drawn once with SE bars.
    if nargin < 11
        plotOptions = struct();
    end
    if nargin < 12
        humanMean = [];
    end
    plotOptions = defaultFig8PlotOptions(plotOptions);

    % Match the fig6 step-3 (large shift) time-lapse axis range.
    minlim = -0.17;
    maxlim = 0.4;

    fig = figure('Color', 'w');
    hold on;
    axis([minlim maxlim minlim maxlim]);
    addBackgroundGuides(minlim, maxlim);

    % Human mean only. Individual human points are intentionally omitted for the
    % final figure.
    xHumanMean = mean(xHuman, 'omitnan');
    yHumanMean = mean(yHuman, 'omitnan');
    scatter(xHumanMean, yHumanMean, 75, 'o', 'filled', ...
        'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w', 'DisplayName', 'Human mean');
    if plotOptions.labelTasks
        addTaskLabel(xHumanMean, yHumanMean, 'Human', [0 0 0]);
    end

    % MEG mean only. Individual MEG participant points are intentionally omitted.
    if ~isempty(hasMEG) && any(hasMEG)
        xMEGMean = mean(xMEG(hasMEG), 'omitnan');
        yMEGMean = mean(yMEG(hasMEG), 'omitnan');
        scatter(xMEGMean, yMEGMean, 70, '^', 'filled', ...
            'MarkerFaceColor', [0.00 0.75 0.85], 'MarkerEdgeColor', 'k', ...
            'LineWidth', 0.5, 'MarkerFaceAlpha', 1.0, 'DisplayName', 'MEG mean');
        if plotOptions.labelTasks
            addTaskLabel(xMEGMean, yMEGMean, 'MEG', [0.00 0.75 0.85]);
        end
    end

    % Network model points: averaged across layers, or at the most human-aligned
    % layer when a human mean is supplied.
    if isempty(humanMean)
        drawNetworkPoints(HSI_all, allNetworks, 90, plotOptions);
    else
        drawNetworkAlignedPoints(HSI_all, allNetworks, humanMean, 90, plotOptions);
    end

    % Task-comparison control means from fig5d. Individual control participants
    % are intentionally omitted.
    colorCol = [1.00 0.45 0.45];
    orientationCol = [0.35 0.55 1.00];
    xColor = mean(controlColorMEG.x, 'omitnan');
    yColor = mean(controlColorMEG.y, 'omitnan');
    xOrient = mean(controlOrientationMEG.x, 'omitnan');
    yOrient = mean(controlOrientationMEG.y, 'omitnan');
    scatter(xColor, yColor, 70, colorCol, '^', 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'MarkerFaceAlpha', 1.0, ...
        'DisplayName', 'Task-comp. MEG: color mean');
    scatter(xOrient, yOrient, 120, orientationCol, 'p', 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'MarkerFaceAlpha', 1.0, ...
        'DisplayName', 'Task-comp. MEG: orientation mean');
    if plotOptions.labelTasks
        addTaskLabel(xColor, yColor, 'Color task', colorCol);
        addTaskLabel(xOrient, yOrient, 'Orientation task', orientationCol);
    end

    xlabel('log_1_0 hue / chroma (purple)', 'FontWeight', 'bold');
    ylabel('log_1_0 hue / chroma (orange)', 'FontWeight', 'bold');
    styleScatterAxes(fig, twocolumn, minlim, maxlim, plotOptions);
end

function plotOptions = defaultFig8PlotOptions(plotOptions)
    if ~isfield(plotOptions, 'wideLayout')
        plotOptions.wideLayout = false;
    end
    if ~isfield(plotOptions, 'labelTasks')
        plotOptions.labelTasks = false;
    end
end

function addTaskLabel(x, y, labelStr, col)
    % Write a task name just to the upper-right of a data point, in a slightly
    % darkened version of the marker color.
    if isempty(labelStr) || ~isfinite(x) || ~isfinite(y)
        return
    end
    text(x + 0.012, y + 0.012, labelStr, ...
        'Color', col * 0.7, 'FontName', 'Arial', 'FontSize', 5.5, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
        'Interpreter', 'none', 'HandleVisibility', 'off');
end

function addBackgroundGuides(minlim, maxlim)
    % Shared ratio-space guides: triangular regions, diagonal equality, and zero
    % reference lines.
    patch([minlim maxlim maxlim], [minlim minlim maxlim], [0.80 0.20 0.90], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.08);
    patch([minlim minlim maxlim], [minlim maxlim maxlim], [0.85 0.33 0.10], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.08);
    plot([minlim maxlim], [minlim maxlim], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
    line([0 0], [minlim maxlim], 'LineStyle', ':', 'Color', 'k', 'LineWidth', 1);
    line([minlim maxlim], [0 0], 'LineStyle', ':', 'Color', 'k', 'LineWidth', 1);
end

function styleScatterAxes(fig, twocolumn, minlim, maxlim, plotOptions)
    % Apply common figure size, axis size, ticks, and styling.
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
    if plotOptions.wideLayout
        fig.PaperPosition = [0, 10, twocolumn, 8.5];
        fig.Position = [10, 10, twocolumn, 8.5];
    else
        fig.PaperPosition = [0, 10, 8.5, 8.5];
        fig.Position = [10, 10, twocolumn/2*0.9, twocolumn/2*0.9];
    end

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

function drawNetworkPoints(HSI_all, allNetworks, networkMarkerArea, plotOptions)
    % Draw one marker per network (averaged across layers), including SE bars.
    if nargin < 4
        plotOptions = struct('labelTasks', false);
    end
    for k = 1:numel(allNetworks)
        nk = allNetworks{k};
        col = HSI_all.(nk).color;
        xi = HSI_all.(nk).x;
        yi = HSI_all.(nk).y;
        xSE = HSI_all.(nk).xSE;
        ySE = HSI_all.(nk).ySE;

        [markerShape, markerArea] = networkMarker(nk, networkMarkerArea);

        errorbar(xi, yi, ySE, ySE, 'Color', col, 'LineWidth', 0.6, 'CapSize', 0, ...
            'HandleVisibility', 'off');
        line([xi - xSE, xi + xSE], [yi yi], 'Color', col, 'LineWidth', 0.6, ...
            'HandleVisibility', 'off');

        scatter(xi, yi, markerArea, 'Marker', markerShape, ...
            'MarkerFaceColor', col, 'MarkerEdgeColor', 'none', ...
            'DisplayName', nk);

        if plotOptions.labelTasks
            addTaskLabel(xi, yi, HSI_all.(nk).type, col);
        end
    end
end

function drawNetworkAlignedPoints(HSI_depth_all, allNetworks, humanMean, networkMarkerArea, plotOptions)
    % Draw one marker per network at the single layer/depth whose (purple, orange)
    % point is closest to the human psychophysical mean. No SE bars, since each
    % marker is a single layer rather than an average across layers.
    if nargin < 5
        plotOptions = struct('labelTasks', false);
    end
    for k = 1:numel(allNetworks)
        nk = allNetworks{k};
        D = HSI_depth_all.(nk);
        col = D.color;

        idxs = find(isfinite(D.x) & isfinite(D.y));
        if isempty(idxs)
            continue
        end
        d2 = (D.x(idxs) - humanMean(1)).^2 + (D.y(idxs) - humanMean(2)).^2;
        [~, mi] = min(d2);
        best = idxs(mi);
        xi = D.x(best);
        yi = D.y(best);

        [markerShape, markerArea] = networkMarker(nk, networkMarkerArea);

        scatter(xi, yi, markerArea, 'Marker', markerShape, ...
            'MarkerFaceColor', col, 'MarkerEdgeColor', 'none', ...
            'DisplayName', nk);

        if plotOptions.labelTasks
            addTaskLabel(xi, yi, D.type, col);
        end
    end
end

function [markerShape, markerArea] = networkMarker(nk, networkMarkerArea)
    % Marker shape and size per network family, shared by the averaged and
    % human-aligned network plots.
    if contains(nk, 'resnet50')
        markerShape = 'd';
        markerArea = 48;
    elseif contains(nk, 'resnet18')
        markerShape = 's';
        markerArea = 72;
    else
        markerShape = '^';
        markerArea = networkMarkerArea;
    end
end

function [typeStr, col] = netTypeAndColor(netname)
    % Group networks by task family and assign colors that stay distinct from
    % the red color-task and blue orientation-task MEG markers.
    if contains(netname, "coco_scratch")
        % COCO-from-scratch ResNet50 models. Both are gray, but pose estimation
        % (keypoint) is darker than object detection so the two are distinct.
        if contains(netname, "keypointrcnn")
            typeStr = 'Keypoint (COCO scratch)';
            col = [0.25 0.25 0.25];
        else
            typeStr = 'Detection (COCO scratch)';
            col = [0.65 0.65 0.65];
        end
    elseif startsWith(netname, "places365")
        typeStr = 'Places classifier';
        col = [0.00 0.55 0.45];
    elseif contains(netname, "fasterrcnn")
        typeStr = 'Detection';
        col = [0.35 0.35 0.35];
    elseif contains(netname, "keypointrcnn")
        typeStr = 'Keypoint';
        col = [0.70 0.70 0.70];
    elseif contains(netname, "flips")
        typeStr = 'ImageNet classifier flips';
        col = [0.55 0.28 0.72];
    else
        typeStr = 'ImageNet classifier';
        col = [0.90 0.50 0.00];
    end
end
