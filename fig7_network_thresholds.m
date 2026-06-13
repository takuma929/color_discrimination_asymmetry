%% fig7_network_thresholds.m
% Plot DKL-plane chromatic discrimination threshold diamonds for all networks.
%
% Each output figure overlays the human group-mean threshold diamonds with the
% threshold diamonds estimated from one network at one processing depth. The
% old hue/chroma ratio scatter plot has intentionally been removed from this
% script.
%
% The script is operating-system independent:
%   - paths are built with fullfile;
%   - data and output folders are resolved relative to this script;
%   - no path depends on the MATLAB current working directory.

clear; clc; close all

%% ------------------------- PATHS AND OPTIONS ----------------------------

% Resolve the folder containing this script so all data paths are stable across
% operating systems and launch locations.
scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

% All networks
% allNetworks = {'resnet50','resnet50_flips', ...
%                'places365_resnet50','places365_resnet18', ...
%                'keypointrcnn_resnet50_fpn','fasterrcnn_resnet50_fpn','resnet18'};

% Networks included in the figure.
allNetworks = {'resnet50','resnet50_flips','places365_resnet50'};

% Human JND data and output folder.
human_csv = fullfile(scriptDir, 'data', 'human', 'human_thresholds.csv');
outdir = fullfile(scriptDir, 'figs');
doSave = true;
twocolumn = 17.8;

% Reference coordinates in DKL space: [L-M, S].
refDKL.purple = [0.1191,  0.1191];
refDKL.orange = [0.1191, -0.1191];

% Plot colors and line widths.
C.purple = [0.50 0.20 0.60];
C.orange = [0.85 0.33 0.10];
LW.humanOutline = 0.7;
LW.networkOutline = 0.7;
LW.errbarHuman = 1.4;
LW.errbarNetwork = 1.4;

% Fixed DKL limits used for all network-depth panels.
xlimG = [0, 0.25];
ylimG = [-0.25, 0.25];

if doSave && ~exist(outdir, 'dir')
    mkdir(outdir);
end

%% ------------------------- HUMAN DATA -----------------------------------

% Load human thresholds once. These provide the group-mean filled diamonds that
% appear in every network panel.
assert(isfile(human_csv), 'Human CSV not found: %s', human_csv);
T = readtable(human_csv, 'TextType', 'string');
T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);

% Keep the same focus-filtering convention used by the other human scripts.
if ismember('orange_hue_focused', T.Properties.VariableNames)
    T = T(T.orange_hue_focused == 1, :);
end

% Standardize table columns used by the grouping functions.
T.ptID = string(T.ptID);
T.axis = lower(string(T.hue_chroma));
T.refLabel = lower(string(T.quadrant));
T.sign = lower(string(T.direction));

% Mean and SE per reference color, axis, and direction.
humanStats = humanThresholdStats(T);

% Chroma is radial from the reference; hue is the tangential direction.
[uchroma.purple, uhue.purple] = axesFromReference(refDKL.purple);
[uchroma.orange, uhue.orange] = axesFromReference(refDKL.orange);

% Human group-mean polygons are reused in every network panel.
polyHuman.purple = diamondPoly(refDKL.purple, ...
    humanStats.purple.chroma.pos.mean, humanStats.purple.chroma.neg.mean, ...
    humanStats.purple.hue.pos.mean, humanStats.purple.hue.neg.mean, ...
    uchroma.purple, uhue.purple);
polyHuman.orange = diamondPoly(refDKL.orange, ...
    humanStats.orange.chroma.pos.mean, humanStats.orange.chroma.neg.mean, ...
    humanStats.orange.hue.pos.mean, humanStats.orange.hue.neg.mean, ...
    uchroma.orange, uhue.orange);

%% ------------------------- NETWORK FIGURES ------------------------------

% Process every network independently and export one diamond plot per available
% depth. Network CSV files contain mean thresholds and optional threshold SE.
for k = 1:numel(allNetworks)
    network = allNetworks{k};
    network_csv = fullfile(scriptDir, 'data', 'network', network, [network, '_thresholds_stats.csv']);

    assert(isfile(network_csv), 'Network CSV not found: %s', network_csv);
    N = readtable(network_csv, 'TextType', 'string');
    N.Properties.VariableNames = matlab.lang.makeValidName(N.Properties.VariableNames);

    if ~ismember("threshold_se", N.Properties.VariableNames)
        N.threshold_se = nan(height(N), 1);
    end

    N.depth = lower(string(N.depth));
    N.refLabel = lower(string(N.quadrant));
    N.dir = lower(string(N.direction));

    depths = orderedDepths(unique(N.depth, 'stable'));

    % Build a nested threshold struct for each network depth.
    netByDepth = struct();
    for d = 1:numel(depths)
        dname = depths(d);
        rows = N(N.depth == dname, :);
        netByDepth.(dname) = networkThresholdStruct(rows);
    end

    % Export one panel per depth.
    for d = 1:numel(depths)
        dname = depths(d);
        Snet = netByDepth.(dname);

        polyNet.purple = diamondPoly(refDKL.purple, ...
            Snet.purple.chroma.pos.mean, Snet.purple.chroma.neg.mean, ...
            Snet.purple.hue.pos.mean, Snet.purple.hue.neg.mean, ...
            uchroma.purple, uhue.purple);
        polyNet.orange = diamondPoly(refDKL.orange, ...
            Snet.orange.chroma.pos.mean, Snet.orange.chroma.neg.mean, ...
            Snet.orange.hue.pos.mean, Snet.orange.hue.neg.mean, ...
            uchroma.orange, uhue.orange);

        fig = plotThresholdDiamondPanel(refDKL, polyHuman, polyNet, ...
            humanStats, Snet, uchroma, uhue, C, LW, xlimG, ylimG, twocolumn);

        if doSave
            pause(0.5)
            outname = sprintf('%s_%s_threshold_diamonds_%s.pdf', ...
                fig7NetworkPrefix(network), network, fig7DepthLabel(dname));
            exportgraphics(fig, fullfile(outdir, outname), ...
                'ContentType', 'vector', 'BackgroundColor', 'none');
        end
        close(fig)
    end
end

%% ------------------------- LOCAL FUNCTIONS ------------------------------

function depths = orderedDepths(depths)
    % Preserve a meaningful architectural ordering when those depth names exist.
    depthOrder = ["stem","layer1","layer2","layer3","layer4","fc"];
    depths = string(depths(:));
    ordered = strings(0, 1);
    for i = 1:numel(depthOrder)
        if any(depths == depthOrder(i))
            ordered(end+1, 1) = depthOrder(i); %#ok<AGROW>
        end
    end
    extra = setdiff(depths, ordered, 'stable');
    depths = [ordered; extra];
end

function prefix = fig7NetworkPrefix(network)
    % Assign manuscript panel prefixes to the selected network families.
    switch char(string(network))
        case 'resnet50'
            prefix = 'fig7a';
        case 'resnet50_flips'
            prefix = 'fig7b';
        otherwise
            prefix = 'fig7';
    end
end

function label = fig7DepthLabel(depthName)
    % Convert internal depth names to manuscript layer labels for filenames.
    switch char(string(depthName))
        case 'stem'
            label = 'layer0';
        case 'layer1'
            label = 'block1';
        case 'layer2'
            label = 'block2';
        case 'layer3'
            label = 'block3';
        case 'layer4'
            label = 'block4';
        case 'fc'
            label = 'fc';
        otherwise
            label = char(string(depthName));
    end
end

function fig = plotThresholdDiamondPanel(refDKL, polyHuman, polyNet, ...
    humanStats, Snet, uchroma, uhue, C, LW, xlimG, ylimG, twocolumn)
    % Draw one DKL threshold-diamond panel with human filled diamonds and network
    % outline diamonds.

    fig = figure('Color', 'w');
    ax = axes(fig);
    hold(ax, 'on');

    % DKL reference axes.
    plot(ax, xlimG, [0 0], ':', 'Color', 'k', 'LineWidth', 1);
    plot(ax, [0 0], ylimG, '-', 'Color', [0 0 0]);

    % Human group-mean filled diamonds.
    patch(ax, polyHuman.purple(:,1), polyHuman.purple(:,2), C.purple, ...
        'FaceAlpha', 0.1, 'EdgeColor', 'none');
    patch(ax, polyHuman.orange(:,1), polyHuman.orange(:,2), C.orange, ...
        'FaceAlpha', 0.1, 'EdgeColor', 'none');
    plot(ax, polyHuman.purple(:,1), polyHuman.purple(:,2), 'o-', ...
        'MarkerSize', 3.5, 'Color', C.purple, 'MarkerFaceColor', C.purple, ...
        'MarkerEdgeColor', 'none', 'LineWidth', LW.humanOutline);
    plot(ax, polyHuman.orange(:,1), polyHuman.orange(:,2), 'o-', ...
        'MarkerSize', 3.5, 'Color', C.orange, 'MarkerFaceColor', C.orange, ...
        'MarkerEdgeColor', 'none', 'LineWidth', LW.humanOutline);

    % Human SE bars.
    drawAxisSEBars(ax, refDKL.purple, humanStats.purple, ...
        uchroma.purple, uhue.purple, C.purple, LW.errbarHuman);
    drawAxisSEBars(ax, refDKL.orange, humanStats.orange, ...
        uchroma.orange, uhue.orange, C.orange, LW.errbarHuman);

    % Network outline diamonds and network SE bars.
    plot(ax, polyNet.purple(:,1), polyNet.purple(:,2), '-', ...
        'Color', C.purple, 'LineWidth', LW.networkOutline);
    plot(ax, polyNet.orange(:,1), polyNet.orange(:,2), '-', ...
        'Color', C.orange, 'LineWidth', LW.networkOutline);
    drawAxisSEBars(ax, refDKL.purple, Snet.purple, ...
        uchroma.purple, uhue.purple, C.purple, LW.errbarNetwork);
    drawAxisSEBars(ax, refDKL.orange, Snet.orange, ...
        uchroma.orange, uhue.orange, C.orange, LW.errbarNetwork);

    % Reference chromaticities.
    plot(ax, refDKL.purple(1), refDKL.purple(2), 'o', ...
        'MarkerSize', 2, 'MarkerFaceColor', C.purple, 'MarkerEdgeColor', 'none');
    plot(ax, refDKL.orange(1), refDKL.orange(2), 'o', ...
        'MarkerSize', 2, 'MarkerFaceColor', C.orange, 'MarkerEdgeColor', 'none');

    % Compact panel styling used by the existing threshold figures.
    ax.XTick = xlimG;
    ax.XLim = xlimG;
    ax.YTick = [ylimG(1) 0 ylimG(2)];
    ax.YLim = ylimG;
    ax.XTickLabel = [];
    ax.YTickLabel = [];
    ax.FontName = 'Arial';
    ax.FontSize = 7;
    ax.Color = ones(1,3) * 0.97;
    ax.Units = 'centimeters';
    ax.Position = [0.2 0.2 2.6 5.2];
    ax.LineWidth = 0.5;
    ax.XColor = 'k';
    ax.YColor = 'k';
    box(ax, 'on');
    grid(ax, 'minor');

    fig.PaperType = 'a4';
    fig.PaperUnits = 'centimeters';
    fig.Units = 'centimeters';
    fig.InvertHardcopy = 'off';
    fig.PaperPosition = [0, 10, twocolumn/6, twocolumn/3.2];
    fig.Position = [10, 10, twocolumn/6, twocolumn/3.2];
end

function S = humanThresholdStats(T)
    % Mean and SE are computed across participant-level mean thresholds.
    P = groupsummary(T, {'ptID','refLabel','axis','sign'}, 'mean', 'JND');
    G = groupsummary(P, {'refLabel','axis','sign'}, {'mean','std'}, 'mean_JND');
    refs = unique(G.refLabel);
    S = struct();
    for i = 1:numel(refs)
        r = refs(i);
        Gr = G(G.refLabel == r, :);
        S.(r).chroma.pos = pullStats(Gr, "chroma", "pos");
        S.(r).chroma.neg = pullStats(Gr, "chroma", "neg");
        S.(r).hue.pos = pullStats(Gr, "hue", "pos");
        S.(r).hue.neg = pullStats(Gr, "hue", "neg");
    end
end

function st = pullStats(G, axisName, signName)
    % Extract one condition's group mean and standard error.
    idx = lower(string(G.axis)) == axisName & lower(string(G.sign)) == signName;
    mu = G.mean_mean_JND(idx);
    sd = G.std_mean_JND(idx);
    n = G.GroupCount(idx);
    st.mean = mu;
    st.se = sd ./ max(1, sqrt(n));
end

function Sdepth = networkThresholdStruct(Nrows)
    % Convert network threshold rows for one depth into the same nested shape as
    % the human threshold stats.
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
    % Network files store direction-specific means and, when available, SE.
    idx = lower(string(T.dir)) == dirName;
    st.mean = mean(T.threshold_mean(idx), 'omitnan');
    if ismember('threshold_se', T.Properties.VariableNames)
        st.se = mean(T.threshold_se(idx), 'omitnan');
    else
        st.se = NaN;
    end
end

function [uChroma, uHue] = axesFromReference(ref)
    % Chroma is radial from the reference; hue is perpendicular in the DKL plane.
    n = norm(ref);
    uChroma = ref / n;
    uHue = [-uChroma(2), uChroma(1)];
end

function poly = diamondPoly(ref, tcpos, tcneg, thpos, thneg, uChroma, uHue)
    % Convert four signed thresholds into a closed diamond polygon.
    p1 = ref + tcpos * uChroma;
    p2 = ref + thpos * uHue;
    p3 = ref - tcneg * uChroma;
    p4 = ref - thneg * uHue;
    poly = [p1; p2; p3; p4; p1];
end

function drawAxisSEBars(ax, ref, Sref, uChroma, uHue, col, lw)
    % Draw one-dimensional SE bars along each threshold direction.
    draw1D(ax, ref, +1, Sref.chroma.pos.mean, Sref.chroma.pos.se, uChroma, col, lw);
    draw1D(ax, ref, -1, Sref.chroma.neg.mean, Sref.chroma.neg.se, uChroma, col, lw);
    draw1D(ax, ref, +1, Sref.hue.pos.mean, Sref.hue.pos.se, uHue, col, lw);
    draw1D(ax, ref, -1, Sref.hue.neg.mean, Sref.hue.neg.se, uHue, col, lw);
end

function draw1D(ax, ref, sgn, mu, se, u, col, lw)
    % Draw an SE interval centered on one signed threshold.
    if ~isfinite(mu) || ~isfinite(se) || se <= 0
        return
    end
    p1 = ref + (sgn * (mu - se)) * u;
    p2 = ref + (sgn * (mu + se)) * u;
    plot(ax, [p1(1) p2(1)], [p1(2) p2(2)], '-', 'Color', col, 'LineWidth', lw);
end
