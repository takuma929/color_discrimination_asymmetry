%% fig5_decoding_acc.m
% Reproduce Figure 5 from meg_decoding_accuracies.mat.
%
% Panels a-d plot group-mean decoding accuracy time courses for the main MEG
% experiment. Panel e plots log10 hue/chroma decoding odds ratios. Each panel
% is saved as a separate one-column figure.

clear; clc; close all

%% ------------------------- PATHS AND OPTIONS ----------------------------

scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

dataFile = fullfile(scriptDir, 'data', 'meg_decoding_accuracies.mat');
outdir = fullfile(scriptDir, 'figs');
if ~exist(outdir, 'dir')
    mkdir(outdir);
end

assert(isfile(dataFile), 'Decoding accuracy MAT file not found: %s', dataFile);
S = load(dataFile, 'dec');
assert(isfield(S, 'dec'), 'Variable dec not found in %s', dataFile);
dec = S.dec;

% The decoding file stores experiments as:
%   1 = task-comparison color experiment
%   2 = main MEG experiment
%   3 = task-comparison orientation experiment
expIdx = 2;

plotTimeMs = [-250 1500];
chancePercent = 50;
doSave = true;

purpleCols = [0.52 0.16 0.86; 0.50 0.54 1.00; 0.68 0.60 0.84];
orangeCols = [0.82 0.38 0.10; 1.00 0.45 0.00; 1.00 0.60 0.00];

%% ------------------------- LOAD DECODING DATA ---------------------------

acc = double(localExperimentValue(dec.acc_agg, expIdx));
accDims = string(localDecMetadataValue(dec, expIdx, ["accDims", "dims", "Dims"]));
dimLevs = localNormalizeDimLevels( ...
    localDecMetadataValue(dec, expIdx, ["accDimLevs", "DimLevs", "dimLevs", "DimLevels", "dimLevels"]), accDims);
timeSec = double(localDecMetadataValue(dec, expIdx, ["accTime", "time", "times"]));

timeDim = localFindDimByName(accDims, "time");
stepDim = localFindDimByName(accDims, "step");
refDim = localFindDimByName(accDims, ["quad", "ref", "reference"]);
axisDim = localFindDimByName(accDims, ["hc", "axis", "dimension"]);
ptDim = localFindDimByName(accDims, ["pt", "participant", "observer"]);

timeMs = timeSec(:)' * 1000;

conditions = struct( ...
    'ref',  {'purple', 'purple',  'orange', 'orange'}, ...
    'axis', {'hue',    'chroma',  'hue',    'chroma'}, ...
    'title', {'Purple-hue', 'Purple-chroma', 'Orange-hue', 'Orange-chroma'}, ...
    'cols', {purpleCols, purpleCols, orangeCols, orangeCols});

tc = struct();
for iCond = 1:numel(conditions)
    key = char(conditions(iCond).ref + "_" + conditions(iCond).axis);
    tc.(key).mean = nan(numel(timeSec), 3);
    tc.(key).sem = nan(numel(timeSec), 3);
    tc.(key).sig = false(numel(timeSec), 3);
    for iStep = 1:3
        subjByTime = localConditionAccuracy(acc, accDims, dimLevs, timeDim, refDim, axisDim, stepDim, ptDim, ...
            conditions(iCond).ref, conditions(iCond).axis, iStep);
        subjByTime = localAsPercent(subjByTime);
        tc.(key).subjByTime(:, :, iStep) = subjByTime;
        tc.(key).mean(:, iStep) = mean(subjByTime, 1, 'omitnan')';
        tc.(key).sem(:, iStep) = std(subjByTime, 0, 1, 'omitnan')' ./ sqrt(sum(isfinite(subjByTime), 1))';
        tc.(key).sig(:, iStep) = localSignificantMask(dec, expIdx, conditions(iCond).ref, conditions(iCond).axis, iStep, timeSec, accDims, dimLevs);
    end
end

ratio = localBuildRatioTimecourses(tc, dec, expIdx, timeSec);

%% ------------------------- PLOT -----------------------------------------

if doSave
    for iCond = 1:4
        panelFig = localNewPanelFigure(false);
        panelAx = localNewPanelAxes(panelFig, true);
        key = char(conditions(iCond).ref + "_" + conditions(iCond).axis);
        localPlotDecodingPanel(panelAx, timeMs, tc.(key), conditions(iCond), chancePercent, plotTimeMs);
        localSavePanel(panelFig, outdir, sprintf('fig5%c_decoding_acc', char('a' + iCond - 1)));
    end

    panelFig = localNewPanelFigure(true);
    panelAx = localNewPanelAxes(panelFig, false);
    localPlotRatioPanel(panelAx, timeMs, ratio, plotTimeMs);
    localSavePanel(panelFig, outdir, 'fig5e_decoding_acc');
end

%% ------------------------- EXTRACTION -----------------------------------

function subjByTime = localConditionAccuracy(acc, accDims, dimLevs, timeDim, refDim, axisDim, stepDim, ptDim, refName, axisName, stepLevel)
    A = acc;
    A = localSelectDim(A, refDim, localFindLevelIndex(dimLevs{refDim}, refName));
    A = localSelectDim(A, axisDim, localFindLevelIndex(dimLevs{axisDim}, axisName));
    A = localSelectDim(A, stepDim, localFindLevelIndex(dimLevs{stepDim}, stepLevel));

    keepDims = [timeDim, ptDim];
    for d = ndims(A):-1:1
        if ~ismember(d, keepDims)
            A = mean(A, d, 'omitnan');
        end
    end

    A = permute(A, [ptDim, timeDim, setdiff(1:ndims(A), [ptDim timeDim], 'stable')]);
    subjByTime = squeeze(A);
    if isvector(subjByTime)
        subjByTime = reshape(subjByTime, 1, []);
    end

    expectedTime = size(acc, timeDim);
    if size(subjByTime, 2) ~= expectedTime && size(subjByTime, 1) == expectedTime
        subjByTime = subjByTime';
    end
end

function ratio = localBuildRatioTimecourses(tc, dec, expIdx, timeSec)
    names = ["purple", "orange"];
    cols = struct();
    cols.purple = [0.52 0.16 0.86; 0.50 0.54 1.00; 0.68 0.60 0.84];
    cols.orange = [0.82 0.38 0.10; 1.00 0.45 0.00; 1.00 0.60 0.00];
    ratio = struct('label', {}, 'y', {}, 'color', {}, 'sig', {});
    for iRef = 1:numel(names)
        ref = names(iRef);
        hue = tc.(char(ref + "_hue")).subjByTime ./ 100;
        chroma = tc.(char(ref + "_chroma")).subjByTime ./ 100;
        participantRatio = log10(localOdds(hue) ./ localOdds(chroma));
        y = squeeze(mean(participantRatio, 1, 'omitnan'));
        for iStep = 1:3
            ratio(end+1).label = sprintf('%s step %d', ref, iStep); %#ok<AGROW>
            ratio(end).y = y(:, iStep);
            ratio(end).color = cols.(char(ref))(iStep, :);
            % Significant time points (p < 0.05) of the log-odds-ratio, from the
            % cluster-based permutation test stored in dec.acc_statsLOR.
            ratio(end).sig = localSignificantMaskLOR(dec, expIdx, ref, iStep, timeSec);
        end
    end
end

function mask = localSignificantMaskLOR(dec, expIdx, refName, stepLevel, timeSec)
    % Significant time points (p < 0.05) for one hue/chroma log-odds-ratio line,
    % read from dec.acc_statsLOR. acc_statsLOR is a per-experiment cell of
    % (quad x step) structs, each with a time-resolved p-value field .prob.
    mask = false(numel(timeSec), 1);
    if ~isfield(dec, 'acc_statsLOR')
        return
    end

    S = dec.acc_statsLOR;
    if iscell(S)
        if numel(S) < expIdx || isempty(S{expIdx})
            return
        end
        S = S{expIdx};
    end

    % Drop singleton dimensions so the array is (quad, step).
    S = squeeze(S);

    quadIdx = localStatsLevelIndex(dec, 'quad', refName);
    stepIdx = localStatsStepIndex(dec, stepLevel);
    if isempty(quadIdx) || isempty(stepIdx)
        return
    end
    if quadIdx > size(S, 1) || stepIdx > size(S, 2)
        return
    end

    if iscell(S)
        s = S{quadIdx, stepIdx};
    else
        s = S(quadIdx, stepIdx);
    end
    if ~isstruct(s) || ~isfield(s, 'prob')
        return
    end
    p = double(s.prob(:));
    n = min(numel(p), numel(timeSec));
    mask(1:n) = p(1:n) < 0.05;
end

function mask = localSignificantMask(dec, expIdx, refName, axisName, stepLevel, timeSec, accDims, dimLevs) %#ok<INUSD>
    % Significant time points (p < 0.05) for one condition, read from the stats
    % stored in dec.acc_statsAcc. acc_statsAcc is a per-experiment cell of
    % (quad x hc x step) structs, each with a time-resolved p-value field .prob.
    mask = false(numel(timeSec), 1);
    if ~isfield(dec, 'acc_statsAcc')
        return
    end

    S = dec.acc_statsAcc;
    if iscell(S)
        if numel(S) < expIdx || isempty(S{expIdx})
            return
        end
        S = S{expIdx};
    end

    % The per-experiment stats array is stored with singleton dimensions
    % (e.g. 1 x quad x hc x 1 x step); drop them so it is (quad, hc, step).
    S = squeeze(S);

    quadIdx = localStatsLevelIndex(dec, 'quad', refName);
    hcIdx   = localStatsLevelIndex(dec, 'hc', axisName);
    stepIdx = localStatsStepIndex(dec, stepLevel);
    if isempty(quadIdx) || isempty(hcIdx) || isempty(stepIdx)
        return
    end
    if quadIdx > size(S, 1) || hcIdx > size(S, 2) || stepIdx > size(S, 3)
        return
    end

    if iscell(S)
        s = S{quadIdx, hcIdx, stepIdx};
    else
        s = S(quadIdx, hcIdx, stepIdx);
    end
    if ~isstruct(s) || ~isfield(s, 'prob')
        return
    end
    p = double(s.prob(:));
    n = min(numel(p), numel(timeSec));
    mask(1:n) = p(1:n) < 0.05;
end

function idx = localStatsLevelIndex(~, fieldName, levelName)
    % acc_statsAcc has a fixed (quad, hc, step) layout, verified against acc_agg:
    %   quad = [purple, orange], hc = [hue, chroma].
    switch lower(string(fieldName))
        case "quad"
            order = ["purple", "orange"];
        case "hc"
            order = ["hue", "chroma"];
        otherwise
            order = strings(1, 0);
    end
    idx = find(order == lower(string(levelName)), 1, 'first');
end

function idx = localStatsStepIndex(~, stepLevel)
    % Steps are stored in order 1, 2, 3 along the acc_statsAcc step dimension.
    idx = double(stepLevel);
end

%% ------------------------- PLOTTING -------------------------------------

function localPlotDecodingPanel(ax, timeMs, D, cond, chancePercent, plotTimeMs)
    hold(ax, 'on');
    for iStep = 1:3
        plot(ax, timeMs, D.mean(:, iStep), 'Color', cond.cols(iStep, :), 'LineWidth', 0.8);
    end

    yline(ax, chancePercent, ':', 'Color', [0.25 0.25 0.25], 'LineWidth', 0.8);
    xline(ax, 0, '-', 'Color', 'k', 'LineWidth', 0.8);
    xlim(ax, plotTimeMs);
    ylim(ax, [40 80]);

    yBase = 46.0;
    ySpacing = 1.7;
    for iStep = 1:3
        % Reverse order with a gap so the darker (lower-step) color sits below.
        localDrawSigBars(ax, timeMs, D.sig(:, iStep), yBase - ySpacing * (3 - iStep), cond.cols(iStep, :), plotTimeMs);
    end

    yticks(ax, [40 50 60 70 80]);
    xticks(ax, -250:250:1500);
    xlabel(ax, 'Time [ms]', 'FontWeight', 'bold');
    ylabel(ax, 'Decoding accuracy [%]', 'FontWeight', 'bold');
    title(ax, cond.title, 'FontWeight', 'normal', 'HorizontalAlignment', 'left');
    localStyleTimeAxis(ax);
    ax.Title.Position(1) = 0.00;
end

function localPlotRatioPanel(ax, timeMs, ratio, plotTimeMs)
    hold(ax, 'on');
    for iLine = 1:numel(ratio)
        plot(ax, timeMs, ratio(iLine).y, 'Color', ratio(iLine).color, 'LineWidth', 0.8);
    end
    yline(ax, 0, ':', 'Color', [0.25 0.25 0.25], 'LineWidth', 0.8);
    xline(ax, 0, '-', 'Color', 'k', 'LineWidth', 0.8);
    xlim(ax, plotTimeMs);
    % The y-axis is extended below -0.10 to make room for a strip of
    % significance bars; the labelled tick range is unchanged.
    ylim(ax, [-0.16 0.35]);
    xticks(ax, -250:250:1500);
    ratioTicks = -0.10:0.10:0.30;
    yticks(ax, ratioTicks);
    yticklabels(ax, compose('%.2f', ratioTicks));
    xlabel(ax, 'Time [ms]', 'FontWeight', 'bold');
    ylabel(ax, 'log-odds-ratio of decoding accuracy', 'FontWeight', 'bold');

    % Significance bars (cluster-based permutation test on the log-odds-ratio,
    % dec.acc_statsLOR) drawn in a strip below the data, one per line. Lines are
    % grouped by reference (purple above orange) and, within each group, ordered
    % small -> medium -> large step from bottom to top, matching panels a-d (the
    % darker, smaller-step color sits below).
    nStep = 3;
    sigTop = -0.105;
    sigSpacing = 0.0095;
    for iLine = 1:numel(ratio)
        refGroup = ceil(iLine / nStep);                 % 1 = purple, 2 = orange
        stepInGroup = iLine - (refGroup - 1) * nStep;   % 1 = small ... 3 = large
        rowFromTop = (refGroup - 1) * nStep + (nStep - stepInGroup);
        localDrawSigBars(ax, timeMs, ratio(iLine).sig, sigTop - sigSpacing * rowFromTop, ...
            ratio(iLine).color, plotTimeMs, 2);
    end

    localStyleTimeAxis(ax);
end

function localDrawSigBars(ax, timeMs, mask, y, col, plotTimeMs, lineWidth)
    if nargin < 7 || isempty(lineWidth)
        lineWidth = 3;
    end
    mask = mask(:)' & timeMs >= min(plotTimeMs) & timeMs <= max(plotTimeMs);
    if ~any(mask)
        return
    end
    d = diff([false mask false]);
    starts = find(d == 1);
    stops = find(d == -1) - 1;
    for iRun = 1:numel(starts)
        plot(ax, [timeMs(starts(iRun)) timeMs(stops(iRun))], [y y], '-', ...
        'Color', col, 'LineWidth', lineWidth, 'Clipping', 'off');
    end
end

function fig = localNewPanelFigure(isRatioPanel)
    onecolumn = 8.9;
    figHeight = onecolumn * 0.624;
    if isRatioPanel
        figHeight = figHeight * 1.20;
    end
    fig = figure('Color', 'w');
    fig.Units = 'centimeters';
    fig.Position = [10 10 onecolumn figHeight];
    fig.PaperUnits = 'centimeters';
    fig.PaperPosition = [0 10 onecolumn figHeight];
    fig.InvertHardcopy = 'off';
end

function ax = localNewPanelAxes(fig, isDecodingPanel)
    onecolumn = 8.9;
    baseFigHeight = onecolumn * 0.624;
    figHeight = fig.Position(4);
    if isDecodingPanel
        axPos = [1.05 1.34 onecolumn*0.84 (figHeight - 1.28) * 0.75];
    else
        axPos = [1.05 0.72 onecolumn*0.84 (baseFigHeight - 1.28) * 1.20];
    end
    ax = axes(fig, 'Units', 'centimeters', ...
        'Position', axPos);
end

function localSavePanel(fig, outdir, fileStem)
    pause(0.5)
    exportgraphics(fig, fullfile(outdir, [fileStem '.pdf']), ...
        'ContentType', 'vector', 'BackgroundColor', 'white');
    exportgraphics(fig, fullfile(outdir, [fileStem '.png']), ...
        'Resolution', 300, 'BackgroundColor', 'white');
    fprintf('%s successfully saved.\n', [fileStem '.pdf']);
    fprintf('%s successfully saved.\n', [fileStem '.png']);
end

function localStyleTimeAxis(ax)
    ax.FontName = 'Arial';
    ax.FontSize = 7;
    ax.LineWidth = 0.5;
    ax.TickDir = 'out';
    ax.Box = 'off';
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.Color = 'w';
    ax.TickLength = [0.006 0.006];
    grid(ax, 'on');
    ax.XMinorGrid = 'off';
    ax.YMinorGrid = 'off';
    ax.GridColor = [0 0 0];
    ax.MinorGridColor = [0 0 0];
    ax.GridAlpha = 0.16;
    ax.MinorGridAlpha = 0.08;
    ax.Title.Units = 'normalized';
    ax.Title.Position(1) = 0.05;
end

%% ------------------------- GENERIC HELPERS ------------------------------

function A = localAsPercent(A)
    if max(A(:), [], 'omitnan') <= 1.5
        A = A * 100;
    end
end

function odds = localOdds(acc)
    epsAcc = 1e-6;
    acc = min(max(acc, epsAcc), 1 - epsAcc);
    odds = acc ./ (1 - acc);
end

function A = localSelectDim(A, dim, idx)
    subs = repmat({':'}, 1, ndims(A));
    subs{dim} = idx;
    A = A(subs{:});
end

function v = localExperimentValue(v, expIdx)
    if iscell(v)
        v = v{expIdx};
    end
end

function v = localDecMetadataValue(dec, expIdx, fieldNames)
    for iField = 1:numel(fieldNames)
        fieldName = char(fieldNames(iField));
        if isfield(dec, fieldName)
            v = dec.(fieldName);
            if iscell(v) && numel(v) == 3 && ~all(cellfun(@ischar, v))
                v = v{expIdx};
            end
            return
        end
    end
    error('None of these decoding fields were found: %s', strjoin(string(fieldNames), ', '));
end

function dimLevs = localNormalizeDimLevels(dimLevsRaw, dims)
    if iscell(dimLevsRaw)
        dimLevs = dimLevsRaw;
        return
    end

    assert(isstruct(dimLevsRaw), 'Dimension levels must be a struct or cell array.');
    dimLevs = cell(1, numel(dims));
    for iDim = 1:numel(dims)
        dimName = char(dims(iDim));
        if isfield(dimLevsRaw, dimName)
            dimLevs{iDim} = dimLevsRaw.(dimName);
        else
            dimLevs{iDim} = {};
        end
    end
end

function dim = localFindDimByName(dims, requestedNames)
    dims = lower(string(dims));
    requestedNames = lower(string(requestedNames));
    dim = [];
    for iName = 1:numel(requestedNames)
        dim = find(dims == requestedNames(iName), 1, 'first');
        if ~isempty(dim)
            return
        end
    end
    error('Could not find any requested dimension (%s) in dimensions: %s.', ...
        strjoin(requestedNames, ', '), strjoin(dims, ', '));
end

function idx = localFindLevelIndex(levels, requestedLevel)
    if isempty(levels) && isnumeric(requestedLevel)
        idx = requestedLevel;
        return
    end
    levelStrings = lower(string(levels));
    requestedLevel = lower(string(requestedLevel));
    idx = find(levelStrings == requestedLevel, 1, 'first');
    if isempty(idx)
        idx = find(contains(levelStrings, requestedLevel), 1, 'first');
    end
    if isempty(idx) && isnumeric(levels)
        idx = find(double(levels) == double(requestedLevel), 1, 'first');
    end
    assert(~isempty(idx), 'Could not find level "%s" in levels: %s', ...
        requestedLevel, strjoin(levelStrings, ', '));
end
