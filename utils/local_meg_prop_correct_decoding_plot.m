function local_meg_prop_correct_decoding_plot(compareMode, runBootstrapStats)
%LOCAL_MEG_PROP_CORRECT_DECODING_PLOT Plot MEG decoding against color strength.
%
% This shared helper is used by:
%   - figS3_vs_decoding_accuracy.m
%
% It loads the MEG color settings and decoding-accuracy files, aligns the
% arrays by experiment, condition, direction, step, and participant, and saves
% two figures:
%   1. decoding accuracy vs fitted proportion correct;
%   2. decoding accuracy vs absolute DKL distance from reference color.
%
% compareMode controls which experiments are compared:
%   "main_vs_color_task" : main MEG color task vs task-comparison color task.
%   "color_vs_orientation_task" : task-comparison color task vs orientation task.
%   "s5_vs_decoding_accuracy" : aggregate all four color conditions for the
%       main and task-comparison color experiments, with separate orientation
%       task panels.
%
% runBootstrapStats controls whether the subject-level bootstrap comparison is
% printed. It is false by default because the bootstrap is not needed to save
% the figure panels and can take noticeably longer than plotting.

if nargin < 2
    runBootstrapStats = false;
end

%% ------------------------- PATHS AND DATA -------------------------------

scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    scriptDir = pwd;
end
% This helper lives in utils/, so the project root is one level up.
projectRoot = fileparts(scriptDir);

dataDir = fullfile(projectRoot, 'data');
outdir = fullfile(projectRoot, 'figs');
if ~exist(outdir, 'dir')
    mkdir(outdir);
end

megColorsMat = fullfile(dataDir, 'meg_colors.mat');
decodingMat = fullfile(dataDir, 'meg_decoding_accuracies.mat');

assert(isfile(megColorsMat), 'MEGcolors MAT file not found: %s', megColorsMat);
assert(isfile(decodingMat), 'Decoding accuracy MAT file not found: %s', decodingMat);

S = load(megColorsMat, 'MEGcolors');
D = load(decodingMat, 'dec');
assert(isfield(S, 'MEGcolors'), 'Variable MEGcolors not found in %s', megColorsMat);
assert(isfield(D, 'dec'), 'Variable dec not found in %s', decodingMat);
MEGcolors = S.MEGcolors;
dec = D.dec;

timeWindow = [0.35 0.65];

%% ------------------------- EXPERIMENT SELECTION -------------------------

% Experiments are stored as 1x3 cell arrays:
%   1 = supplementary/task-comparison color experiment
%   2 = main MEG experiment
%   3 = control/task-comparison orientation experiment
switch string(compareMode)
    case "main_vs_color_task"
        figPrefix = 'figS3';
        datasets = struct( ...
            'label', {'Main exp.', 'Task-comp. color'}, ...
            'expIdx', {2, 1}, ...
            'color', {[0.00 0.75 0.85], [1.00 0.45 0.45]}, ...
            'marker', {'^', '^'}, ...
            'annotRow', {1, 2});
    case "color_vs_orientation_task"
        figPrefix = 'figS4';
        datasets = struct( ...
            'label', {'Task-comp. color', 'Task-comp. orientation'}, ...
            'expIdx', {1, 3}, ...
            'color', {[1.00 0.45 0.45], [0.35 0.55 1.00]}, ...
            'marker', {'>', 'p'}, ...
            'annotRow', {2, 1});
    case "s5_vs_decoding_accuracy"
        figPrefix = 'figS3_vs_decoding_accuracy';
        datasets = struct( ...
            'label', {'Main exp.', 'Task-comp. color', 'Task-comp. orientation'}, ...
            'expIdx', {2, 1, 3}, ...
            'color', {[0.00 0.75 0.85], [1.00 0.45 0.45], [0.35 0.55 1.00]}, ...
            'marker', {'^', '^', 'p'}, ...
            'annotRow', {1, 2, 1});
    otherwise
        error('Unknown compareMode: %s', compareMode);
end

conditions = struct( ...
    'ref',  {'purple', 'purple',  'orange', 'orange'}, ...
    'axis', {'hue',    'chroma',  'hue',    'chroma'}, ...
    'label', {'Purple-hue', 'Purple-chroma', 'Orange-hue', 'Orange-chroma'}, ...
    'tag', {'purple_hue', 'purple_chroma', 'orange_hue', 'orange_chroma'});

%% ------------------------- BUILD LONG-FORM DATA -------------------------

% Each table row is one participant x direction x step observation. The decoding
% file stores a separate accuracy for each of the two color shift directions
% (the 'direc' dimension), so direction is kept as a unit of observation and
% paired element-wise with propCorr/distDKL. This matches the per-direction
% correlation convention (acc_agg{i}(:) vs propCorr{i}(:)).
for iData = 1:numel(datasets)
    datasets(iData).data = localBuildExperimentTable( ...
        MEGcolors, dec, datasets(iData).expIdx, conditions, timeWindow);
end

%% ------------------------- PLOT AND SAVE --------------------------------

pause(0.5)
if strcmp(figPrefix, 'figS3_vs_decoding_accuracy')
    localSaveAggregateVsDecodingAccuracyFigure(datasets, outdir, figPrefix);
elseif strcmp(figPrefix, 'figS3')
    % Figure S3 panel order requested by the user:
    %   a = fitted proportion correct vs decoding accuracy
    %   b = DKL distance vs decoding accuracy
    localSaveCorrelationPanels(datasets, conditions, 'propCorrect', ...
        'Fitted proportion correct', 'Decoding accuracy', true, ...
        outdir, figPrefix, 'a', 'prop_correct_vs_decoding_acc');
    localSaveCorrelationPanels(datasets, conditions, 'distDKL', ...
        'Distance from reference color', 'Decoding accuracy', false, ...
        outdir, figPrefix, 'b', 'dkl_distance_vs_decoding_acc');
else
    % Keep the S6 manuscript ordering:
    %   a = fitted proportion correct vs decoding accuracy
    %   b = DKL distance vs decoding accuracy
    localSaveCorrelationPanels(datasets, conditions, 'propCorrect', ...
        'Fitted proportion correct', 'Decoding accuracy', true, ...
        outdir, figPrefix, 'a', 'prop_correct_vs_decoding_acc');
    localSaveCorrelationPanels(datasets, conditions, 'distDKL', ...
        'Distance from reference color', 'Decoding accuracy', false, ...
        outdir, figPrefix, 'b', 'dkl_distance_vs_decoding_acc');
end

localPrintSummary(datasets, compareMode, runBootstrapStats);

end

%% ------------------------- EXTRACTION FUNCTIONS -------------------------

function T = localBuildExperimentTable(MEGcolors, dec, expIdx, conditions, timeWindow)
    % Convert one experiment into a condition-labeled long table.

    propCorr = double(localExperimentValue(MEGcolors.propCorr, expIdx));
    distDKL = double(localExperimentValue(MEGcolors.distDKL, expIdx));
    acc = double(localExperimentValue(dec.acc_agg, expIdx));

    colorDims = string(localMetadataValue(MEGcolors, expIdx, ["dims", "Dims"]));
    colorDimLevs = localNormalizeDimLevels( ...
        localMetadataValue(MEGcolors, expIdx, ["dimLevs", "DimLevs"]), colorDims);

    accDims = string(localDecMetadataValue(dec, expIdx, ["accDims", "dims", "Dims"]));
    accDimLevs = localNormalizeDimLevels( ...
        localDecMetadataValue(dec, expIdx, ["accDimLevs", "DimLevs", "dimLevs"]), accDims);

    timeDim = localFindDimByName(accDims, "time");
    timeVals = localDecMetadataValue(dec, expIdx, ["accTime", "time"]);
    timeIdx = timeVals >= timeWindow(1) & timeVals <= timeWindow(2);
    assert(any(timeIdx), 'No decoding time points found in %.3f-%.3f s.', timeWindow(1), timeWindow(2));

    % Average decoding accuracy over the requested time window while preserving
    % all condition, direction, step, and participant dimensions.
    acc = localSelectDim(acc, timeDim, find(timeIdx));
    acc = mean(acc, timeDim, 'omitnan');

    rows = struct('condition', {}, 'propCorrect', {}, 'distDKL', {}, 'decodingAcc', {}, 'participant', {});

    for iCond = 1:numel(conditions)
        thisCond = conditions(iCond);

        pcVals = localConditionVector(propCorr, colorDims, colorDimLevs, thisCond.ref, thisCond.axis);
        dklVals = localConditionVector(distDKL, colorDims, colorDimLevs, thisCond.ref, thisCond.axis);
        accVals = localConditionVector(acc, accDims, accDimLevs, thisCond.ref, thisCond.axis);

        assert(numel(pcVals) == numel(accVals), ...
            'propCorr and decoding vectors have different lengths for %s %s.', ...
            thisCond.ref, thisCond.axis);
        assert(numel(dklVals) == numel(accVals), ...
            'distDKL and decoding vectors have different lengths for %s %s.', ...
            thisCond.ref, thisCond.axis);

        ptVals = localParticipantVector(MEGcolors, expIdx, colorDims, size(propCorr), thisCond.ref, thisCond.axis);
        assert(numel(ptVals) == numel(accVals), ...
            'Participant labels and observations have different lengths for %s %s.', ...
            thisCond.ref, thisCond.axis);

        for iRow = 1:numel(accVals)
            rows(end+1).condition = string(thisCond.label); %#ok<AGROW>
            rows(end).propCorrect = pcVals(iRow);
            rows(end).distDKL = dklVals(iRow);
            rows(end).decodingAcc = accVals(iRow);
            rows(end).participant = string(ptVals(iRow));
        end
    end

    T = struct2table(rows);
end

function vals = localConditionVector(A, dims, dimLevs, refName, axisName)
    % Select one reference/axis condition and return direction x step x
    % participant observations as one vector.
    %
    % The decoding file stores a separate accuracy for each of the two color
    % shift directions (the 'direc' dimension, size 2). Direction is KEPT as a
    % unit of observation here (not averaged), so propCorr/distDKL and decoding
    % accuracy are paired per direction. This mirrors acc_agg{i}(:) vs
    % propCorr{i}(:) and matches the per-direction correlation convention. All
    % other nuisance dimensions are averaged.

    refDim = localFindDimByName(dims, ["quad", "quadrant", "ref", "reference"]);
    axisDim = localFindDimByName(dims, ["hc", "axis", "dimension"]);
    direcDim = localFindDimByName(dims, ["direc", "direction", "sign"]);
    stepDim = localFindDimByName(dims, "step");
    ptDim = localFindDimByName(dims, ["pt", "participant", "observer"]);

    A = localSelectDim(A, refDim, localFindLevelIndex(dimLevs{refDim}, refName));
    A = localSelectDim(A, axisDim, localFindLevelIndex(dimLevs{axisDim}, axisName));

    keepDims = [direcDim, stepDim, ptDim];
    for d = ndims(A):-1:1
        if ~ismember(d, keepDims)
            A = mean(A, d, 'omitnan');
        end
    end

    order = [stepDim, direcDim, ptDim, setdiff(1:ndims(A), keepDims, 'stable')];
    A = permute(A, order);
    vals = A(:);
end

function ptVals = localParticipantVector(MEGcolors, expIdx, dims, arraySize, refName, axisName)
    % Repeat participant labels once for every direction x step observation, so
    % the labels line up with the kept 'direc' dimension in localConditionVector.
    if isfield(MEGcolors, 'pts')
        ptLabels = string(localExperimentValue(MEGcolors.pts, expIdx));
    else
        ptDim = localFindDimByName(dims, ["pt", "participant", "observer"]);
        ptLabels = "P" + string(1:arraySize(ptDim));
    end

    direcDim = localFindDimByName(dims, ["direc", "direction", "sign"]);
    stepDim = localFindDimByName(dims, "step");
    nPerPt = arraySize(stepDim) * arraySize(direcDim);

    ptVals = strings(nPerPt, numel(ptLabels));
    for iPt = 1:numel(ptLabels)
        ptVals(:, iPt) = ptLabels(iPt);
    end
    ptVals = ptVals(:);
end

%% ------------------------- PLOTTING FUNCTIONS ---------------------------

function localSaveCorrelationPanels(datasets, conditions, xField, xLabelText, yLabelText, xIsPerformance, outdir, figPrefix, panelLetter, fileStem)
    % Save each condition as an independent one-column-width figure.
    for iCond = 1:numel(conditions)
        fig = localPlotCorrelationPanel(datasets, conditions(iCond), ...
            xField, xLabelText, yLabelText, xIsPerformance);
        exportgraphics(fig, fullfile(outdir, sprintf('%s%s_%s_%s.pdf', ...
            figPrefix, panelLetter, fileStem, conditions(iCond).tag)), ...
            'ContentType', 'vector', 'BackgroundColor', 'none');
    end
end

function localSaveAggregateVsDecodingAccuracyFigure(datasets, outdir, figPrefix)
    % Save four independent one-column panels:
    %   a/c = main and task-comparison color experiments pooled over all
    %         purple/orange hue/chroma conditions;
    %   b/d = task-comparison orientation experiment pooled over the same
    %         stimulus conditions.

    colorDatasets = datasets(1:2);
    orientationDataset = datasets(3);

    fig = localPlotAggregateFigure(colorDatasets, 'propCorrect', true, ...
        'Fitted proportion correct', 'Decoding accuracy', 'Color tasks');
    exportgraphics(fig, fullfile(outdir, sprintf('%s_a_prop_correct_vs_decoding_acc_color_tasks.pdf', figPrefix)), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');

    fig = localPlotAggregateFigure(orientationDataset, 'propCorrect', true, ...
        'Fitted proportion correct', 'Decoding accuracy', 'Orientation task');
    exportgraphics(fig, fullfile(outdir, sprintf('%s_b_prop_correct_vs_decoding_acc_orientation_task.pdf', figPrefix)), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');

    fig = localPlotAggregateFigure(colorDatasets, 'distDKL', false, ...
        'Distance from reference color', 'Decoding accuracy', 'Color tasks');
    exportgraphics(fig, fullfile(outdir, sprintf('%s_c_dkl_distance_vs_decoding_acc_color_tasks.pdf', figPrefix)), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');

    fig = localPlotAggregateFigure(orientationDataset, 'distDKL', false, ...
        'Distance from reference color', 'Decoding accuracy', 'Orientation task');
    exportgraphics(fig, fullfile(outdir, sprintf('%s_d_dkl_distance_vs_decoding_acc_orientation_task.pdf', figPrefix)), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
end

function fig = localPlotAggregateFigure(datasets, xField, xIsPerformance, xLabelText, yLabelText, panelTitle)
    % Plot one aggregate panel using compact one-column figure dimensions.

    onecolumn = 8.9;
    figHeight = onecolumn * 0.624 * 1.20;
    fig = figure('Color', 'w');
    fig.PaperType = 'a4';
    fig.PaperUnits = 'centimeters';
    fig.Units = 'centimeters';
    fig.InvertHardcopy = 'off';
    fig.PaperPosition = [0, 10, onecolumn, figHeight];
    fig.Position = [10, 10, onecolumn, figHeight];

    ax = axes(fig, 'Units', 'centimeters', ...
        'Position', [1.15 1.05 onecolumn*0.78 figHeight - 1.55]);
    localPlotAggregatePanel(ax, datasets, xField, xIsPerformance, xLabelText, yLabelText, panelTitle);
end

function localPlotAggregatePanel(ax, datasets, xField, xIsPerformance, xLabelText, yLabelText, panelTitle)
    % Plot one aggregate panel, pooling all four color-reference conditions.

    hold(ax, 'on');
    allX = [];
    allY = [];

    for iData = 1:numel(datasets)
        data = datasets(iData).data;
        x = data.(xField);
        y = data.decodingAcc;
        valid = isfinite(x) & isfinite(y);
        x = x(valid);
        y = y(valid);

        allX = [allX; x]; %#ok<AGROW>
        allY = [allY; y]; %#ok<AGROW>

        thisColor = datasets(iData).color;
        thisMarker = datasets(iData).marker;
        markerArea = 24;
        if strcmp(thisMarker, 'p')
            markerArea = 48;
        end
        scatter(ax, x, y, markerArea, thisColor, thisMarker, 'filled', ...
            'MarkerEdgeColor', 'k', ...
            'MarkerEdgeAlpha', 1.00, ...
            'LineWidth', 0.2, ...
            'DisplayName', datasets(iData).label);
    end

    localPlotFitLine(ax, allX, allY, [0.10 0.10 0.10]);
    localAnnotateAggregateCorrelation(ax, allX, allY, [0.10 0.10 0.10], panelTitle, xField);

    localStyleAxis(ax, allX, allY, xIsPerformance);
    xlabel(ax, xLabelText, 'FontWeight', 'bold');
    ylabel(ax, yLabelText, 'FontWeight', 'bold');
end

function localAnnotateAggregateCorrelation(ax, x, y, thisColor, panelTitle, xField)
    % Print Pearson's r after pooling every point in the aggregate panel.
    if numel(x) < 3 || numel(unique(x)) < 2 || numel(unique(y)) < 2
        label = 'r = n/a';
        r = NaN;
        p = NaN;
    else
        [r, p] = corr(x, y, 'Rows', 'complete', 'Type', 'Pearson');
        label = sprintf('r = %.2f%s', localRoundForDisplay(r, 2), localStars(p));
    end

    fprintf('Plot correlation (%s, %s): %s, raw r = %.6f, p = %.6g, n = %d\n', ...
        panelTitle, xField, label, r, p, numel(x));

    text(ax, 0.03, 0.96, label, ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
        'FontName', 'Arial', 'FontSize', 8, ...
        'Color', thisColor);
end

function fig = localPlotCorrelationPanel(datasets, condition, xField, xLabelText, yLabelText, xIsPerformance)
    % Plot one condition panel using compact one-column figure dimensions.

    onecolumn = 8.9;
    figHeight = onecolumn * 0.624;
    fig = figure('Color', 'w');
    fig.PaperType = 'a4';
    fig.PaperUnits = 'centimeters';
    fig.Units = 'centimeters';
    fig.InvertHardcopy = 'off';
    fig.PaperPosition = [0, 10, onecolumn, figHeight];
    fig.Position = [10, 10, onecolumn, figHeight];

    ax = axes(fig, 'Units', 'centimeters', ...
        'Position', [1.15 1.05 onecolumn*0.78 figHeight - 1.55]);
    hold(ax, 'on');

    conditionLabel = string(condition.label);
    allX = [];
    allY = [];

    for iData = 1:numel(datasets)
        data = datasets(iData).data;
        condIdx = data.condition == conditionLabel;
        x = data.(xField)(condIdx);
        y = data.decodingAcc(condIdx);
        valid = isfinite(x) & isfinite(y);
        x = x(valid);
        y = y(valid);

        allX = [allX; x]; %#ok<AGROW>
        allY = [allY; y]; %#ok<AGROW>

        thisColor = datasets(iData).color;
        thisMarker = datasets(iData).marker;
        markerArea = 30;
        if strcmp(thisMarker, 'p')
            markerArea = 55;
        end
        scatter(ax, x, y, markerArea, thisColor, thisMarker, 'filled', ...
            'MarkerEdgeColor', 'k', ...
            'MarkerEdgeAlpha', 1.00, ...
            'LineWidth', 0.2);

        localPlotFitLine(ax, x, y, thisColor);
        localAnnotateCorrelation(ax, x, y, thisColor, datasets(iData).annotRow, condition, xField);
    end

    localStyleAxis(ax, allX, allY, xIsPerformance);
    text(ax, 0.03, 0.96, conditionLabel, 'Units', 'normalized', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
        'FontName', 'Arial', 'FontSize', 9, 'FontWeight', 'bold', ...
        'Color', 'k');
    xlabel(ax, xLabelText, 'FontWeight', 'bold');
    ylabel(ax, yLabelText, 'FontWeight', 'bold');
end

function localPlotFitLine(ax, x, y, thisColor)
    % Add a least-squares regression line when enough finite data are present.
    if numel(x) < 3 || numel(unique(x)) < 2
        return
    end

    coef = polyfit(x, y, 1);
    xFit = linspace(min(x), max(x), 100);
    yFit = polyval(coef, xFit);
    plot(ax, xFit, yFit, '-', 'Color', thisColor, 'LineWidth', 0.8);
end

function localAnnotateCorrelation(ax, x, y, thisColor, rowIdx, condition, xField)
    % Print Pearson's r and significance stars inside each panel.
    if numel(x) < 3 || numel(unique(x)) < 2 || numel(unique(y)) < 2
        label = 'r = n/a';
        r = NaN;
        p = NaN;
    else
        [r, p] = corr(x, y, 'Rows', 'complete', 'Type', 'Pearson');
        label = sprintf('r = %.2f%s', localRoundForDisplay(r, 2), localStars(p));
    end

    fprintf('Plot correlation (%s, %s): %s, raw r = %.6f, p = %.6g, n = %d\n', ...
        condition.label, xField, label, r, p, numel(x));

    xPos = 0.78;
    yPos = 0.025 + (rowIdx - 1) * 0.10;
    if strcmp(string(condition.tag), "orange_hue") && strcmp(string(xField), "propCorrect")
        xPos = 0.03;
        yPos = 0.72 - (rowIdx - 1) * 0.10;
    end

    text(ax, xPos, yPos, label, ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
        'FontName', 'Arial', 'FontSize', 8, ...
        'Color', thisColor);
end

function localStyleAxis(ax, allX, allY, xIsPerformance)
    % Apply compact manuscript styling used across the MATLAB figure scripts.
    ax.FontName = 'Arial';
    ax.FontSize = 7;
    ax.LineWidth = 0.5;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.Color = [0.97 0.97 0.97];
    ax.TickLength = [0.006 0.006];
    box(ax, 'off');
    grid(ax, 'on');
    ax.XMinorGrid = 'on';
    ax.YMinorGrid = 'on';
    ax.GridColor = [0 0 0];
    ax.MinorGridColor = [0 0 0];
    ax.GridAlpha = 0.16;
    ax.MinorGridAlpha = 0.08;

    if xIsPerformance
        ax.XLim = [0.2 1.05];
        ax.XTick = 0.2:0.2:1.0;
        ax.XTickLabel = {'0.20','0.40','0.60','0.80','1.00'};
    else
        ax.XLim = [0 0.07];
        ax.XTick = 0:0.01:0.07;
        ax.XTickLabel = {'0.00','0.01','0.02','0.03','0.04','0.05','0.06','0.07'};
    end

    ax.YLim = [0.35 0.85];
    ax.YTick = 0.40:0.10:0.80;
    ax.YTickLabel = {'0.40','0.50','0.60','0.70','0.80'};
end

function stars = localStars(p)
    % Return significance stars for two-sided Pearson correlation p-values.
    if p < 0.001
        stars = '***';
    elseif p < 0.01
        stars = '**';
    elseif p < 0.05
        stars = '*';
    else
        stars = '';
    end
end

function val = localRoundForDisplay(val, nDecimal)
    % Round explicitly before sprintf so displayed correlations are never
    % accidentally truncated by formatting differences across environments.
    scale = 10 ^ nDecimal;
    val = round(val * scale) / scale;
end

function localPrintSummary(datasets, compareMode, runBootstrapStats)
    % Display pooled correlations and bootstrap comparison statistics.
    fprintf('\n%s\n', compareMode);
    fprintf('Pearson correlations are two-tailed.\n');
    if runBootstrapStats
        fprintf('Bootstrap p-values are two-sided.\n');
    else
        fprintf('Subject-level bootstrap comparison skipped. Set runBootstrapStats = true to run it.\n');
    end
    for iData = 1:numel(datasets)
        T = datasets(iData).data;
        [rPerf, pPerf] = corr(T.propCorrect, T.decodingAcc, 'Rows', 'complete', 'Type', 'Pearson');
        [rDkl, pDkl] = corr(T.distDKL, T.decodingAcc, 'Rows', 'complete', 'Type', 'Pearson');
        if runBootstrapStats
            stats = localSubjectBootstrap(T, 5000);
            fprintf('%s: r_perf = %.3f (p = %.3g), r_DKL = %.3f (p = %.3g), delta r = %.3f, 95%% CI [%.3f %.3f], p = %.3g, n_pt = %d, n_obs = %d\n', ...
                datasets(iData).label, rPerf, pPerf, rDkl, pDkl, rPerf - rDkl, ...
                stats.ci(1), stats.ci(2), stats.p, numel(unique(T.participant)), height(T));
        else
            fprintf('%s: r_perf = %.3f (p = %.3g), r_DKL = %.3f (p = %.3g), delta r = %.3f, n_pt = %d, n_obs = %d\n', ...
                datasets(iData).label, rPerf, pPerf, rDkl, pDkl, rPerf - rDkl, ...
                numel(unique(T.participant)), height(T));
        end
    end
end

function stats = localSubjectBootstrap(T, nBoot)
    % Compare r(performance, decoding) and r(DKL, decoding) by resampling
    % participants with replacement while preserving all observations from each
    % sampled participant.
    pt = unique(T.participant);
    nPt = numel(pt);
    bootDelta = nan(nBoot, 1);

    for iBoot = 1:nBoot
        sampleIdx = randi(nPt, nPt, 1);
        Tb = T([], :);
        for iSample = 1:numel(sampleIdx)
            Tb = [Tb; T(T.participant == pt(sampleIdx(iSample)), :)]; %#ok<AGROW>
        end
        rPerf = corr(Tb.propCorrect, Tb.decodingAcc, 'Rows', 'complete', 'Type', 'Pearson');
        rDkl = corr(Tb.distDKL, Tb.decodingAcc, 'Rows', 'complete', 'Type', 'Pearson');
        bootDelta(iBoot) = rPerf - rDkl;
    end

    stats.ci = prctile(bootDelta, [2.5 97.5]);
    stats.p = 2 * min(mean(bootDelta <= 0), mean(bootDelta >= 0));
    stats.p = max(stats.p, 1 / nBoot);
end

%% ------------------------- METADATA HELPERS -----------------------------

function A = localSelectDim(A, dim, idx)
    % Index one dimension while keeping singleton dimensions in place.
    subs = repmat({':'}, 1, ndims(A));
    subs{dim} = idx;
    A = A(subs{:});
end

function v = localExperimentValue(v, expIdx)
    % Extract one experiment from a 1x3 cell array, or return the value as-is.
    if iscell(v)
        v = v{expIdx};
    end
end

function v = localMetadataValue(MEGcolors, expIdx, fieldNames)
    % Return metadata from the first matching MEGcolors field name.
    for iField = 1:numel(fieldNames)
        fieldName = char(fieldNames(iField));
        if isfield(MEGcolors, fieldName)
            v = MEGcolors.(fieldName);
            if iscell(v) && numel(v) == 3 && ~all(cellfun(@ischar, v))
                v = v{expIdx};
            end
            return
        end
    end
    error('None of these MEGcolors fields were found: %s', strjoin(string(fieldNames), ', '));
end

function v = localDecMetadataValue(dec, expIdx, fieldNames)
    % Return metadata from the first matching decoding field name.
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
    % Convert dimLevs metadata into a cell array aligned with dims.
    if iscell(dimLevsRaw)
        dimLevs = dimLevsRaw;
        return
    end

    assert(isstruct(dimLevsRaw), 'Dimension levels must be a struct or cell array.');
    dimLevs = cell(1, numel(dims));
    for iDim = 1:numel(dims)
        dimName = char(dims(iDim));
        fieldName = localDimLevelFieldName(dimLevsRaw, dimName);
        if ~isempty(fieldName)
            dimLevs{iDim} = dimLevsRaw.(fieldName);
        else
            dimLevs{iDim} = {};
        end
    end
end

function fieldName = localDimLevelFieldName(dimLevsRaw, dimName)
    % The 21-May files use a few expanded dimension names while dimLevs may
    % retain shorter legacy field names.
    aliases = struct();
    aliases.quadrant = ["quadrant", "quad", "ref", "reference"];
    aliases.quad = ["quad", "quadrant", "ref", "reference"];
    aliases.hc = ["hc", "axis", "dimension", "hue_chroma"];
    aliases.axis = ["axis", "hc", "dimension", "hue_chroma"];
    aliases.pt = ["pt", "participant", "observer"];
    aliases.participant = ["participant", "pt", "observer"];

    key = matlab.lang.makeValidName(lower(string(dimName)));
    if isfield(aliases, key)
        candidates = aliases.(key);
    else
        candidates = string(dimName);
    end

    fields = string(fieldnames(dimLevsRaw));
    fieldName = '';
    for iCandidate = 1:numel(candidates)
        idx = find(strcmpi(fields, candidates(iCandidate)), 1, 'first');
        if ~isempty(idx)
            fieldName = char(fields(idx));
            return
        end
    end
end

function dim = localFindDimByName(dims, requestedNames)
    % Find a dimension index using one or more aliases.
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
    % Find the index of a named level in dimLevs metadata.
    levelStrings = lower(string(levels));
    requestedLevel = lower(string(requestedLevel));

    idx = find(levelStrings == requestedLevel, 1, 'first');
    if isempty(idx)
        idx = find(contains(levelStrings, requestedLevel), 1, 'first');
    end

    assert(~isempty(idx), 'Could not find level "%s" in levels: %s', ...
        requestedLevel, strjoin(levelStrings, ', '));
end
