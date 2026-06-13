%% figS7_taskonomy.m
% Summary scatter of all Taskonomy-trained tasks in the hue/chroma ratio plane,
% together with the human psychophysics mean and the MEG mean.
%
% Each Taskonomy task contributes one point (averaged across depths and
% iterations), colored by the UNSUPERVISED CLUSTER it belongs to. The clustering
% is computed in taskonomyClustering.m and shared with
% figS8_taskonomy_24tasks_layer_clustered.m, so the two figures use identical
% cluster assignments and colors.
%
% Coordinates are computed exactly as in fig8_human_network.m:
%   sensitivity   = 1 / threshold
%   plotted value = log10(hue sensitivity / chroma sensitivity)
% with purple on the x-axis and orange on the y-axis.
%
% Three figures are produced:
%   figS7_taskonomy            - one point per task, averaged across depths,
%                                colored by its unsupervised cluster.
%   figS7_taskonomy_bestlayer  - one point per task at its BEST processing depth
%                                (the depth with the highest orange hue/chroma
%                                ratio), colored by which layer that was
%                                (Layer 0 / Block 1-4, per the architecture
%                                figure; Layer 0 shown gray since black = human).
%   figS7_taskonomy_humanlayer - one point per task at the processing depth most
%                                SIMILAR TO HUMAN (the depth whose (purple,orange)
%                                point is closest to the human mean), colored by
%                                which layer that was, as above.
%
% Standard-error bars on the task markers can be toggled with showErrorBars.
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

% Input files.
human_csv = fullfile(scriptDir, 'data', 'human', 'human_thresholds.csv');
meg_mat = fullfile(scriptDir, 'data', 'meg_log_odds_ratios.mat');
taskonomy_csv = fullfile(scriptDir, 'data', 'network', 'taskonomy_thresholds.csv');

% Output folder and figure sizing.
outdir = fullfile(scriptDir, 'figs');
doSave = true;
twocolumn = 17.8;

% Whether to label each point with its task name in the best-layer figure.
showBestLayerTaskNames = true;

% Whether to draw standard-error bars on the Taskonomy task markers.
showErrorBars = false;

% MEG settings shared with fig5/fig8.
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

%% ------------------------- MEG AND TASKONOMY DATA -----------------------

% Participant-aligned MEG log-odds ratios from the main MEG analysis.
[xMEG, yMEG, hasMEG] = loadMegLogOdds(meg_mat, H_HSI.ptID, meg_time_window, meg_step_idx);

% One point per Taskonomy-trained task, averaged across iterations and depths.
taskonomyHSI_all = taskonomySensitivityHSI(taskonomy_csv);

% Unsupervised clustering of all tasks by their layer profiles (shared with
% figS8_taskonomy_24tasks_layer_clustered.m).
C = taskonomyClustering(taskonomy_csv);

% Per task, per depth (for the best-layer figure below): one (purple, orange)
% point at every processing depth, used to pick the layer closest to the human
% psychophysics mean.
taskonomyHSI_depth = taskonomyDepthHSI(taskonomy_csv);
humanMean = [mean(xHuman, 'omitnan'), mean(yHuman, 'omitnan')];

%% ------------------------- PLOT AND SAVE --------------------------------

if doSave && ~exist(outdir, 'dir')
    mkdir(outdir);
end

% Average across all depths: one point per task, colored by its cluster.
fig = plotTaskonomyClusterScatter(xHuman, yHuman, xMEG, yMEG, hasMEG, ...
    taskonomyHSI_all, C, twocolumn, showErrorBars);

% Best layer per task: the processing depth with the highest orange hue/chroma
% ratio, colored by which layer (Layer 0 / Block 1-4) it was.
figBest = plotTaskonomyBestLayer(humanMean, xMEG, yMEG, hasMEG, ...
    taskonomyHSI_depth, twocolumn, showBestLayerTaskNames, showErrorBars, 'orange');

% Most human-like layer per task: the processing depth whose (purple, orange)
% point lies closest to the human mean, colored by which layer it was.
figHuman = plotTaskonomyBestLayer(humanMean, xMEG, yMEG, hasMEG, ...
    taskonomyHSI_depth, twocolumn, showBestLayerTaskNames, showErrorBars, 'humansim');

if doSave
    pause(0.1)
    exportgraphics(fig, fullfile(outdir, 'figS7_taskonomy.pdf'), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
    exportgraphics(fig, fullfile(outdir, 'figS7_taskonomy.png'), ...
        'ContentType', 'image', 'BackgroundColor', 'none', 'Resolution', 600);
    exportgraphics(figBest, fullfile(outdir, 'figS7_taskonomy_bestlayer.pdf'), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
    exportgraphics(figBest, fullfile(outdir, 'figS7_taskonomy_bestlayer.png'), ...
        'ContentType', 'image', 'BackgroundColor', 'none', 'Resolution', 600);
    exportgraphics(figHuman, fullfile(outdir, 'figS7_taskonomy_humanlayer.pdf'), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
    exportgraphics(figHuman, fullfile(outdir, 'figS7_taskonomy_humanlayer.png'), ...
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

%% ------------------------- TASKONOMY HELPERS ----------------------------

function H = taskonomySensitivityHSI(taskonomy_csv, requestedDepths)
    % Load the all-task Taskonomy threshold table and compute one hue/chroma
    % ratio point per task, averaged across iterations and available depths.
    if nargin < 2
        requestedDepths = strings(0, 1);
    end

    assert(isfile(taskonomy_csv), 'Taskonomy CSV not found: %s', taskonomy_csv);

    N = readtable(taskonomy_csv, 'TextType', 'string');
    N.Properties.VariableNames = matlab.lang.makeValidName(N.Properties.VariableNames);
    N.task = string(N.task);
    N.depth = lower(string(N.depth));
    N.refLabel = lower(string(N.quadrant));
    N.dir = lower(string(N.direction));
    N.threshold_mean = N.threshold;

    % Exclude the colorization task from figS7 (kept in figS8).
    N = N(lower(N.task) ~= "colorization", :);

    tasks = unique(N.task, 'stable');

    H = repmat(struct('task', "", 'x', NaN, 'y', NaN, 'xSE', NaN, 'ySE', NaN), ...
        numel(tasks), 1);

    epsDen = 1e-12;
    for iTask = 1:numel(tasks)
        rowsTask = N(N.task == tasks(iTask), :);
        iters = unique(rowsTask.iter, 'stable');
        depths = localOrderedDepths(unique(rowsTask.depth, 'stable'));
        if ~isempty(requestedDepths)
            depths = depths(ismember(depths, lower(string(requestedDepths))));
        end

        xVals = [];
        yVals = [];
        for iIter = 1:numel(iters)
            for iDepth = 1:numel(depths)
                rows = rowsTask(rowsTask.iter == iters(iIter) & rowsTask.depth == depths(iDepth), :);
                if isempty(rows)
                    continue
                end

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
                end
            end
        end

        H(iTask).task = tasks(iTask);
        H(iTask).x = mean(xVals, 'omitnan');
        H(iTask).y = mean(yVals, 'omitnan');
        H(iTask).xSE = localStandardError(xVals);
        H(iTask).ySE = localStandardError(yVals);
    end
end

function depths = localOrderedDepths(depths)
    dmid = setdiff(depths, ["stem","fc"], 'stable');
    if any(depths == "stem"), dmid = ["stem"; dmid]; end
    if any(depths == "fc"), dmid = [dmid; "fc"]; end
    depths = dmid;
end

function se = localStandardError(vals)
    vals = vals(isfinite(vals));
    if isempty(vals)
        se = NaN;
    else
        se = std(vals, 'omitnan') / sqrt(numel(vals));
    end
end

function Sdepth = networkThresholdStruct(Nrows)
    % Convert rows for one network layer into a nested threshold struct.
    refs = unique(Nrows.refLabel);
    Sdepth = struct();
    for i = 1:numel(refs)
        r = refs(i);
        R = Nrows(Nrows.refLabel == r, :);
        Sdepth.(r).chroma.pos = getDirStats(R, "chroma_plus");
        Sdepth.(r).chroma.neg = getDirStats(R, "chroma_minus");
        Sdepth.(r).hue.pos = getDirStats(R, "hue_plus");
        Sdepth.(r).hue.neg = getDirStats(R, "hue_minus");
    end
end

function st = getDirStats(T, dirName)
    % Extract the mean threshold for one named DKL direction.
    idx = lower(string(T.dir)) == dirName;
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

%% ------------------------- PLOTTING HELPERS -----------------------------

function fig = plotTaskonomyClusterScatter(xHuman, yHuman, xMEG, yMEG, hasMEG, taskonomyHSI, C, twocolumn, showErrorBars)
    % Scatter of human mean, MEG mean, and one diamond per Taskonomy task in the
    % hue/chroma ratio plane. Each task is colored by its unsupervised cluster
    % (from taskonomyClustering.m), with optional SE bars and a per-cluster legend.
    if nargin < 9 || isempty(showErrorBars)
        showErrorBars = true;
    end
    xlims = [-0.25 0.10];
    ylims = [-0.05 0.30];

    % Map each task name to its cluster index.
    taskToCluster = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for i = 1:numel(C.tasks)
        taskToCluster(char(lower(C.tasks(i)))) = C.clusterId(i);
    end

    fig = figure('Color', 'w');
    hold on;
    axis([xlims ylims]);
    addBackgroundGuides(xlims, ylims);

    % Human and MEG group means.
    scatter(mean(xHuman, 'omitnan'), mean(yHuman, 'omitnan'), 80, 'o', 'filled', ...
        'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w', 'DisplayName', 'Human mean');
    if ~isempty(hasMEG) && any(hasMEG)
        scatter(mean(xMEG(hasMEG), 'omitnan'), mean(yMEG(hasMEG), 'omitnan'), 75, '^', 'filled', ...
            'MarkerFaceColor', [0.00 0.75 0.85], 'MarkerEdgeColor', 'k', ...
            'LineWidth', 0.5, 'DisplayName', 'MEG mean');
    end

    % One diamond per task, colored by its cluster, with SE bars.
    for iTask = 1:numel(taskonomyHSI)
        xi = taskonomyHSI(iTask).x;
        yi = taskonomyHSI(iTask).y;
        key = char(lower(taskonomyHSI(iTask).task));
        if ~isfinite(xi) || ~isfinite(yi) || ~isKey(taskToCluster, key)
            continue
        end
        col = C.clusterColors(taskToCluster(key), :);
        xSE = taskonomyHSI(iTask).xSE;
        ySE = taskonomyHSI(iTask).ySE;
        if showErrorBars && isfinite(ySE)
            errorbar(xi, yi, ySE, ySE, 'Color', col, ...
                'LineWidth', 0.6, 'CapSize', 0, 'HandleVisibility', 'off');
        end
        if showErrorBars && isfinite(xSE)
            line([xi - xSE, xi + xSE], [yi yi], ...
                'Color', col, 'LineWidth', 0.6, 'HandleVisibility', 'off');
        end
        scatter(xi, yi, 55, 'd', 'filled', 'MarkerFaceColor', col, ...
            'MarkerEdgeColor', 'k', 'LineWidth', 0.25, 'HandleVisibility', 'off');
    end

    xlabel('log_1_0 hue / chroma (purple)', 'FontWeight', 'bold');
    ylabel('log_1_0 hue / chroma (orange)', 'FontWeight', 'bold');

    % Axis ticks: 0.1 step, two-decimal labels.
    ax = gca;
    xtick = ceil(xlims(1) / 0.1) * 0.1 : 0.1 : floor(xlims(2) / 0.1) * 0.1;
    ytick = ceil(ylims(1) / 0.1) * 0.1 : 0.1 : floor(ylims(2) / 0.1) * 0.1;
    ax.XTick = xtick;
    ax.YTick = ytick;
    ax.XLim = xlims;
    ax.YLim = ylims;
    ax.XTickLabel = arrayfun(@(v) sprintf('%.2f', v), xtick, 'UniformOutput', false);
    ax.YTickLabel = arrayfun(@(v) sprintf('%.2f', v), ytick, 'UniformOutput', false);
    ax.FontName = 'Arial';
    ax.FontSize = 10;
    ax.LineWidth = 0.5;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.Color = 'none';
    box on
    grid minor

    % 0.8 x two-column figure with a square plot box (no legend).
    figWidth = twocolumn * 0.8;
    boxSize = figWidth - 1.5 - 0.4;     % left and right margins
    ax.Units = 'centimeters';
    ax.Position = [1.5 1.1 boxSize boxSize];
    axis(ax, 'square');

    figHeight = 1.1 + boxSize + 0.6;
    fig.PaperType = 'a4';
    fig.PaperUnits = 'centimeters';
    fig.Units = 'centimeters';
    fig.InvertHardcopy = 'off';
    fig.PaperPosition = [0, 10, figWidth, figHeight];
    fig.Position = [10, 10, figWidth, figHeight];
end

function H = taskonomyDepthHSI(taskonomy_csv)
    % Per task, per depth: log10 hue/chroma sensitivity ratio for the purple (x)
    % and orange (y) references, averaged across iterations, plus SE across
    % iterations. Depths are kept in stem -> layer4 order.
    assert(isfile(taskonomy_csv), 'Taskonomy CSV not found: %s', taskonomy_csv);

    N = readtable(taskonomy_csv, 'TextType', 'string');
    N.Properties.VariableNames = matlab.lang.makeValidName(N.Properties.VariableNames);
    N.task = string(N.task);
    N.depth = lower(string(N.depth));
    N.refLabel = lower(string(N.quadrant));
    N.dir = lower(string(N.direction));
    N.threshold_mean = N.threshold;

    % Exclude the colorization task from figS7 (kept in figS8).
    N = N(lower(N.task) ~= "colorization", :);

    tasks = unique(N.task, 'stable');
    H = repmat(struct('task', "", 'depths', strings(0, 1), ...
        'x', [], 'y', [], 'xSE', [], 'ySE', []), numel(tasks), 1);

    epsDen = 1e-12;
    for iTask = 1:numel(tasks)
        rowsTask = N(N.task == tasks(iTask), :);
        iters = unique(rowsTask.iter, 'stable');
        depths = localOrderedDepths(unique(rowsTask.depth, 'stable'));

        x = nan(numel(depths), 1);
        y = nan(numel(depths), 1);
        xSE = nan(numel(depths), 1);
        ySE = nan(numel(depths), 1);
        for d = 1:numel(depths)
            xv = [];
            yv = [];
            for iIter = 1:numel(iters)
                rows = rowsTask(rowsTask.iter == iters(iIter) & rowsTask.depth == depths(d), :);
                if isempty(rows)
                    continue
                end
                S = networkThresholdStruct(rows);
                mp = meanOfTwo(S.purple.chroma.pos.mean, S.purple.chroma.neg.mean);
                hp = meanOfTwo(S.purple.hue.pos.mean, S.purple.hue.neg.mean);
                mo = meanOfTwo(S.orange.chroma.pos.mean, S.orange.chroma.neg.mean);
                ho = meanOfTwo(S.orange.hue.pos.mean, S.orange.hue.neg.mean);

                xi = log10((1 / max(hp, epsDen)) / max(1 / max(mp, epsDen), epsDen));
                yi = log10((1 / max(ho, epsDen)) / max(1 / max(mo, epsDen), epsDen));
                if isfinite(xi) && isfinite(yi)
                    xv(end+1) = xi; %#ok<AGROW>
                    yv(end+1) = yi; %#ok<AGROW>
                end
            end
            x(d) = mean(xv, 'omitnan');
            y(d) = mean(yv, 'omitnan');
            xSE(d) = localStandardError(xv);
            ySE(d) = localStandardError(yv);
        end

        H(iTask).task = tasks(iTask);
        H(iTask).depths = depths;
        H(iTask).x = x;
        H(iTask).y = y;
        H(iTask).xSE = xSE;
        H(iTask).ySE = ySE;
    end
end

function label = taskDisplayLabel(taskName)
    % Map a raw Taskonomy task name to a readable label. Unknown names fall back
    % to a generic prettifier (underscores -> spaces, leading capital).
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

function [order, labels, colors] = layerPalette()
    % Processing depths in the Taskonomy CSV mapped to the ResNet50 architecture
    % figure's naming and colors. Layer 0 (the stem, drawn black in the
    % architecture figure) is shown in GRAY here, because black already denotes
    % the human psychophysics mean.
    order  = ["stem", "layer1", "layer2", "layer3", "layer4"];
    labels = ["Layer 0", "Block 1", "Block 2", "Block 3", "Block 4"];
    colors = [0.45 0.45 0.45;    % Layer 0 (stem)  - gray
              0.13 0.38 0.78;    % Block 1         - blue
              0.00 0.62 0.50;    % Block 2         - teal/green
              0.87 0.56 0.12;    % Block 3         - tan/gold
              0.84 0.20 0.52];   % Block 4         - rose/magenta
end

function fig = plotTaskonomyBestLayer(humanMean, xMEG, yMEG, hasMEG, depthHSI, twocolumn, showTaskNames, showErrorBars, selectMode)
    if nargin < 7 || isempty(showTaskNames)
        showTaskNames = true;
    end
    if nargin < 8 || isempty(showErrorBars)
        showErrorBars = true;
    end
    if nargin < 9 || isempty(selectMode)
        selectMode = 'orange';
    end
    % Scatter of the human mean, MEG mean, and one diamond per Taskonomy task
    % placed at a single chosen processing depth, selected per task by selectMode:
    %   'orange'   - the depth with the highest orange hue/chroma ratio (strongest
    %                orange-region hue superiority).
    %   'humansim' - the depth whose (purple, orange) point is closest to the
    %                human mean (most human-like layer).
    % Each diamond is colored by which layer that was (Layer 0 / Block 1-4),
    % matching the architecture figure.
    xlims = [-0.22 0.10];
    ylims = [-0.04 0.26];
    [order, labels, colors] = layerPalette();

    fig = figure('Color', 'w');
    hold on;
    axis([xlims ylims]);
    addBackgroundGuides(xlims, ylims);

    % Human and MEG group means.
    hHuman = scatter(humanMean(1), humanMean(2), 80, 'o', 'filled', ...
        'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w', 'DisplayName', 'Human mean');
    hMEG = gobjects(1);
    if ~isempty(hasMEG) && any(hasMEG)
        hMEG = scatter(mean(xMEG(hasMEG), 'omitnan'), mean(yMEG(hasMEG), 'omitnan'), 75, '^', 'filled', ...
            'MarkerFaceColor', [0.00 0.75 0.85], 'MarkerEdgeColor', 'k', ...
            'LineWidth', 0.5, 'DisplayName', 'MEG mean');
    end

    % One diamond per task at its chosen depth (see selectMode above).
    for iTask = 1:numel(depthHSI)
        D = depthHSI(iTask);
        idxs = find(isfinite(D.x) & isfinite(D.y));
        if isempty(idxs)
            continue
        end
        switch lower(string(selectMode))
            case "humansim"
                % Depth closest to the human mean in the (purple, orange) plane.
                d2 = (D.x(idxs) - humanMean(1)).^2 + (D.y(idxs) - humanMean(2)).^2;
                [~, mi] = min(d2);
            otherwise
                % Depth with the highest orange hue/chroma ratio.
                [~, mi] = max(D.y(idxs));
        end
        best = idxs(mi);

        li = find(order == D.depths(best), 1);
        if isempty(li)
            col = [0.4 0.4 0.4];
        else
            col = colors(li, :);
        end

        bx = D.x(best);
        by = D.y(best);
        if showErrorBars && isfinite(D.ySE(best))
            errorbar(bx, by, D.ySE(best), D.ySE(best), 'Color', col, ...
                'LineWidth', 0.6, 'CapSize', 0, 'HandleVisibility', 'off');
        end
        if showErrorBars && isfinite(D.xSE(best))
            line([bx - D.xSE(best), bx + D.xSE(best)], [by by], ...
                'Color', col, 'LineWidth', 0.6, 'HandleVisibility', 'off');
        end
        scatter(bx, by, 55, 'd', 'filled', 'MarkerFaceColor', col, ...
            'MarkerEdgeColor', 'k', 'LineWidth', 0.25, 'HandleVisibility', 'off');

        % Optional task name immediately to the right of the marker.
        if showTaskNames
            text(bx, by, [' ' char(taskDisplayLabel(D.task))], ...
                'FontName', 'Arial', 'FontSize', 4.5, 'Color', [0.15 0.15 0.15], ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
                'Clipping', 'on');
        end
    end

    xlabel('log_1_0 hue / chroma (purple)', 'FontWeight', 'bold');
    ylabel('log_1_0 hue / chroma (orange)', 'FontWeight', 'bold');

    % Axis ticks: fixed -0.30:0.1:0.30 grid, two-decimal labels (ticks outside
    % each axis range are simply not shown).
    ax = gca;
    xtick = -0.30:0.10:0.30;
    ytick = -0.30:0.10:0.30;
    ax.XTick = xtick;
    ax.YTick = ytick;
    ax.XLim = xlims;
    ax.YLim = ylims;
    ax.XTickLabel = arrayfun(@(v) sprintf('%.2f', v), xtick, 'UniformOutput', false);
    ax.YTickLabel = arrayfun(@(v) sprintf('%.2f', v), ytick, 'UniformOutput', false);
    ax.FontName = 'Arial';
    ax.FontSize = 10;
    ax.LineWidth = 0.5;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.Color = 'none';
    box on
    grid minor

    % 0.8 x two-column figure with a square plot box (no legend; layer colors are
    % keyed by the architecture figure), matching figS7_taskonomy.
    figWidth = twocolumn * 0.8;
    boxSize = figWidth - 1.5 - 0.4;     % left and right margins
    ax.Units = 'centimeters';
    ax.Position = [1.5 1.1 boxSize boxSize];
    axis(ax, 'square');

    figHeight = 1.1 + boxSize + 0.6;
    fig.PaperType = 'a4';
    fig.PaperUnits = 'centimeters';
    fig.Units = 'centimeters';
    fig.InvertHardcopy = 'off';
    fig.PaperPosition = [0, 10, figWidth, figHeight];
    fig.Position = [10, 10, figWidth, figHeight];
end

function addBackgroundGuides(xlims, ylims)
    % Shared ratio-space guides: triangular regions, diagonal equality, and zero
    % reference lines. The triangles are drawn far beyond the visible range and
    % clipped to the axes: the purple region is where the purple ratio exceeds
    % the orange ratio (y < x) and the orange region is the opposite (y > x).
    big = 10;
    patch([-big big big], [-big -big big], [0.80 0.20 0.90], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.08, 'HandleVisibility', 'off');
    patch([-big -big big], [-big big big], [0.85 0.33 0.10], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.08, 'HandleVisibility', 'off');

    % Equality diagonal, drawn only across the part of the box both axes share.
    dmin = max(xlims(1), ylims(1));
    dmax = min(xlims(2), ylims(2));
    plot([dmin dmax], [dmin dmax], '-', 'Color', [0.7 0.7 0.7], ...
        'LineWidth', 0.5, 'HandleVisibility', 'off');

    line([0 0], ylims, 'LineStyle', ':', 'Color', 'k', 'LineWidth', 1, 'HandleVisibility', 'off');
    line(xlims, [0 0], 'LineStyle', ':', 'Color', 'k', 'LineWidth', 1, 'HandleVisibility', 'off');
end
