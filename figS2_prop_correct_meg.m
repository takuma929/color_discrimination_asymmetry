%% figS2_prop_correct_meg.m
% Plot fitted proportion-correct values for the MEG color settings.
%
% Figure S2 separates the four reference/axis conditions:
%   - purple hue
%   - purple chroma
%   - orange hue
%   - orange chroma
%
% For each condition, the script saves one panel for the main MEG experiment
% and one panel for the task-comparison color experiment. The orientation task
% is not plotted because proportion-correct values are not needed for that
% control here. Data points follow the participant-by-step format used in
% figS1_color_settings_meg.m.
%
% The script is operating-system independent:
%   - paths are built with fullfile;
%   - data and output folders are resolved relative to this script;
%   - no path depends on MATLAB's current working directory.

clear; clc; close all

%% ------------------------- PATHS AND OPTIONS ----------------------------

% Resolve the repository/script folder from this file.
scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

% Support both the requested filename and the currently present local filename.
megColorsMat = fullfile(scriptDir, 'data', 'meg_colors.mat');

% Output folder follows the manuscript figure convention used in this project.
outdir = fullfile(scriptDir, 'figs');
doSave = true;
onecolumn = 8.9;

if doSave && ~exist(outdir, 'dir')
    mkdir(outdir);
end

%% ------------------------- LOAD DATA ------------------------------------

assert(isfile(megColorsMat), 'MEGcolors MAT file not found: %s', megColorsMat);
S = load(megColorsMat, 'MEGcolors');
assert(isfield(S, 'MEGcolors'), 'Variable MEGcolors not found in %s', megColorsMat);
MEGcolors = S.MEGcolors;

% Experiments are stored as 1x3 cell arrays:
%   1 = supplementary/task-comparison color experiment
%   2 = main MEG experiment
%   3 = control/task-comparison orientation experiment, not plotted here
expIdx.colorTask = 1;
expIdx.main = 2;

% Conditions are ordered to match the example layout supplied by the user.
conditions = struct( ...
    'ref',  {'purple', 'purple',  'orange', 'orange'}, ...
    'axis', {'hue',    'chroma',  'hue',    'chroma'}, ...
    'tag',  {'purple_hue', 'purple_chroma', 'orange_hue', 'orange_chroma'});

%% ------------------------- PLOT PANELS ----------------------------------

for iCond = 1:numel(conditions)
    thisCond = conditions(iCond);

    % Extract participants x steps matrices for this color condition.
    [mainPc, mainPtLabels, stepLabels] = localPropCorrectByParticipantStep( ...
        MEGcolors, expIdx.main, thisCond.ref, thisCond.axis);
    [colorPc, colorPtLabels] = localPropCorrectByParticipantStep( ...
        MEGcolors, expIdx.colorTask, thisCond.ref, thisCond.axis);

    % One-column panel for the main MEG experiment.
    figMain = localPlotPropCorrectPanel(mainPc, mainPtLabels, stepLabels, ...
        onecolumn, thisCond.ref);

    % One-column panel for the task-comparison color experiment only.
    figTask = localPlotPropCorrectPanel(colorPc, colorPtLabels, stepLabels, ...
        onecolumn, thisCond.ref);

    if doSave
        pause(0.1)
        exportgraphics(figMain, fullfile(outdir, sprintf('figS2%s_main_%s.pdf', ...
            'a', thisCond.tag)), ...
            'ContentType', 'vector', 'BackgroundColor', 'none');
        exportgraphics(figTask, fullfile(outdir, sprintf('figS2%s_color_task_%s.pdf', ...
            'b', thisCond.tag)), ...
            'ContentType', 'vector', 'BackgroundColor', 'none');
    end
end

%% ------------------------- LOCAL FUNCTIONS ------------------------------

function [pcByParticipant, ptLabels, stepLabels] = localPropCorrectByParticipantStep(MEGcolors, expIdx, refName, axisName)
    % Return a participants x steps x directions array for one experiment and
    % condition.
    %
    % propCorr stores fitted proportion correct for reference color, chromatic
    % axis, color direction, step, and participant. This function selects the
    % requested reference/axis condition and keeps the two direction polarities,
    % so two dots can be plotted side by side for every step.

    propCorr = double(localExperimentValue(MEGcolors.propCorr, expIdx));
    dims = string(localMetadataValue(MEGcolors, expIdx, ["dims", "Dims"]));
    dimLevs = localNormalizeDimLevels(localMetadataValue(MEGcolors, expIdx, ["dimLevs", "DimLevs"]), dims);

    refDim = localFindDimByName(dims, ["quad", "ref", "reference"]);
    axisDim = localFindDimByName(dims, ["hc", "axis", "dimension"]);
    direcDim = localFindDimByName(dims, ["direc", "direction"]);
    stepDim = localFindDimByName(dims, "step");
    ptDim = localFindDimByName(dims, ["pt", "participant", "observer"]);

    refIdx = localFindLevelIndex(dimLevs{refDim}, refName);
    axisIdx = localFindLevelIndex(dimLevs{axisDim}, axisName);

    % Select the reference color and hue/chroma axis while preserving the full
    % dimensionality, so the remaining dimension indices stay valid.
    propCorr = localSelectDim(propCorr, refDim, refIdx);
    propCorr = localSelectDim(propCorr, axisDim, axisIdx);

    % Average every non-direction, non-step, non-participant dimension while
    % keeping the two direction polarities separate.
    keepDims = [direcDim, stepDim, ptDim];
    for d = ndims(propCorr):-1:1
        if ~ismember(d, keepDims)
            propCorr = mean(propCorr, d, 'omitnan');
        end
    end

    % Bring the remaining values into participant x step x direction order.
    pcByParticipant = localParticipantStepDirectionArray(propCorr, ptDim, stepDim, direcDim);

    % Step labels come from dimLevs.step when available.
    if numel(dimLevs) >= stepDim && ~isempty(dimLevs{stepDim})
        stepVals = string(dimLevs{stepDim});
    else
        stepVals = string(1:size(pcByParticipant, 2));
    end
    stepLabels = strcat("Step ", stepVals);

    % Participant labels are optional. If missing, use participant numbers.
    if isfield(MEGcolors, 'pts')
        ptLabels = string(localExperimentValue(MEGcolors.pts, expIdx));
    else
        ptLabels = "P" + string(1:size(pcByParticipant, 1));
    end
end

function fig = localPlotPropCorrectPanel(pcByParticipant, ptLabels, stepLabels, onecolumn, refName, groupSizes)
    % Plot fitted proportion correct for Step 1-3 using the compact S3 style.

    if nargin < 6
        groupSizes = [];
    end

    nPt = size(pcByParticipant, 1);
    nSteps = size(pcByParticipant, 2);
    nDirec = size(pcByParticipant, 3);
    xBase = 1:nPt;
    groupGap = 1.0;
    if ~isempty(groupSizes)
        % Add a small visual gap between task groups.
        xBase(groupSizes(1)+1:end) = xBase(groupSizes(1)+1:end) + groupGap;
    end

    stepOffsets = linspace(-0.22, 0.22, nSteps);
    directionOffsets = linspace(-0.045, 0.045, nDirec);
    stepColors = localStepColors(refName, nSteps);

    fig = figure('Color', 'w');
    ax = axes(fig);
    hold(ax, 'on');

    yMin = -0.05;
    yMax = 1.05;

    % Shade odd participant columns to separate neighboring labels without grid
    % lines. In grouped panels, restart striping inside each task group.
    if isempty(groupSizes)
        stripeIdx = 1:2:nPt;
    else
        stripeIdx = [1:2:groupSizes(1), ...
            groupSizes(1) + (1:2:groupSizes(2))];
    end
    for iPt = stripeIdx
        xCenter = xBase(iPt);
        patch(ax, [xCenter-0.5 xCenter+0.5 xCenter+0.5 xCenter-0.5], ...
            [yMin yMin yMax yMax], [0.74 0.74 0.74], ...
            'EdgeColor', 'none', 'FaceAlpha', 0.35, ...
            'HandleVisibility', 'off');
    end

    % Reference lines match the example: chance performance for a 4AFC task and
    % the QUEST threshold level used for fitted performance.
    line(ax, [0 max(xBase)+1], [0.25 0.25], ...
        'Color', [1.00 0.00 0.00], 'LineStyle', ':', 'LineWidth', 1.3, ...
        'HandleVisibility', 'off');
    line(ax, [0 max(xBase)+1], [0.625 0.625], ...
        'Color', [0.00 0.00 1.00], 'LineStyle', '--', 'LineWidth', 0.7, ...
        'HandleVisibility', 'off');

    for iStep = 1:nSteps
        col = stepColors(min(iStep, size(stepColors, 1)), :);
        for iDirec = 1:nDirec
            scatter(ax, xBase + stepOffsets(iStep) + directionOffsets(iDirec), ...
                pcByParticipant(:, iStep, iDirec), ...
                14, col, 'o', 'filled', ...
                'MarkerEdgeColor', 'k', ...
                'LineWidth', 0.4, ...
                'DisplayName', char(stepLabels(iStep)));
        end
    end

    % Draw a dotted task separator in task-comparison panels.
    if ~isempty(groupSizes)
        groupBoundary = groupSizes(1) + 0.5 + groupGap / 2;
        line(ax, [groupBoundary groupBoundary], [yMin yMax], ...
            'Color', 'k', 'LineStyle', ':', 'LineWidth', 0.8, ...
            'HandleVisibility', 'off');
    end

    ylabel(ax, 'Proportion correct', 'FontWeight', 'bold');
    xlabel(ax, 'Participant', 'FontWeight', 'bold');

    % Axes styling follows figS1, with one-column figure dimensions.
    ax.FontName = 'Arial';
    ax.FontSize = 7;
    ax.LineWidth = 0.5;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.Color = [0.97 0.97 0.97];
    ax.XLim = [0.0 max(xBase) + 1.0];
    ax.YLim = [yMin yMax];
    ax.YTick = 0:0.25:1;
    ax.YTickLabel = {'0.00','0.25','0.50','0.75','1.00'};
    ax.XTick = xBase;
    ax.XTickLabel = ptLabels;
    ax.XTickLabelRotation = 60;
    ax.TickLength = [0.005 0.005];
    box(ax, 'off');
    grid(ax, 'off');

    fig.PaperType = 'a4';
    fig.PaperUnits = 'centimeters';
    fig.Units = 'centimeters';
    fig.InvertHardcopy = 'off';
    figHeight = onecolumn * 0.62 * 0.88;
    fig.PaperPosition = [0, 10, onecolumn, figHeight];
    fig.Position = [10, 10, onecolumn, figHeight];
    ax.Units = 'centimeters';
    ax.Position = [0.95 1.1 onecolumn*0.86 figHeight - 1.45];
end

function colors = localStepColors(refName, nSteps)
    % Use reference-specific colors with lightness changing across steps.
    if strcmpi(refName, 'purple')
        colors = [0.33 0.16 0.55;
                  0.52 0.33 0.72;
                  0.73 0.61 0.86];
    else
        colors = [0.74 0.28 0.05;
                  0.90 0.48 0.18;
                  0.98 0.70 0.42];
    end

    if nSteps > size(colors, 1)
        colors = interp1(1:size(colors, 1), colors, linspace(1, size(colors, 1), nSteps));
    end
end

function mat = localParticipantStepDirectionArray(A, ptDim, stepDim, direcDim)
    % Convert an array with participant, step, and direction as non-singleton
    % dimensions into an explicit participants x steps x directions array.
    nd = ndims(A);
    order = [ptDim, stepDim, direcDim, setdiff(1:nd, [ptDim, stepDim, direcDim], 'stable')];
    A = permute(A, order);
    A = squeeze(A);

    if ndims(A) == 2
        A = reshape(A, size(A, 1), size(A, 2), 1);
    end

    mat = A(:, :, 1:size(A, 3));
end

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
    % Return metadata from the first matching field name. Metadata can be shared
    % across experiments or stored as a 1x3 cell array.
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

function dimLevs = localNormalizeDimLevels(dimLevsRaw, dims)
    % Convert dimLevs metadata into a cell array aligned with dims.
    if iscell(dimLevsRaw)
        dimLevs = dimLevsRaw;
        return
    end

    assert(isstruct(dimLevsRaw), 'MEGcolors.dimLevs must be a struct or cell array.');
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
    % Find a dimension index from MEGcolors.dims using one or more aliases.
    dims = lower(string(dims));
    requestedNames = lower(string(requestedNames));

    dim = [];
    for iName = 1:numel(requestedNames)
        dim = find(dims == requestedNames(iName), 1, 'first');
        if ~isempty(dim)
            return
        end
    end

    error('Could not find any requested dimension (%s) in MEGcolors.dims.', ...
        strjoin(requestedNames, ', '));
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
