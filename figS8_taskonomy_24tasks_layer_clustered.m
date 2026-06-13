%% figS8_taskonomy_24tasks_layer_clustered.m
% Layer-wise hue/chroma sensitivity ratio for all 24 Taskonomy tasks (every task
% except colorization), one panel per task in a 4x6 tiled layout, with tasks
% ORGANISED BY BEST-ALIGNED LAYER.
%
% For every task the per-depth (purple, orange) log10 hue/chroma sensitivity
% ratios are computed (averaged across iterations), and the task's "best-aligned
% layer" is the network depth whose point lies closest to the human
% psychophysical mean -- the same human-alignment criterion used in
% figS7_taskonomy.m. Tasks are then ordered from early (Layer 1 / stem) to deep
% (Block 4) by that layer, and each panel's title is coloured by it using the
% layer palette shared with figS7_taskonomy.m (Layer 1 / Block 1-4).
%
% The per-task depth profiles are sourced from taskonomyClustering.m (the shared
% profile builder); its unsupervised clustering is no longer used to organise
% this figure.
%
% Set showErrorBars to add SE bars (standard error across the 10 iterations) to
% each per-depth purple/orange marker.
%
% Requires the Statistics and Machine Learning Toolbox (used by
% taskonomyClustering.m when building the profiles).
%
% Operating-system independent: all paths are built with fullfile relative to
% this file.

clear; clc; close all

%% ------------------------- PATHS AND OPTIONS ----------------------------

scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

human_csv = fullfile(scriptDir, 'data', 'human', 'human_thresholds.csv');
taskonomy_csv = fullfile(scriptDir, 'data', 'network', 'taskonomy_thresholds.csv');

outdir = fullfile(scriptDir, 'figs');
doSave = true;
twocolumn = 17.8;

% Whether to draw standard-error bars (SE across the 10 iterations) on each
% per-depth purple/orange marker.
showErrorBars = true;

% Clustering options forwarded to taskonomyClustering.m (the shared profile
% builder). This figure no longer uses the resulting clusters to organise its
% panels, but the options are kept so the shared call behaves as elsewhere.
autoSelectK = true;
kList = 2:8;
fixedK = 4;

% Reference colors shared with figS7_taskonomy.m.
purpleColor = [0.80 0.20 0.90];
orangeColor = [0.85 0.33 0.10];

%% ------------------------- HUMAN REFERENCE ------------------------------

assert(isfile(human_csv), 'Human CSV not found: %s', human_csv);
T = readtable(human_csv, 'TextType', 'string');
T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);
if ismember('orange_hue_focused', T.Properties.VariableNames)
    T = T(T.orange_hue_focused == 1, :);
end
T.ptID = string(T.ptID);
T.axis = lower(string(T.hue_chroma));
T.refLabel = lower(string(T.quadrant));
T.sign = lower(string(T.direction));
[~, xHuman, yHuman] = humanSensitivityHSI(T);

humanProfileStats.purple.mean = mean(xHuman, 'omitnan');
humanProfileStats.purple.sd   = std(xHuman, 'omitnan');
humanProfileStats.orange.mean = mean(yHuman, 'omitnan');
humanProfileStats.orange.sd   = std(yHuman, 'omitnan');

%% ------------------------- TASKONOMY PROFILES ---------------------------

% Per-task layer profiles (purple/orange log10 hue/chroma ratio per depth, with
% SE across iterations). taskonomyClustering.m is reused only as the shared
% source of these profiles; the grid below is organised by best-aligned layer
% rather than by the unsupervised clusters.
clusterOpts = struct('autoSelectK', autoSelectK, 'kList', kList, 'fixedK', fixedK);
C = taskonomyClustering(taskonomy_csv, clusterOpts);
profiles = C.profiles;

% Exclude the colorization task (also removed from figS7).
profiles = profiles(arrayfun(@(p) lower(string(p.task)) ~= "colorization", profiles));

% Organise the grid by each task's best-aligned layer: the network depth whose
% (purple, orange) point is closest to the human psychophysical mean (the same
% "human alignment" criterion used in figS7_taskonomy.m). Tasks are ordered from
% early (Layer 1 / stem) to deep (Block 4) and coloured by that layer, using the
% layer palette shared with figS7_taskonomy.m.
humanMean = [humanProfileStats.purple.mean, humanProfileStats.orange.mean];
[layerDepthOrder, layerNames, layerColors] = layerPalette();
[profiles, layerId] = assignBestAlignedLayer(profiles, humanMean, layerDepthOrder);

%% ------------------------- PLOT AND SAVE --------------------------------

if doSave && ~exist(outdir, 'dir')
    mkdir(outdir);
end

fig = plotTaskonomy24TaskGridByLayer(profiles, layerId, layerColors, ...
    layerNames, humanProfileStats, purpleColor, orangeColor, twocolumn, showErrorBars);

if doSave
    pause(0.1)
    exportgraphics(fig, fullfile(outdir, 'figS8_taskonomy_24tasks_layer_clustered.pdf'), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
    exportgraphics(fig, fullfile(outdir, 'figS8_taskonomy_24tasks_layer_clustered.png'), ...
        'ContentType', 'image', 'BackgroundColor', 'none', 'Resolution', 600);
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

%% ------------------------- PLOTTING HELPERS -----------------------------

function [order, labels, colors] = layerPalette()
    % Processing depths in the Taskonomy CSV mapped to the ResNet50 architecture
    % figure's naming and colors, shared with figS7_taskonomy.m. Layer 1 (the
    % stem, drawn black in the architecture figure) is shown in GRAY here.
    order  = ["stem", "layer1", "layer2", "layer3", "layer4"];
    labels = ["Layer 1 (L_1)", "Block 1 (B_1)", "Block 2 (B_2)", "Block 3 (B_3)", "Block 4 (B_4)"];
    colors = [0.45 0.45 0.45;    % Layer 1 (stem)  - gray
              0.13 0.38 0.78;    % Block 1         - blue
              0.00 0.62 0.50;    % Block 2         - teal/green
              0.87 0.56 0.12;    % Block 3         - tan/gold
              0.84 0.20 0.52];   % Block 4         - rose/magenta
end

function [profiles, layerId] = assignBestAlignedLayer(profiles, humanMean, depthOrder)
    % For each task, find the layer (network depth) whose (purple, orange) point
    % is closest to the human psychophysical mean, then order the tasks by that
    % layer from early (Layer 1 / stem) to deep (Block 4). Returns the reordered
    % profiles and, per task, the index of its best-aligned layer into the layer
    % palette (1 = Layer 1 ... 5 = Block 4).
    nTasks = numel(profiles);
    layerPos = nan(nTasks, 1);   % index into depthOrder (1..5)
    for k = 1:nTasks
        Pk = profiles(k);
        x = Pk.purple(:);
        y = Pk.orange(:);
        d = Pk.depths(:);
        valid = isfinite(x) & isfinite(y);
        if ~any(valid)
            continue
        end
        dist2 = (x - humanMean(1)).^2 + (y - humanMean(2)).^2;
        dist2(~valid) = inf;
        [~, mi] = min(dist2);
        li = find(depthOrder == d(mi), 1);
        if isempty(li)
            li = numel(depthOrder);   % unknown depth -> deepest bucket
        end
        layerPos(k) = li;
    end

    % Alphabetical rank of each task by its displayed panel label (so the order
    % matches what the reader sees), used to order tasks within a layer.
    taskLabels = arrayfun(@(p) lower(string(taskDisplayLabel(p.task))), profiles);
    [~, alphaOrder] = sort(taskLabels);
    alphaRank = zeros(nTasks, 1);
    alphaRank(alphaOrder) = 1:nTasks;

    % Order tasks by best-aligned layer (early -> deep), then alphabetically
    % within the same layer. Tasks with no valid layer sink to the end and
    % default to Layer 1 for colouring.
    sortLayer = layerPos;
    sortLayer(isnan(sortLayer)) = numel(depthOrder) + 1;
    [~, ord] = sortrows([sortLayer, alphaRank], [1 2]);

    profiles = profiles(ord);
    layerId = layerPos(ord);
    layerId(isnan(layerId)) = 1;
end

function label = taskDisplayLabel(taskName)
    % Map a raw Taskonomy task name to a readable panel title. Unknown names fall
    % back to a generic prettifier (underscores -> spaces, leading capital).
    key = char(lower(string(taskName)));
    map = containers.Map('KeyType', 'char', 'ValueType', 'char');
    map('autoencoding')      = 'Autoencoding';
    map('class_object')      = 'Object classification';
    map('class_scene')       = 'Scene classification';
    map('colorization')      = 'Colorization';
    map('curvature')         = 'Curvature';
    map('denoising')         = 'Denoising';
    map('depth_euclidean')   = 'Depth (Euclidean)';
    map('depth_zbuffer')     = 'Depth (z-buffer)';
    map('edge_occlusion')    = 'Edge occlusion';
    map('edge_texture')      = 'Edge texture';
    map('egomotion')         = 'Egomotion';
    map('fixated_pose')      = 'Fixated pose';
    map('inpainting')        = 'Inpainting';
    map('jigsaw')            = 'Jigsaw';
    map('keypoints2d')       = 'Keypoints 2D';
    map('keypoints3d')       = 'Keypoints 3D';
    map('nonfixated_pose')   = 'Nonfixated pose';
    map('normal')            = 'Surface normals';
    map('point_matching')    = 'Point matching';
    map('reshading')         = 'Reshading';
    map('room_layout')       = 'Room layout';
    map('segment_semantic')  = 'Semantic segmentation';
    map('segment_unsup2d')   = 'Segment 2D (unsupervised)';
    map('segment_unsup25d')  = 'Segment 2.5D (unsupervised)';
    map('vanishing_point')   = 'Vanishing point';

    if isKey(map, key)
        label = map(key);
    else
        label = strrep(key, '_', ' ');
        if ~isempty(label)
            label(1) = upper(label(1));
        end
    end
end

function t = wrapTitle(label)
    % Break a long title into two lines at the space nearest the middle, so wide
    % labels stay within the panel. Short labels are returned unchanged.
    label = char(label);
    maxLen = 14;
    if numel(label) <= maxLen || ~contains(label, ' ')
        t = label;
        return
    end
    spaces = strfind(label, ' ');
    [~, si] = min(abs(spaces - numel(label) / 2));
    splitPos = spaces(si);
    t = {strtrim(label(1:splitPos - 1)), strtrim(label(splitPos + 1:end))};
end

function fig = plotTaskonomy24TaskGridByLayer(profiles, layerId, layerColors, ...
        layerNames, humanStats, purpleColor, orangeColor, twocolumn, showErrorBars)
    % One panel per task in a 4x6 tiled layout. Each panel plots the log10
    % hue/chroma sensitivity ratio versus network depth for the purple and orange
    % references together, with faint human mean +/- SD reference bands. Tasks are
    % ordered from early to deep by their best-aligned layer (closest to the human
    % mean) and each panel's title is coloured by that layer, using the layer
    % palette shared with figS7_taskonomy.m. A common y-axis range is used across
    % all panels. When showErrorBars is true, each marker carries an SE bar
    % (standard error across the 10 iterations).
    if nargin < 9 || isempty(showErrorBars)
        showErrorBars = true;
    end
    nTasks = numel(profiles);
    nCols = 6;
    nRows = ceil(nTasks / nCols);   % 24 tasks -> 4 rows x 6 cols
    depthOrder = ["stem", "layer1", "layer2", "layer3", "layer4"];
    depthLabels = {'L_1', 'B_1', 'B_2', 'B_3', 'B_4'};
    nD = numel(depthOrder);

    % Common y-limits across every panel (tasks + human reference bands).
    allVals = [humanStats.purple.mean + humanStats.purple.sd;
               humanStats.purple.mean - humanStats.purple.sd;
               humanStats.orange.mean + humanStats.orange.sd;
               humanStats.orange.mean - humanStats.orange.sd];
    for k = 1:nTasks
        allVals = [allVals; profiles(k).purple(:); profiles(k).orange(:)]; %#ok<AGROW>
        if showErrorBars
            % Include the SE bar extents so they are not clipped.
            pSE = profiles(k).purpleSE(:);
            oSE = profiles(k).orangeSE(:);
            allVals = [allVals; ...
                profiles(k).purple(:) + pSE; profiles(k).purple(:) - pSE; ...
                profiles(k).orange(:) + oSE; profiles(k).orange(:) - oSE]; %#ok<AGROW>
        end
    end
    allVals = allVals(isfinite(allVals));
    loVal = min(allVals);
    hiVal = max(allVals);
    pad = 0.05 * (hiVal - loVal) + 0.01;
    ylims = [loVal - pad, hiVal + pad];
    % Only label -0.30, 0, 0.30, keeping ticks that fall inside the y-range.
    ytick = [-0.3 0 0.3];
    ytick = ytick(ytick >= ylims(1) & ytick <= ylims(2));

    fig = figure('Color', 'w');
    tl = tiledlayout(fig, nRows, nCols, 'TileSpacing', 'loose', 'Padding', 'tight');

    axHandles = gobjects(nTasks, 1);
    for k = 1:nTasks
        ax = nexttile(tl);
        axHandles(k) = ax;
        hold(ax, 'on');
        cCol = layerColors(layerId(k), :);

        % Zero reference and human mean +/- SD bands for both references.
        line(ax, [0.5 nD + 0.5], [0 0], 'Color', [0.65 0.65 0.65], ...
            'LineStyle', '-', 'LineWidth', 0.4, 'HandleVisibility', 'off');
        drawHumanBand(ax, humanStats.purple, purpleColor, nD);
        drawHumanBand(ax, humanStats.orange, orangeColor, nD);

        % Map this task's depths onto the canonical depth axis.
        Pk = profiles(k);
        xIdx = nan(numel(Pk.depths), 1);
        for i = 1:numel(Pk.depths)
            idx = find(depthOrder == Pk.depths(i), 1);
            if ~isempty(idx)
                xIdx(i) = idx;
            end
        end
        vp = isfinite(xIdx) & isfinite(Pk.purple);
        vo = isfinite(xIdx) & isfinite(Pk.orange);

        % SE bars (standard error across the 10 iterations) drawn first, so the
        % connecting lines and markers sit on top of them.
        if showErrorBars
            drawDepthErrorBars(ax, xIdx(vp), Pk.purple(vp), Pk.purpleSE(vp), purpleColor);
            drawDepthErrorBars(ax, xIdx(vo), Pk.orange(vo), Pk.orangeSE(vo), orangeColor);
        end

        % Lines and markers drawn separately so the white marker edge can be
        % thinner than the connecting line.
        plot(ax, xIdx(vp), Pk.purple(vp), '-', 'Color', purpleColor, ...
            'LineWidth', 1.0, 'HandleVisibility', 'off');
        plot(ax, xIdx(vp), Pk.purple(vp), 'd', 'MarkerFaceColor', purpleColor, ...
            'MarkerEdgeColor', 'w', 'MarkerSize', 7, 'LineWidth', 0.75, ...
            'LineStyle', 'none');
        plot(ax, xIdx(vo), Pk.orange(vo), '-', 'Color', orangeColor, ...
            'LineWidth', 1.0, 'HandleVisibility', 'off');
        plot(ax, xIdx(vo), Pk.orange(vo), 'd', 'MarkerFaceColor', orangeColor, ...
            'MarkerEdgeColor', 'w', 'MarkerSize', 7, 'LineWidth', 0.75, ...
            'LineStyle', 'none');

        ax.XLim = [0.5 nD + 0.5];
        ax.YLim = ylims;
        ax.XTick = 1:nD;
        ax.YTick = ytick;
        ax.FontName = 'Arial';
        ax.FontSize = 7;

        % Axes stay fully black; the best-aligned layer is indicated by the title
        % colour only.
        ax.LineWidth = 0.5;
        ax.XColor = 'k';
        ax.YColor = 'k';
        ax.Color = [0.97 0.97 0.97];
        box(ax, 'off');

        % Only show x tick labels on the bottom-most panel of each column (so a
        % partially filled last row still labels the columns that end early) and
        % y labels on the left column.
        colK = mod(k - 1, nCols) + 1;
        isBottomOfColumn = (k + nCols) > nTasks;
        if isBottomOfColumn
            ax.XTickLabel = depthLabels;
        else
            ax.XTickLabel = [];
        end
        if colK == 1
            ax.YTickLabel = arrayfun(@(v) sprintf('%.2f', v), ytick, 'UniformOutput', false);
        else
            ax.YTickLabel = [];
        end

        title(ax, wrapTitle(taskDisplayLabel(Pk.task)), 'FontWeight', 'bold', ...
            'FontSize', 8, 'Color', cCol);
    end

    xlabel(tl, 'Depth', 'FontWeight', 'bold', 'FontName', 'Arial', 'FontSize', 10);
    ylabel(tl, 'log_1_0 hue / chroma sensitivity', 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'FontSize', 10);

    % Best-aligned-layer colour key (top), anchored to a panel as its own legend
    % object. Only the layers that occur among the tasks are shown, in early ->
    % deep order. Dummy markers are drawn off-range.
    presentLayers = unique(layerId(:))';   % ascending = Layer 1 -> Block 4
    axKey = axHandles(2);
    keyHandles = gobjects(1, numel(presentLayers));
    for i = 1:numel(presentLayers)
        c = presentLayers(i);
        keyHandles(i) = plot(axKey, NaN, NaN, 's', 'MarkerFaceColor', layerColors(c, :), ...
            'MarkerEdgeColor', 'none', 'MarkerSize', 9, 'LineStyle', 'none');
    end
    leg2 = legend(axKey, keyHandles, cellstr(layerNames(presentLayers)), 'Orientation', 'horizontal');
    leg2.Box = 'off';
    leg2.FontName = 'Arial';
    leg2.FontSize = 9;
    leg2.Layout.Tile = 'north';

    % Full two-column figure; height kept moderate so the 4x6 grid stays legible.
    figWidth = twocolumn;
    figHeight = 16.5;
    fig.PaperType = 'a4';
    fig.PaperUnits = 'centimeters';
    fig.Units = 'centimeters';
    fig.InvertHardcopy = 'off';
    fig.PaperPosition = [0, 10, figWidth, figHeight];
    fig.Position = [5, 5, figWidth, figHeight];
end

function drawDepthErrorBars(ax, x, y, se, barColor)
    % Vertical SE bars (standard error across iterations) for one reference's
    % per-depth ratio values. Depths with a non-finite SE are skipped.
    x = x(:);
    y = y(:);
    se = se(:);
    valid = isfinite(x) & isfinite(y) & isfinite(se);
    if ~any(valid)
        return
    end
    errorbar(ax, x(valid), y(valid), se(valid), 'LineStyle', 'none', ...
        'Color', barColor, 'LineWidth', 0.6, 'CapSize', 0, ...
        'HandleVisibility', 'off');
end

function drawHumanBand(ax, refStat, bandColor, nD)
    % Faint human mean +/- SD reference band and dotted mean line for one
    % reference chromaticity, spanning the full depth range.
    mu = refStat.mean;
    sd = refStat.sd;
    patch(ax, [0.5 nD + 0.5 nD + 0.5 0.5], [mu - sd mu - sd mu + sd mu + sd], ...
        bandColor, 'EdgeColor', 'none', 'FaceAlpha', 0.10, 'HandleVisibility', 'off');
    line(ax, [0.5 nD + 0.5], [mu mu], 'Color', bandColor, ...
        'LineStyle', ':', 'LineWidth', 0.6, 'HandleVisibility', 'off');
end
