%% fig2_hue_histogram.m
% Reads all *_hue_histogram.csv files in folder,
% normalizes counts, groups foster_nascimento datasets,
% draws custom polar histograms with colored wedges,
% overlays thick hue circle, and reports quadrant proportions.
% Orientation: 0° at +x, angles increase clockwise.
% NOTE: DKL S-axis flipped (y -> -y), so quadrants remapped:
%   Purple = 0–90°, Orange = 270–360°

clearvars; close all; clc;

%% ------------------------- PATHS AND SETTINGS ---------------------------

% Resolve paths relative to this script so the code runs from any MATLAB folder
% and on any operating system.
scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

twocolumn = 17.8;

% CSV input folder and output folder.
dataDir = fullfile(scriptDir, 'data', 'dkl_hist_results');
outDir  = fullfile(scriptDir, 'figs');
if ~exist(outDir,'dir'), mkdir(outDir); end

localWriteTinyTaskonomyHueHistogram(dataDir);

%% ------------------------- HUE COLOR LOOKUP -----------------------------

% Hue ring palette for the 24 histogram bins. Colors are generated from the
% same DKL hue circle used in the analysis and gamma adjusted for display.
nHue = 24;
theta = linspace(0,2*pi,nHue+1); theta(end) = [];
rgb = zeros(3,nHue);
for k = 1:nHue
    rgb(:,k) = fromDKL([0 0.4*cos(theta(k)) 0.4*sin(theta(k))],1).^(1/2.2);
end

% Higher-resolution colors for the outer continuous hue annulus.
nCirc = 1080;
thetaCirc = linspace(0,2*pi,nCirc);
rgbCirc = zeros(nCirc,3);
for k = 1:nCirc
    rgbCirc(k,:) = fromDKL([0 0.4*cos(thetaCirc(k)) 0.4*sin(thetaCirc(k))],1).^(1/2.2);
end

%% ------------------------- FILE GROUPING --------------------------------

csvFiles = dir(fullfile(dataDir,'*_hue_histogram.csv'));
if isempty(csvFiles)
    error('No *_hue_histogram.csv files found in %s', dataDir);
end

% ---- group files by base name (strip trailing digits & spaces) ----
datasetMap = containers.Map;
for f = 1:numel(csvFiles)
    fname = csvFiles(f).name;

    % The sign-flipped ImageNet histogram is a network-training control (see
    % Figure 7b), not one of the natural-image databases shown in Figure 2, so
    % it is not drawn here.
    if contains(fname, 'flips')
        continue
    end

    datasetName = erase(fname,'_hue_histogram.csv');

    % Normalize names by removing spaces. Some datasets have multiple files with
    % numeric suffixes; these are merged into one displayed dataset.
    normName = regexprep(datasetName,'\s+','');   
    
    % Special handling for datasets whose files should be grouped under a shared
    % dataset name.
    if contains(normName,'foster_nascimento')
        baseName = 'foster_nascimento';
    elseif contains(normName,'tokyo_tech')
        baseName = 'tokyo_tech';
    else
        baseName = regexprep(normName,'\d+$',''); % strip trailing digits
    end
    
    % Add this file to the dataset group.
    if ~isKey(datasetMap, baseName)
        datasetMap(baseName) = {fname};
    else
        tmp = datasetMap(baseName);
        tmp{end+1} = fname;
        datasetMap(baseName) = tmp;
    end
end

%% ------------------------- DRAW HISTOGRAMS ------------------------------

% ---- process each dataset group ----
datasetKeys = keys(datasetMap);
for g = 1:numel(datasetKeys)
    baseName = datasetKeys{g};
    fileList = datasetMap(baseName);

    % initialize counts
    counts_total = [];
    edges_lo = [];
    edges_hi = [];

    % Sum counts across all CSV files assigned to this dataset group.
    for f = 1:numel(fileList)
        T = readtable(fullfile(dataDir,fileList{f}));
        if isempty(counts_total)
            edges_lo = T.hue_edge_lo_deg;
            edges_hi = T.hue_edge_hi_deg;
            counts_total = T.count;
        else
            counts_total = counts_total + T.count;
        end
    end

    % Normalize by peak count so each radial plot uses the same unit radius.
    counts = counts_total ./ max(counts_total);

    fig = localDrawHueHistogramFigure(counts, edges_lo, edges_hi, rgb, ...
        rgbCirc, thetaCirc, twocolumn, 0:45:315);

    % ---- save ----
    histName = ['fig2_' baseName '_histogram.png'];
    exportgraphics(fig, fullfile(outDir, histName), ...
        'ContentType','image','BackgroundColor','none','Resolution',600);
    close(fig);
    fprintf('%s successfully saved.\n', histName);
end

%% ------------------------- DRAW AGGREGATE HISTOGRAMS --------------------

rgbAggregateFiles = localSelectAggregateFiles(csvFiles, 'rgb');
hyperAggregateFiles = localSelectAggregateFiles(csvFiles, 'hyperspectral');

localDrawAggregateHueHistogram('all_rgb', rgbAggregateFiles, dataDir, outDir, ...
    rgb, rgbCirc, thetaCirc, twocolumn);
localDrawAggregateHueHistogram('all_hyperspectral', hyperAggregateFiles, dataDir, outDir, ...
    rgb, rgbCirc, thetaCirc, twocolumn);

figExtract = localDrawHueCircleQuadrantsFigure(rgbCirc, thetaCirc, twocolumn);
exportgraphics(figExtract, fullfile(outDir, 'fig2_hue_circle_quadrants_extract.png'), ...
    'ContentType','image','BackgroundColor','none','Resolution',600);
close(figExtract);
fprintf('%s successfully saved.\n', 'fig2_hue_circle_quadrants_extract.png');

%% ---------------- Collect proportions across datasets ----------------
orangeProps = [];
purpleProps = [];

for g = 1:numel(datasetKeys)
    baseName = datasetKeys{g};
    fileList = datasetMap(baseName);

    % initialize counts
    counts_total = [];
    edges_lo = [];
    edges_hi = [];

    % Sum counts across all files in this dataset group.
    for f = 1:numel(fileList)
        T = readtable(fullfile(dataDir,fileList{f}));
        if isempty(counts_total)
            edges_lo = T.hue_edge_lo_deg;
            edges_hi = T.hue_edge_hi_deg;
            counts_total = T.count;
        else
            counts_total = counts_total + T.count;
        end
    end

    % Normalize by peak count before computing quadrant proportions.
    counts = counts_total ./ max(counts_total);

    % ---- Flip S-axis and compute quadrant proportions ----
    centers = mod(-((edges_lo + edges_hi)/2), 360);

    [orangeMask, purpleMask] = localQuadrantMasks(centers, fileList);

    orangeProp = sum(counts(orangeMask)) / sum(counts);
    purpleProp = sum(counts(purpleMask)) / sum(counts);
    orangeProps(end+1) = orangeProp;
    purpleProps(end+1) = purpleProp;
end

%% ---------------- Statistical comparison ----------------
% Paired comparison across datasets. MATLAB's default paired ttest is two-tailed.
[~,p,~,stats] = ttest(orangeProps, purpleProps);

diffVals = orangeProps - purpleProps;
meanOrangePct = mean(orangeProps) * 100;
meanPurplePct = mean(purpleProps) * 100;
meanDiff = mean(diffVals);
sdDiff   = std(diffVals,1); % population SD
cohens_d = meanDiff / sdDiff;

fprintf('Orange vs purple quadrant fraction across %d datasets: orange = %.1f%%, purple = %.1f%%\n', ...
    numel(orangeProps), meanOrangePct, meanPurplePct);
fprintf('Two-tailed paired t-test: t(%d) = %.1f, p = %.3g, Cohen''s d = %.2f\n', ...
    stats.df, stats.tstat, p, cohens_d);

function localWriteTinyTaskonomyHueHistogram(dataDir)
    % Convert per-scene Tiny Taskonomy .mat count files into the same hue
    % histogram CSV format used by the other image databases.
    tinyDir = fullfile(dataDir, 'tiny_taskonomy_dkl_histcount');
    matFiles = dir(fullfile(tinyDir, 'tiny_taskonomy_*_count.mat'));
    if isempty(matFiles)
        warning('No Tiny Taskonomy count files found in %s', tinyDir);
        return
    end

    countsTotal = [];
    hueEdgesRad = [];
    for iFile = 1:numel(matFiles)
        S = load(fullfile(tinyDir, matFiles(iFile).name));
        if ~isfield(S, 'Out') || ~isfield(S.Out, 'counted') || ...
                ~isfield(S.Out.counted, 'all') || ~isfield(S.Out, 'hueedge')
            warning('Skipping Tiny Taskonomy file with unexpected fields: %s', ...
                matFiles(iFile).name);
            continue
        end

        if isempty(hueEdgesRad)
            hueEdgesRad = S.Out.hueedge(:);
            countsTotal = zeros(numel(hueEdgesRad) - 1, 1);
        elseif any(abs(hueEdgesRad - S.Out.hueedge(:)) > 1e-10)
            error('Hue bin edges do not match in %s', matFiles(iFile).name);
        end

        % counted.all is hue x image (chroma already summed out); sum over
        % images to get the per-hue pixel count for this scene.
        countsThis = sum(S.Out.counted.all, 2);
        countsTotal = countsTotal + countsThis(:);
    end

    if isempty(hueEdgesRad)
        error('No valid Tiny Taskonomy count files found in %s', tinyDir);
    end

    edgesDeg = rad2deg(hueEdgesRad);
    edgeLo = edgesDeg(1:end-1);
    edgeHi = edgesDeg(2:end);
    hueBin = (1:numel(countsTotal))';
    hueCenter = (edgeLo + edgeHi) / 2;

    Ttiny = table(hueBin, hueCenter, edgeLo, edgeHi, countsTotal, ...
        'VariableNames', {'hue_bin','hue_center_deg','hue_edge_lo_deg', ...
        'hue_edge_hi_deg','count'});
    writetable(Ttiny, fullfile(dataDir, 'tiny_taskonomy_hue_histogram.csv'));
end

function [orangeMask, purpleMask] = localQuadrantMasks(centers, fileList)
    orangeMask = (centers >= 270 & centers < 360);
    purpleMask = (centers >=   0 & centers <  90);

    % Mirroring an orange boundary bin at 270 degrees lands it exactly on
    % the purple upper boundary at 90 degrees in flipS histograms.
    if any(contains(fileList, 'flips'))
        purpleMask = (centers >= 0 & centers <= 90);
    end
end

function fileNames = localSelectAggregateFiles(csvFiles, aggregateType)
    % Select source image databases for aggregate hue histograms.
    fileNames = {};
    for i = 1:numel(csvFiles)
        fname = csvFiles(i).name;
        % Hyperspectral databases, identified by name.
        hyperspectralDatasets = {'icvl', 'harvard', 'tokyo_tech', ...
            'foster_nascimento', 'cave', 'granada'};
        isHyper = any(startsWith(fname, hyperspectralDatasets));
        isFlip = contains(fname, 'flips');
        isNaturalRefs = startsWith(fname, 'natural_reflectance');

        if strcmp(aggregateType, 'hyperspectral') && isHyper
            fileNames{end+1} = fname; %#ok<AGROW>
        elseif strcmp(aggregateType, 'rgb') && ~isHyper && ~isFlip && ~isNaturalRefs
            fileNames{end+1} = fname; %#ok<AGROW>
        end
    end
end

function localDrawAggregateHueHistogram(baseName, fileList, dataDir, outDir, rgb, rgbCirc, thetaCirc, twocolumn)
    % Sum counts across a database class and draw one normalized polar histogram.
    if isempty(fileList)
        warning('No files found for aggregate histogram: %s', baseName);
        return
    end

    counts_total = [];
    edges_lo = [];
    edges_hi = [];
    for f = 1:numel(fileList)
        T = readtable(fullfile(dataDir, fileList{f}));
        if isempty(counts_total)
            edges_lo = T.hue_edge_lo_deg;
            edges_hi = T.hue_edge_hi_deg;
            counts_total = T.count;
        else
            counts_total = counts_total + T.count;
        end
    end

    counts = counts_total ./ max(counts_total);

    fig = localDrawHueHistogramFigure(counts, edges_lo, edges_hi, rgb, ...
        rgbCirc, thetaCirc, twocolumn, 0:45:315);
    histName = ['fig2_' baseName '_histogram.png'];
    exportgraphics(fig, fullfile(outDir, histName), ...
        'ContentType', 'image', 'BackgroundColor', 'none', 'Resolution', 600);
    close(fig);
    fprintf('%s successfully saved.\n', histName);
end

function fig = localDrawHueHistogramFigure(counts, edges_lo, edges_hi, rgb, rgbCirc, thetaCirc, twocolumn, radialAngles)
    fig = figure; hold on; axis equal off;

    % Draw colored histogram wedges.
    for k = 1:numel(counts)
        th = linspace(edges_lo(k), edges_hi(k), 50);
        th = deg2rad(th);
        r = counts(k) * ones(size(th));
        [x, y] = pol2cart(th, r);
        y = -y; % flip Y for clockwise orientation
        patch([0 x 0], [0 y 0], rgb(:,k)', ...
            'EdgeColor', 'k', 'FaceAlpha', 1, 'LineWidth', 0.1);
    end

    % Overlay thick hue circle as annulus.
    r_in = 1.05;
    r_out = 1.15;
    for k = 1:numel(thetaCirc)-1
        th = [thetaCirc(k), thetaCirc(k+1)];
        [x_in, y_in] = pol2cart(th, r_in * ones(1,2));
        [x_out, y_out] = pol2cart(fliplr(th), r_out * ones(1,2));
        y_in = -y_in;
        y_out = -y_out;
        c = mean(rgbCirc(k:k+1,:), 1);
        patch([x_in x_out], [y_in y_out], c, 'EdgeColor', 'none');
    end

    maxR = 1.0;
    for ang = radialAngles
        th = deg2rad(ang);
        [xg, yg] = pol2cart(th, maxR * 1.1);
        yg = -yg;
        line([0 xg], [0 yg], ...
             'Color', [0.7 0.7 0.7], 'LineStyle', '-', 'LineWidth', 0.1);
    end

    for R = linspace(0, 1, 5)
        angs = linspace(0, 2*pi, 360);
        [xc, yc] = pol2cart(angs, R);
        yc = -yc;
        plot(xc, yc, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.1);
    end

    fig.Color = 'w';
    ax = gca;
    axis equal; axis off;
    ax.Color = ones(1,3) * 0.97;
    ax.GridAlpha = 0.2;
    ax.MinorGridAlpha = 0.1;

    fig.PaperType = 'a4'; fig.PaperUnits = 'centimeters';
    fig.Units = 'centimeters'; fig.Color = 'w';
    fig.InvertHardcopy = 'off';
    figSize = twocolumn / 6;
    fig.PaperPosition = [0, 10, figSize, figSize];
    fig.Position = [0, 10, figSize, figSize];
    ax.FontName = 'Helvetica'; ax.FontSize = 5;
    ax.LineWidth = 0.2;
    ax.Units = 'centimeters';
    ax.Position = [-0.65 -0.65 4.3 4.3];
    grid on
end

function fig = localDrawHueCircleQuadrantsFigure(rgbCirc, thetaCirc, twocolumn)
    fig = figure; hold on; axis equal off;

    r_in = 1.05;
    r_out = 1.15;
    for k = 1:numel(thetaCirc)-1
        th = [thetaCirc(k), thetaCirc(k+1)];
        [x_in, y_in] = pol2cart(th, r_in * ones(1,2));
        [x_out, y_out] = pol2cart(fliplr(th), r_out * ones(1,2));
        y_in = -y_in;
        y_out = -y_out;
        c = mean(rgbCirc(k:k+1,:), 1);
        patch([x_in x_out], [y_in y_out], c, 'EdgeColor', 'none');
    end

    for ang = 0:90:270
        th = deg2rad(ang);
        [xg, yg] = pol2cart(th, r_in);
        yg = -yg;
        line([0 xg], [0 yg], ...
             'Color', [0 0 0], 'LineStyle', '-', 'LineWidth', 0.1);
    end

    fig.Color = 'w';
    ax = gca;
    axis equal; axis off;
    ax.Color = ones(1,3) * 0.97;

    fig.PaperType = 'a4'; fig.PaperUnits = 'centimeters';
    fig.Units = 'centimeters'; fig.Color = 'w';
    fig.InvertHardcopy = 'off';
    figSize = twocolumn / 6;
    fig.PaperPosition = [0, 10, figSize, figSize];
    fig.Position = [0, 10, figSize, figSize];
    ax.FontName = 'Helvetica'; ax.FontSize = 5;
    ax.LineWidth = 0.2;
    ax.Units = 'centimeters';
    ax.Position = [-0.65 -0.65 4.3 4.3];
end
