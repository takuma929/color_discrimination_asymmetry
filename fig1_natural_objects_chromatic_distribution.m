%% fig1_natural_objects_chromatic_distribution.m
% Plot DKL chromatic distributions for all object datasets stored in
% object_pixels.mat. Each sampled point is colored by the corresponding RGB
% value so that the scatter plot preserves the approximate object colors.
%
% The script is written to be operating-system independent:
%   - paths are built with fullfile rather than hard-coded separators;
%   - input and output folders are resolved relative to this script, not the
%     current MATLAB working directory;
%   - output folders are created only when needed.

clear; clc; close all

% Fix the random seed so the same subset of points is plotted each time.
rng(1);

% Resolve the repository/script location from this file. This lets the script
% run correctly from any MATLAB current folder and on macOS, Windows, or Linux.
scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    % mfilename can be empty if code is pasted into the command window. In
    % that fallback case, use the current folder as the project root.
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

% Input data and output figures live under the script directory.
dataFile = fullfile(scriptDir, 'data', 'object_pixels.mat');
outdir = fullfile(scriptDir, 'figs');

% Set doSave to false for interactive inspection without writing files.
doSave = true;

% Two-column figure width in centimeters. The final figure uses 75% of this.
twocolumn = 17.8;

% Limit the number of plotted pixels per fruit/object. This keeps the SVG size
% manageable while preserving the overall chromatic distribution.
sampleCountPerFruit = 5000;

% Load and validate the expected MATLAB variable before plotting.
assert(isfile(dataFile), 'Data file not found: %s', dataFile);
S = load(dataFile, 'fruitData');
assert(isfield(S, 'fruitData'), 'fruitData variable not found in %s', dataFile);

fruitData = S.fruitData;
assert(isstruct(fruitData), 'fruitData must be a struct array.');

% Create the output directory only when saving is enabled.
if doSave && ~exist(outdir, 'dir')
    mkdir(outdir);
end
iconOutDir = fullfile(outdir, 'fig1_fruit_icons');
if doSave && ~exist(iconOutDir, 'dir')
    mkdir(iconOutDir);
end

% Common DKL axis limits for all datasets. These fixed limits make the
% plotted distributions comparable across runs and figures.
xlimVals = [-0.1 0.5];
ylimVals = [-0.6 0.1];

% Build a single axes object explicitly so all plotting and styling calls target
% the intended figure, independent of whatever figures may already be open.
fig = figure('Color', 'w');
ax = axes(fig);
hold(ax, 'on');

for iFruit = 1:numel(fruitData)
    % Use only the chromatic DKL dimensions. The first DKL column is luminance,
    % which is not shown in this two-dimensional figure.
    DKL = double(fruitData(iFruit).DKL(:,2:3));

    % Normalize RGB values to MATLAB's expected [0, 1] range and apply the same
    % display transform used by the original script.
    RGB = localNormalizeRGB(fruitData(iFruit).RGBuncorr);

    % Randomly sample a bounded number of points from each fruit/object to keep
    % all datasets similarly represented in the final plot.
    nPts = size(DKL, 1);
    nKeep = min(nPts, sampleCountPerFruit);
    keepIdx = randperm(nPts, nKeep);

    % Draw sampled DKL chromatic points, using the original RGB value as the point color.
    scatter(ax, DKL(keepIdx,1), DKL(keepIdx,2), 15, RGB(keepIdx,:), 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.2, 'MarkerFaceAlpha', 0.95);
end

% Label and style the chromatic axes after all points have been plotted.
xlabel(ax, 'L-M', 'FontWeight', 'bold');
ylabel(ax, 'S-(L+M)', 'FontWeight', 'bold');
localStyleAxes(ax, xlimVals, ylimVals);

% Position the axes in physical units so exported figures have predictable
% dimensions regardless of screen resolution or operating system.
ax.Units = 'centimeters';
ax.Position = [0.2 0.8 12.2 12.2];

% Configure paper and on-screen figure dimensions for consistent export.
fig.PaperType = 'a4';
fig.PaperUnits = 'centimeters';
fig.Units = 'centimeters';
fig.InvertHardcopy = 'off';
figWidth = twocolumn * 0.75;
figHeight = figWidth;
fig.PaperPosition = [0, 10, figWidth, figHeight];
fig.Position = [10, 10, figWidth, figHeight];

if doSave
    % Give MATLAB a brief moment to finish drawing before export. This is useful
    % for some graphics backends when scripts are run non-interactively.
    pause(0.1)

    % Save both vector and high-resolution raster versions of the scatter plot.
    figBaseName = 'fig1_objects_chromatic_distributions';
    exportgraphics(fig, fullfile(outdir, [figBaseName '.pdf']), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');
    exportgraphics(fig, fullfile(outdir, [figBaseName '.png']), ...
        'ContentType', 'image', 'BackgroundColor', 'none', 'Resolution', 600);
    fprintf('%s successfully saved.\n', [figBaseName '.pdf']);
    fprintf('%s successfully saved.\n', [figBaseName '.png']);

    % Save the object icons as individual PNG files for figure assembly.
    for iFruit = 1:numel(fruitData)
        if isfield(fruitData, 'icon') && ~isempty(fruitData(iFruit).icon)
            iconName = localSafeFilename(fruitData(iFruit).name);
            [iconRGB, iconAlpha] = localPrepareIconForPng(fruitData(iFruit).icon);
            if isempty(iconAlpha)
                imwrite(iconRGB, fullfile(iconOutDir, [iconName '.png']));
            else
                imwrite(iconRGB, fullfile(iconOutDir, [iconName '.png']), 'Alpha', iconAlpha);
            end
        end
    end
end

function RGB = localNormalizeRGB(RGB)
    % Convert numeric image/color data to double precision for safe arithmetic.
    RGB = double(RGB);

    % Accept either uint8-style [0, 255] values or MATLAB-style [0, 1] values.
    if max(RGB(:)) > 1
        RGB = RGB ./ 255;
    end

    % Clamp values to the valid display interval before applying the transform.
    RGB = min(max(RGB, 0), 1);

    % Brighten low RGB values for visibility in dense scatter plots. This keeps
    % the color identity while making dark object pixels easier to see.
    RGB = RGB .^ (1/4);
end


function [iconRGB, iconAlpha] = localPrepareIconForPng(icon)
    % Convert icon data to RGB and crop to the alpha/mask channel when present.
    icon = double(icon);
    if max(icon(:)) > 1
        icon = icon ./ 255;
    end
    icon = min(max(icon, 0), 1);

    iconAlpha = [];
    if ndims(icon) == 3 && size(icon, 3) >= 4
        iconAlpha = icon(:,:,4);
        mask = iconAlpha > 0;
        if any(mask(:))
            [rowIdx, colIdx] = find(mask);
            rowRange = min(rowIdx):max(rowIdx);
            colRange = min(colIdx):max(colIdx);
            icon = icon(rowRange, colRange, :);
            iconAlpha = iconAlpha(rowRange, colRange);
        end
    end

    iconRGB = icon(:,:,1:min(3, size(icon, 3)));
    if size(iconRGB, 3) == 1
        iconRGB = repmat(iconRGB, 1, 1, 3);
    end
end

function fileName = localSafeFilename(name)
    % Make object names safe for cross-platform filenames.
    fileName = char(string(name));
    fileName = regexprep(fileName, '\s+', '_');
    fileName = regexprep(fileName, '[^A-Za-z0-9_-]', '');
    if isempty(fileName)
        fileName = 'fruit_icon';
    end
end

function localStyleAxes(ax, xlimVals, ylimVals)
    % Add dotted zero-reference lines. These mark the neutral chromatic axes in
    % DKL space.
    line(ax, [0 0], ylimVals, 'LineStyle', ':', 'Color', 'k', 'LineWidth', 0.8);
    line(ax, xlimVals, [0 0], 'LineStyle', ':', 'Color', 'k', 'LineWidth', 0.8);

    % Equal scaling prevents geometric distortion of chromatic distances.
    axis(ax, 'equal');
    ax.XLim = xlimVals;
    ax.YLim = ylimVals;
    ax.XTick = xlimVals(1):0.1:xlimVals(2);
    ax.YTick = ylimVals(1):0.1:ylimVals(2);
    ax.XTickLabel = arrayfun(@(x) sprintf('%.2f', x), ax.XTick, 'UniformOutput', false);
    ax.YTickLabel = arrayfun(@(y) sprintf('%.2f', y), ax.YTick, 'UniformOutput', false);

    % Use a common sans-serif font. If Arial is unavailable on a system, MATLAB
    % will substitute an available compatible font.
    ax.FontName = 'Arial';
    ax.FontSize = 7;
    ax.LineWidth = 0.5;
    ax.XColor = 'k';
    ax.YColor = 'k';

    % Use a light gray axes background to keep colored points visible.
    ax.Color = [0.97 0.97 0.97];
    box(ax, 'on');
    grid(ax, 'minor');
end
