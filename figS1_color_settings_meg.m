%% figS1_color_settings_meg.m
% Plot distances between MEG color steps and the orange/purple reference colors.
%
% Figure S1 has two panels:
%   A. Main MEG experiment.
%   B. Task-comparison experiments, grouped by completed task.
%
% The MEGcolors MAT file stores one distance array per experiment. The distance
% array has dimensions described by MEGcolors.dims and MEGcolors.dimLevs. Only
% the step and participant dimensions vary meaningfully for this figure, because
% the reference-to-step distances are the same across color direction conditions.
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
twocolumn = 17.8;

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
%   3 = control/task-comparison orientation experiment
expIdx.colorTask = 1;
expIdx.main = 2;
expIdx.orientationTask = 3;

%% ------------------------- EXTRACT DISTANCES ----------------------------

% Convert each experiment's distDKL array into participants x steps.
[mainDist, mainPtLabels, stepLabels] = localStepDistances(MEGcolors, expIdx.main);
[colorDist, colorPtLabels] = localStepDistances(MEGcolors, expIdx.colorTask);
[orientationDist, orientationPtLabels] = localStepDistances(MEGcolors, expIdx.orientationTask);

%% ------------------------- PLOT PANELS ----------------------------------

% Panel A: main experiment only.
figA = localPlotDistancePanel(mainDist, mainPtLabels, stepLabels, ...
    "A", "Main MEG experiment", {}, twocolumn);

% Panel B: task-comparison experiments grouped by task.
groupNames = {'Color task', 'Orientation task'};
figB = localPlotDistancePanel([colorDist; orientationDist], ...
    [colorPtLabels(:); orientationPtLabels(:)], stepLabels, ...
    "B", "Task-comparison experiments", groupNames, twocolumn, ...
    [numel(colorPtLabels), numel(orientationPtLabels)]);

if doSave
    pause(0.1)
    exportgraphics(figA, fullfile(outdir, 'figS1a_color_settings_meg_main.pdf'), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
    fprintf('%s successfully saved.\n', 'figS1a_color_settings_meg_main.pdf');
    exportgraphics(figB, fullfile(outdir, 'figS1b_color_settings_meg_task_comparison.pdf'), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
    fprintf('%s successfully saved.\n', 'figS1b_color_settings_meg_task_comparison.pdf');
end

%% ------------------------- LOCAL FUNCTIONS ------------------------------

function [distByParticipant, ptLabels, stepLabels] = localStepDistances(MEGcolors, expIdx)
    % Return a participants x steps matrix of DKL distances for one experiment.
    %
    % distDKL may contain dimensions for reference color, hue/chroma axis, color
    % direction, step, and participant. For this figure we average over every
    % dimension except step and participant.

    dist = double(localExperimentValue(MEGcolors.distDKL, expIdx));
    dims = string(localMetadataValue(MEGcolors, expIdx, ["dims", "Dims", "accDims"]));
    dimLevs = localNormalizeDimLevels(localMetadataValue(MEGcolors, expIdx, ["dimLevs", "DimLevs", "accDimLevs"]), dims);

    stepDim = localFindDimByName(dims, "step");
    ptDim = localFindDimByName(dims, "pt");

    % Average all condition dimensions while preserving step and participant.
    keepDims = [stepDim, ptDim];
    for d = ndims(dist):-1:1
        if ~ismember(d, keepDims)
            dist = mean(dist, d, 'omitnan');
        end
    end

    % Bring the remaining dimensions into step x participant order, then
    % transpose to participant x step for plotting.
    dist = squeeze(dist);
    if stepDim > ptDim
        % If squeeze leaves participant x step order, transpose it below.
        dist = dist.';
    end

    % The intended output is participant x step.
    if size(dist, 1) <= size(dist, 2)
        distByParticipant = dist.';
    else
        distByParticipant = dist;
    end

    % Step labels: describe the three steps as Small/Medium/Large shift. Fall
    % back to "Step N" if the number of steps is not the expected three.
    nStepsOut = size(distByParticipant, 2);
    shiftNames = ["Small shift", "Medium shift", "Large shift"];
    if nStepsOut == numel(shiftNames)
        stepLabels = shiftNames;
    else
        stepLabels = strcat("Step ", string(1:nStepsOut));
    end

    % Participant labels are optional. If missing, use participant numbers.
    if isfield(MEGcolors, 'pts')
        ptLabels = string(localExperimentValue(MEGcolors.pts, expIdx));
    else
        ptLabels = "P" + string(1:size(distByParticipant, 1));
    end
end

function fig = localPlotDistancePanel(distByParticipant, ptLabels, stepLabels, panelLetter, panelTitle, groupNames, twocolumn, groupSizes)
    % Plot all participant distances for Step 1-3.
    %
    % Steps are encoded by grayscale marker color: black, dark gray, light gray.

    if nargin < 8
        groupSizes = [];
    end

    nPt = size(distByParticipant, 1);
    nSteps = size(distByParticipant, 2);
    xBase = 1:nPt;
    groupGap = 1.0;
    if ~isempty(groupSizes)
        % Add a small visual gap between task groups.
        xBase(groupSizes(1)+1:end) = xBase(groupSizes(1)+1:end) + groupGap;
    end
    xOffsets = linspace(-0.18, 0.18, nSteps);
    stepColors = [0.00 0.00 0.00;
                  0.35 0.35 0.35;
                  0.72 0.72 0.72];

    fig = figure('Color', 'w');
    ax = axes(fig);
    hold(ax, 'on');

    % Shade odd participant columns to make neighboring participants easier to
    % separate without using grid lines.
    yMax = 0.07;
    if isempty(groupSizes)
        stripeIdx = 1:2:nPt;
    else
        % Restart the odd-column striping within each task group so both groups
        % have the same visual rhythm and the final odd participant is shaded.
        stripeIdx = [1:2:groupSizes(1), ...
            groupSizes(1) + (1:2:groupSizes(2))];
    end
    for iPt = stripeIdx
        xCenter = xBase(iPt);
        patch(ax, [xCenter-0.5 xCenter+0.5 xCenter+0.5 xCenter-0.5], [0 0 yMax yMax], ...
            [0.74 0.74 0.74], 'EdgeColor', 'none', 'FaceAlpha', 0.35, ...
            'HandleVisibility', 'off');
    end

    for iStep = 1:nSteps
        col = stepColors(min(iStep, size(stepColors, 1)), :);
        scatter(ax, xBase + xOffsets(iStep), distByParticipant(:, iStep), ...
            22, col, 'o', 'filled', ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', 0.4, ...
            'DisplayName', char(stepLabels(iStep)));
    end

    % Draw a subtle divider and group labels for the task-comparison panel.
    if ~isempty(groupSizes)
        groupBoundary = groupSizes(1) + 0.5 + groupGap / 2;
        line(ax, [groupBoundary groupBoundary], [0 yMax], ...
            'Color', 'k', 'LineStyle', ':', 'LineWidth', 0.8, ...
            'HandleVisibility', 'off');

        ax.XTick = xBase;
        ax.XTickLabel = ptLabels;
    else
        ax.XTick = xBase;
        ax.XTickLabel = ptLabels;
    end

    ylabel(ax, 'Distance from reference color', 'FontWeight', 'bold');
    xlabel(ax, 'Participant', 'FontWeight', 'bold');

    % Axes styling follows the compact figure style used elsewhere.
    ax.FontName = 'Arial';
    ax.FontSize = 7;
    ax.LineWidth = 0.5;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.Color = [0.97 0.97 0.97];
    ax.XLim = [0.0 max(xBase) + 1.0];
    ax.YLim = [0 0.07];
    ax.YTick = 0:0.01:0.07;
    ax.YTickLabel = {'0.00','0.01','0.02','0.03','0.04','0.05','0.06','0.07'};
    ax.XTickLabelRotation = 45;
    ax.TickLength = [0.005 0.005];
    box(ax, 'on');
    grid(ax, 'off');

    fig.PaperType = 'a4';
    fig.PaperUnits = 'centimeters';
    fig.Units = 'centimeters';
    fig.InvertHardcopy = 'off';
    figHeight = twocolumn * 0.42 * 0.75;
    fig.PaperPosition = [0, 10, twocolumn, figHeight];
    fig.Position = [10, 10, twocolumn, figHeight];
    ax.Units = 'centimeters';
    ax.Position = [1.0 1.1 twocolumn*0.92 figHeight - 1.45];
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

function dim = localFindDimByName(dims, requestedName)
    % Find a dimension index from MEGcolors.dims.
    dims = lower(string(dims));
    requestedName = lower(string(requestedName));
    dim = find(dims == requestedName, 1, 'first');
    assert(~isempty(dim), 'Could not find dimension "%s" in MEGcolors.dims.', requestedName);
end
