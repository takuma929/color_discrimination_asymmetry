%% fig3_human_thresholds.m
% Build separate human-threshold figures from existing analysis scripts.
%
% Panels A and B reproduce the first two L-M versus S-(L+M) threshold plots
% from plot_human_thresholds.m:
%   A. Individual participant diamonds plus the group mean.
%   B. Group mean diamonds only.
%
% Panel C reproduces the human hue-chroma ratio scatter from analyze_thresholds.m.
%
% The script is operating-system independent:
%   - all paths are made with fullfile;
%   - input and output locations are resolved relative to this script;
%   - no path assumes macOS, Windows, or Linux separators;
%   - the script can be run from any MATLAB current folder.

clear; clc; close all

%% ------------------------- PATHS AND OPTIONS ----------------------------

% Resolve the folder containing this script. Using the script location instead
% of pwd makes the code robust when launched from another MATLAB folder.
scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    % Fallback for unusual interactive use, such as pasting the code into the
    % command window where mfilename('fullpath') is empty.
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

% Human threshold measurements used by the source scripts.
humanCsv = fullfile(scriptDir, 'data', 'human', 'human_thresholds.csv');

% Save the separate figures next to the other manuscript-style figure folders.
outdir = fullfile(scriptDir, 'figs');
doSave = true;

% Create the output folder only when the script is actually writing files.
if doSave && ~exist(outdir, 'dir')
    mkdir(outdir);
end

% Fail early with a clear message if the human data file is missing.
assert(isfile(humanCsv), 'Human CSV not found: %s', humanCsv);

%% ------------------------- CONSTANTS AND STYLE --------------------------

% Reference object coordinates in DKL space: [L-M, S].
refDKL.purple = [0.1191,  0.1191];
refDKL.orange = [0.1191, -0.1191];

% Colors inherited from the original figure scripts.
C.purple = [0.50 0.20 0.60];
C.orange = [0.85 0.33 0.10];

% Line widths inherited from plot_human_thresholds.m.
LW.humanOutline = 0.5;
LW.errbarHuman = 1.0;
LW.individual = 0.1;

% Figure dimensions in centimeters.
twocolumn = 17.8;

% Shared DKL axis limits for the two threshold-diamond panels.
dklXLim = [0, 0.25];
dklYLim = [-0.25, 0.25];

% Shared hue-chroma ratio limits for the scatter panel.
hsiXLim = [-0.15, 0.4];
hsiYLim = [-0.15, 0.4];

%% ------------------------- LOAD AND PREPARE DATA ------------------------

% Read the human CSV as strings where possible, then make variable names valid
% MATLAB identifiers so later code is insensitive to spaces or punctuation.
T = readtable(humanCsv, 'TextType', 'string');
T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);

% Preserve the source-script filter. If the column exists, use only the rows
% that passed the orange-hue focus criterion.
if ismember('orange_hue_focused', T.Properties.VariableNames)
    T = T(T.orange_hue_focused == 1, :);
end

% Normalize the categorical columns used by the helper functions.
T.ptID = string(T.ptID);
T.axis = lower(string(T.hue_chroma));    % "hue" or "chroma"
T.refLabel = lower(string(T.quadrant));  % "purple" or "orange"
T.sign = lower(string(T.direction));     % "pos" or "neg"

% Group mean and standard error for every reference, axis, and direction.
humanStats = humanThresholdStats(T);

% Per-participant means for the individual diamonds in panel A.
ptMeans = humanParticipantMeans(T);
ptList = fieldnames(ptMeans);

% Unit vectors pointing along chroma and hue axes for each DKL reference.
[uchroma.purple, uhue.purple] = axesFromReference(refDKL.purple);
[uchroma.orange, uhue.orange] = axesFromReference(refDKL.orange);

% Group mean diamond polygons used in both DKL panels.
polyHumanMean.purple = diamondPoly(refDKL.purple, ...
    humanStats.purple.chroma.pos.mean, humanStats.purple.chroma.neg.mean, ...
    humanStats.purple.hue.pos.mean, humanStats.purple.hue.neg.mean, ...
    uchroma.purple, uhue.purple);

polyHumanMean.orange = diamondPoly(refDKL.orange, ...
    humanStats.orange.chroma.pos.mean, humanStats.orange.chroma.neg.mean, ...
    humanStats.orange.hue.pos.mean, humanStats.orange.hue.neg.mean, ...
    uchroma.orange, uhue.orange);

% Human hue-chroma ratio values for panel C.
[~, xHuman, yHuman, xHumanMean, yHumanMean, xHumanSE, yHumanSE] = humanHSI(T);

%% ------------------------- SEPARATE FIGURES -----------------------------

% Create each requested plot in a separate figure, matching the behavior of the
% source scripts and making each panel easy to place independently later.

% Figure 1: individual participant diamonds plus group mean.
figA = localNewFigure(twocolumn / 4, twocolumn / 2 * 0.85);
axA = axes(figA);
plotHumanDiamondsWithIndividuals(axA, ptMeans, ptList, refDKL, ...
    uchroma, uhue, polyHumanMean, humanStats, C, LW, dklXLim, dklYLim);
axA.Units = 'centimeters';
axA.Position = [1 0.7 3.4 6.8];

% Figure 2: group mean threshold diamonds only.
figB = localNewFigure(twocolumn / 4, twocolumn / 2 * 0.85);
axB = axes(figB);
plotHumanMeanDiamonds(axB, refDKL, uchroma, uhue, polyHumanMean, ...
    humanStats, C, LW, dklXLim, dklYLim);
axB.Units = 'centimeters';
axB.Position = [1 0.7 3.4 6.8];

% Figure 3: hue-chroma ratio scatter with individual humans and group mean.
figC = localNewFigure(twocolumn / 2 * 0.9, twocolumn / 2 * 0.9);
axC = axes(figC);
plotHumanHueChromaScatter(axC, xHuman, yHuman, xHumanMean, yHumanMean, ...
    xHumanSE, yHumanSE, C, hsiXLim, hsiYLim);
axC.Units = 'centimeters';
axC.Position = [1.1 1.0 6.6 6.6];

% Save vector and raster versions of each separate figure.
if doSave
    pause(0.1)
    exportgraphics(figA, fullfile(outdir, sprintf('fig3a_human_individuals_N%d.pdf', numel(ptList))), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');

    exportgraphics(figB, fullfile(outdir, sprintf('fig3b_human_mean_N%d.pdf', numel(ptList))), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');

    exportgraphics(figC, fullfile(outdir, sprintf('fig3c_human_scatter_hue_chroma_ratio_N%d.pdf', numel(xHuman))), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
end

%% ------------------------- LOCAL PLOTTING FUNCTIONS ---------------------

function fig = localNewFigure(figWidth, figHeight)
    % Create one consistently sized, white-background figure for export.
    fig = figure('Color', 'w');
    fig.PaperType = 'a4';
    fig.PaperUnits = 'centimeters';
    fig.Units = 'centimeters';
    fig.InvertHardcopy = 'off';
    fig.PaperPosition = [0, 10, figWidth, figHeight];
    fig.Position = [10, 10, figWidth, figHeight];
end

function plotHumanDiamondsWithIndividuals(ax, ptMeans, ptList, refDKL, ...
    uchroma, uhue, polyHumanMean, humanStats, C, LW, xlimVals, ylimVals)
    % Draw all participant threshold diamonds as thin outlines, then overlay
    % the group mean filled polygons and standard-error bars.

    axes(ax); %#ok<LAXES>
    hold(ax, 'on');
    drawDklReferenceAxes(ax, xlimVals, ylimVals);

    % Individual participant threshold diamonds.
    for iPt = 1:numel(ptList)
        pid = ptList{iPt};
        Spt = ptMeans.(pid);

        if isValidPt(Spt.purple)
            polyP = diamondPoly(refDKL.purple, ...
                Spt.purple.chroma.pos.mean, Spt.purple.chroma.neg.mean, ...
                Spt.purple.hue.pos.mean, Spt.purple.hue.neg.mean, ...
                uchroma.purple, uhue.purple);

            plot(ax, polyP(:,1), polyP(:,2), '-', ...
                'MarkerSize', 4, 'Color', C.purple, ...
                'MarkerFaceColor', C.purple, 'MarkerEdgeColor', 'none', ...
                'LineWidth', LW.individual);
        end

        if isValidPt(Spt.orange)
            polyO = diamondPoly(refDKL.orange, ...
                Spt.orange.chroma.pos.mean, Spt.orange.chroma.neg.mean, ...
                Spt.orange.hue.pos.mean, Spt.orange.hue.neg.mean, ...
                uchroma.orange, uhue.orange);

            plot(ax, polyO(:,1), polyO(:,2), '-', ...
                'MarkerSize', 4, 'Color', C.orange, ...
                'MarkerFaceColor', C.orange, 'MarkerEdgeColor', 'none', ...
                'LineWidth', LW.individual);
        end
    end

    % Group mean filled polygons and standard-error bars.
    drawHumanMeanDiamondElements(ax, refDKL, uchroma, uhue, polyHumanMean, ...
        humanStats, C, LW, false);
    styleDklAxes(ax, xlimVals, ylimVals);
end

function plotHumanMeanDiamonds(ax, refDKL, uchroma, uhue, polyHumanMean, ...
    humanStats, C, LW, xlimVals, ylimVals)
    % Draw only the group mean threshold diamonds with the original outline,
    % fill, reference points, and standard-error bars.

    axes(ax); %#ok<LAXES>
    hold(ax, 'on');
    drawDklReferenceAxes(ax, xlimVals, ylimVals);
    drawHumanMeanDiamondElements(ax, refDKL, uchroma, uhue, polyHumanMean, ...
        humanStats, C, LW, true);
    styleDklAxes(ax, xlimVals, ylimVals);
end

function drawHumanMeanDiamondElements(ax, refDKL, uchroma, uhue, polyHumanMean, ...
    humanStats, C, LW, drawOutline)
    % Shared group-mean diamond layers used by both DKL panels.

    patch(ax, polyHumanMean.purple(:,1), polyHumanMean.purple(:,2), C.purple, ...
        'FaceAlpha', 0.1, 'EdgeColor', 'none');
    patch(ax, polyHumanMean.orange(:,1), polyHumanMean.orange(:,2), C.orange, ...
        'FaceAlpha', 0.1, 'EdgeColor', 'none');

    if drawOutline
        plot(ax, polyHumanMean.purple(:,1), polyHumanMean.purple(:,2), 'o-', ...
            'MarkerSize', 4, 'Color', C.purple, 'MarkerFaceColor', C.purple, ...
            'MarkerEdgeColor', 'none', 'LineWidth', LW.humanOutline);
        plot(ax, polyHumanMean.orange(:,1), polyHumanMean.orange(:,2), 'o-', ...
            'MarkerSize', 4, 'Color', C.orange, 'MarkerFaceColor', C.orange, ...
            'MarkerEdgeColor', 'none', 'LineWidth', LW.humanOutline);
    end

    drawAxisSEBars(ax, refDKL.purple, humanStats.purple, ...
        uchroma.purple, uhue.purple, C.purple, LW.errbarHuman);
    drawAxisSEBars(ax, refDKL.orange, humanStats.orange, ...
        uchroma.orange, uhue.orange, C.orange, LW.errbarHuman);

    plot(ax, refDKL.purple(1), refDKL.purple(2), 'o', 'MarkerSize', 3, ...
        'MarkerFaceColor', C.purple, 'MarkerEdgeColor', 'none');
    plot(ax, refDKL.orange(1), refDKL.orange(2), 'o', 'MarkerSize', 3, ...
        'MarkerFaceColor', C.orange, 'MarkerEdgeColor', 'none');
end

function plotHumanHueChromaScatter(ax, xHuman, yHuman, xHumanMean, yHumanMean, ...
    xHumanSE, yHumanSE, C, xlimVals, ylimVals)
    % Draw the human hue-chroma ratio scatter from analyze_thresholds.m.
    % x is the purple log10 chroma/hue threshold ratio; y is the orange ratio.

    axes(ax); %#ok<LAXES>
    hold(ax, 'on');

    % Background triangles mark the side of the diagonal where purple or orange
    % has the larger hue-chroma asymmetry.
    patch(ax, [xlimVals(1) xlimVals(2) xlimVals(2)], ...
        [ylimVals(1) ylimVals(1) ylimVals(2)], C.purple, ...
        'EdgeColor', 'none', 'FaceAlpha', 0.10);
    patch(ax, [xlimVals(1) xlimVals(1) xlimVals(2)], ...
        [ylimVals(1) ylimVals(2) ylimVals(2)], C.orange, ...
        'EdgeColor', 'none', 'FaceAlpha', 0.10);

    % Diagonal equality line and zero-reference lines.
    plot(ax, xlimVals, ylimVals, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
    line(ax, [0 0], ylimVals, 'LineStyle', ':', 'Color', 'k', 'LineWidth', 1);
    line(ax, xlimVals, [0 0], 'LineStyle', ':', 'Color', 'k', 'LineWidth', 1);

    % Individual participant points.
    scatter(ax, xHuman, yHuman, 36, [0.4 0.4 0.4], 'o', 'filled', ...
        'MarkerFaceAlpha', 0.4);

    % Group mean with vertical and horizontal standard-error bars.
    errorbar(ax, xHumanMean, yHumanMean, yHumanSE, yHumanSE, 'k', ...
        'LineWidth', 1.6, 'CapSize', 0);
    line(ax, [xHumanMean - xHumanSE, xHumanMean + xHumanSE], ...
        [yHumanMean, yHumanMean], 'Color', 'k', 'LineWidth', 1);
    plot(ax, xHumanMean, yHumanMean, 'o', 'MarkerFaceColor', 'k', ...
        'MarkerEdgeColor', 'w', 'MarkerSize', 8);

    xlabel(ax, 'log_1_0 hue / chroma sensitivity (purple)', 'FontWeight', 'bold');
    ylabel(ax, 'log_1_0 hue / chroma sensitivity (orange)', 'FontWeight', 'bold');

    ax.XLim = xlimVals;
    ax.YLim = ylimVals;
    ax.XTick = [-0.10 0.0 0.1 0.2 0.3 0.4];
    ax.YTick = [-0.10 0.0 0.1 0.2 0.3 0.4];
    ax.XTickLabel = {'-0.10', '0.00', '0.10', '0.20', '0.30', '0.40'};
    ax.YTickLabel = {'-0.10', '0.00', '0.10', '0.20', '0.30', '0.40'};
    styleCommonAxes(ax);
    axis(ax, 'square');
end

function drawDklReferenceAxes(ax, xlimVals, ylimVals)
    % Draw the zero lines in DKL space before plotting thresholds.
    plot(ax, xlimVals, [0 0], ':', 'Color', 'k', 'LineWidth', 1);
    plot(ax, [0 0], ylimVals, '-', 'Color', [0 0 0]);
end

function styleDklAxes(ax, xlimVals, ylimVals)
    % Apply the common DKL panel labels, ticks, limits, and visual styling.
    xlabel(ax, 'L-M', 'FontWeight', 'bold');
    ylabel(ax, 'S-(L+M)', 'FontWeight', 'bold');
    ax.XTick = [0 0.1 0.2];
    ax.YTick = [-0.2 -0.1 0 0.1 0.2];
    ax.XTickLabel = {'0.00', '0.10', '0.20'};
    ax.YTickLabel = {'-0.20', '-0.10', '0.00', '0.10', '0.20'};
    ax.XLim = xlimVals;
    ax.YLim = ylimVals;
    styleCommonAxes(ax);
end

function styleCommonAxes(ax)
    % Shared axes styling copied from the source figure scripts.
    ax.FontName = 'Arial';
    ax.FontSize = 7;
    ax.LineWidth = 0.5;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.Color = ones(1, 3) * 0.97;
    box(ax, 'on');
    grid(ax, 'minor');
end

%% ------------------------- LOCAL DATA FUNCTIONS -------------------------

function tf = isValidPt(Sref)
    % A participant diamond is drawable only if all four threshold means exist.
    vals = [Sref.chroma.pos.mean, Sref.chroma.neg.mean, ...
        Sref.hue.pos.mean, Sref.hue.neg.mean];
    tf = all(isfinite(vals));
end

function S = humanParticipantMeans(T)
    % Return per-participant mean thresholds per reference, axis, and direction.
    % Structure example:
    %   S.(ptID).purple.chroma.pos.mean

    P = groupsummary(T, {'ptID', 'refLabel', 'axis', 'sign'}, 'mean', 'JND');
    P.ptID = string(P.ptID);
    P.refLabel = lower(string(P.refLabel));
    P.axis = lower(string(P.axis));
    P.sign = lower(string(P.sign));

    ptList = unique(P.ptID, 'stable');
    S = struct();

    for iPt = 1:numel(ptList)
        pid = ptList(iPt);
        % Dynamic struct field names are safest as character vectors across
        % MATLAB releases, so convert the participant ID explicitly.
        pidField = char(matlab.lang.makeValidName(char(pid)));

        for ref = ["purple", "orange"]
            for axisName = ["chroma", "hue"]
                for signName = ["pos", "neg"]
                    idx = (P.ptID == pid) & (P.refLabel == ref) & ...
                        (P.axis == axisName) & (P.sign == signName);

                    if any(idx)
                        mu = P.mean_JND(find(idx, 1, 'first'));
                    else
                        mu = NaN;
                    end

                    refField = char(ref);
                    axisField = char(axisName);
                    signField = char(signName);
                    S.(pidField).(refField).(axisField).(signField).mean = mu;
                    S.(pidField).(refField).(axisField).(signField).se = NaN;
                end
            end
        end
    end
end

function S = humanThresholdStats(T)
    % Compute group mean and SE across participants for each condition.
    % First average repeated measurements within each participant, then compute
    % the participant-level group summary.

    P = groupsummary(T, {'ptID', 'refLabel', 'axis', 'sign'}, 'mean', 'JND');
    G = groupsummary(P, {'refLabel', 'axis', 'sign'}, {'mean', 'std'}, 'mean_JND');
    refs = unique(G.refLabel);
    S = struct();

    for iRef = 1:numel(refs)
        refField = char(refs(iRef));
        Gr = G(G.refLabel == refs(iRef), :);
        S.(refField).chroma.pos = pullStats(Gr, "chroma", "pos");
        S.(refField).chroma.neg = pullStats(Gr, "chroma", "neg");
        S.(refField).hue.pos = pullStats(Gr, "hue", "pos");
        S.(refField).hue.neg = pullStats(Gr, "hue", "neg");
    end
end

function st = pullStats(G, axisName, signName)
    % Extract the mean, standard deviation, and sample count for one condition,
    % then convert standard deviation to standard error.
    idx = lower(string(G.axis)) == axisName & lower(string(G.sign)) == signName;
    mu = G.mean_mean_JND(idx);
    sd = G.std_mean_JND(idx);
    n = G.GroupCount(idx);
    st.mean = mu;
    st.se = sd ./ max(1, sqrt(n));
end

function [uChroma, uHue] = axesFromReference(ref)
    % Chroma points radially through the reference. Hue is the perpendicular
    % direction in the DKL plane.
    n = norm(ref);
    uChroma = ref / n;
    uHue = [-uChroma(2), uChroma(1)];
end

function poly = diamondPoly(ref, tcpos, tcneg, thpos, thneg, uChroma, uHue)
    % Convert four one-dimensional thresholds into a closed DKL diamond polygon.
    p1 = ref + tcpos * uChroma;
    p2 = ref + thpos * uHue;
    p3 = ref - tcneg * uChroma;
    p4 = ref - thneg * uHue;
    poly = [p1; p2; p3; p4; p1];
end

function drawAxisSEBars(ax, ref, Sref, uChroma, uHue, col, lw)
    % Draw one standard-error bar along each threshold axis/direction.
    draw1D(ax, ref, +1, Sref.chroma.pos.mean, Sref.chroma.pos.se, uChroma, col, lw);
    draw1D(ax, ref, -1, Sref.chroma.neg.mean, Sref.chroma.neg.se, uChroma, col, lw);
    draw1D(ax, ref, +1, Sref.hue.pos.mean, Sref.hue.pos.se, uHue, col, lw);
    draw1D(ax, ref, -1, Sref.hue.neg.mean, Sref.hue.neg.se, uHue, col, lw);
end

function draw1D(ax, ref, sgn, mu, se, u, col, lw)
    % Draw a single error interval centered on one signed threshold mean.
    if ~isfinite(mu) || ~isfinite(se) || se <= 0
        return
    end

    p1 = ref + (sgn * (mu - se)) * u;
    p2 = ref + (sgn * (mu + se)) * u;
    plot(ax, [p1(1) p2(1)], [p1(2) p2(2)], '-', 'Color', col, 'LineWidth', lw);
end

function [H_HSI, xHuman, yHuman, xHumanMean, yHumanMean, xHumanSE, yHumanSE] = humanHSI(T)
    % Compute each participant's hue-chroma index for purple and orange.
    % The source scripts define HSI as chroma threshold divided by hue threshold,
    % then plot log10(HSI) for purple against log10(HSI) for orange.

    Hgrp = groupsummary(T, {'ptID', 'refLabel', 'axis'}, 'mean', 'JND');
    Hwide = unstack(Hgrp, 'mean_JND', 'axis');
    epsDen = 1e-12;
    Hwide.HSI = Hwide.chroma ./ max(Hwide.hue, epsDen);

    H_HSI = unstack(Hwide(:, {'ptID', 'refLabel', 'HSI'}), 'HSI', 'refLabel');
    H_HSI = rmmissing(H_HSI, 'DataVariables', {'purple', 'orange'});

    xHuman = log10(H_HSI.purple);
    yHuman = log10(H_HSI.orange);
    xHumanMean = mean(xHuman, 'omitnan');
    yHumanMean = mean(yHuman, 'omitnan');

    n = height(H_HSI);
    xHumanSE = std(xHuman, 'omitnan') / sqrt(n);
    yHumanSE = std(yHuman, 'omitnan') / sqrt(n);
end
