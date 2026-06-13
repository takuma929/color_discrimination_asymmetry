function local_decoding_acc_panels(expIdx, figPrefix, fileTag)
%LOCAL_DECODING_ACC_PANELS Save decoding accuracy panels.

scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    scriptDir = pwd;
end
% This helper lives in utils/, so the project root is one level up.
projectRoot = fileparts(scriptDir);

dataFile = fullfile(projectRoot, 'data', 'meg_decoding_accuracies.mat');
outdir = fullfile(projectRoot, 'figs');
if ~exist(outdir, 'dir')
    mkdir(outdir);
end

assert(isfile(dataFile), 'Decoding accuracy MAT file not found: %s', dataFile);
S = load(dataFile, 'dec');
assert(isfield(S, 'dec'), 'Variable dec not found in %s', dataFile);
dec = S.dec;

plotTimeMs = [-250 1500];
chancePercent = 50;

purpleCols = [0.52 0.16 0.86; 0.50 0.54 1.00; 0.68 0.60 0.84];
orangeCols = [0.82 0.38 0.10; 1.00 0.45 0.00; 1.00 0.60 0.00];

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

for iCond = 1:numel(conditions)
    thisCond = conditions(iCond);
    D.mean = nan(numel(timeSec), 3);
    D.sig = false(numel(timeSec), 3);
    for iStep = 1:3
        subjByTime = localConditionAccuracy(acc, accDims, dimLevs, timeDim, refDim, axisDim, stepDim, ptDim, ...
            thisCond.ref, thisCond.axis, iStep);
        subjByTime = localAsPercent(subjByTime);
        D.mean(:, iStep) = mean(subjByTime, 1, 'omitnan')';
        D.sig(:, iStep) = localSignificantMask(dec, expIdx, thisCond.ref, thisCond.axis, iStep, timeSec, accDims, dimLevs);
    end

    panelFig = localNewPanelFigure();
    panelAx = localNewPanelAxes(panelFig);
    localPlotDecodingPanel(panelAx, timeMs, D, thisCond, chancePercent, plotTimeMs);
    localSavePanel(panelFig, outdir, sprintf('%s%c_%s', figPrefix, char('a' + iCond - 1), fileTag));
end
end

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

function mask = localSignificantMask(dec, expIdx, refName, axisName, stepLevel, timeSec, accDims, dimLevs) %#ok<INUSD>
    % Significant time points (p < 0.05) for one condition, read from the stats
    % stored in dec.acc_stats. acc_stats is a per-experiment cell of
    % (quad x hc x step) structs, each with a time-resolved p-value field .prob.
    mask = false(numel(timeSec), 1);
    if ~isfield(dec, 'acc_stats')
        return
    end

    S = dec.acc_stats;
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
    % acc_stats has a fixed (quad, hc, step) layout, verified against acc_agg:
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
    % Steps are stored in order 1, 2, 3 along the acc_stats step dimension.
    idx = double(stepLevel);
end

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

function localDrawSigBars(ax, timeMs, mask, y, col, plotTimeMs)
    mask = mask(:)' & timeMs >= min(plotTimeMs) & timeMs <= max(plotTimeMs);
    if ~any(mask)
        return
    end
    d = diff([false mask false]);
    starts = find(d == 1);
    stops = find(d == -1) - 1;
    for iRun = 1:numel(starts)
        plot(ax, [timeMs(starts(iRun)) timeMs(stops(iRun))], [y y], '-', ...
            'Color', col, 'LineWidth', 3, 'Clipping', 'off');
    end
end

function fig = localNewPanelFigure()
    onecolumn = 8.9;
    figHeight = onecolumn * 0.624;
    fig = figure('Color', 'w');
    fig.Units = 'centimeters';
    fig.Position = [10 10 onecolumn figHeight];
    fig.PaperUnits = 'centimeters';
    fig.PaperPosition = [0 10 onecolumn figHeight];
    fig.InvertHardcopy = 'off';
end

function ax = localNewPanelAxes(fig)
    onecolumn = 8.9;
    figHeight = fig.Position(4);
    ax = axes(fig, 'Units', 'centimeters', ...
        'Position', [1.05 1.34 onecolumn*0.84 (figHeight - 1.28) * 0.75]);
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

function A = localAsPercent(A)
    if max(A(:), [], 'omitnan') <= 1.5
        A = A * 100;
    end
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
