%% figS9_network_layers.m
% Supplementary layer-wise hue/chroma ratio analysis for all networks.
%
% The figure shows how log10 hue/chroma sensitivity changes across network
% depth, separately for purple and orange reference chromaticities and grouped
% by model family. Paths are resolved relative to this script so the code is
% operating-system independent.

clear; clc; close all

%% ------------------------- PATHS AND OPTIONS ----------------------------

% Resolve paths relative to this script rather than the MATLAB current folder.
scriptFile = mfilename('fullpath');
scriptDir = fileparts(scriptFile);
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'utils'));

% Networks included in the supplementary layer analysis. The COCO-from-scratch
% detection/keypoint networks get their own panel pair.
allNetworks = {'resnet50','resnet18', ...
               'places365_resnet50','places365_resnet18', ...
               'resnet50_flips', ...
               'fasterrcnn_resnet50_fpn_coco_scratch', ...
               'keypointrcnn_resnet50_fpn_coco_scratch'};

% Output folder and plotting options.
outdir = fullfile(scriptDir, 'figs');
doSave = true;
twocolumn = 17.8;
human_csv = fullfile(scriptDir, 'data', 'human', 'human_thresholds.csv');
networkMarkerArea = 50;

if doSave && ~exist(outdir, 'dir')
    mkdir(outdir);
end

%% ------------------------- LOAD LAYER DATA ------------------------------

% Human band used as a reference in each layer panel.
layerData = struct();
allPurple = [];
allOrange = [];
[humanStats, ~, ~] = localHumanHSI(human_csv);

% Load each network's threshold table and compute one purple/orange ratio for
% every available depth.
for k = 1:numel(allNetworks)
    network = allNetworks{k};
    network_csv = fullfile(scriptDir, 'data', 'network', [network, '_thresholds.csv']);
    assert(isfile(network_csv), 'Network CSV not found: %s', network_csv);

    N = readtable(network_csv, 'TextType', 'string');
    N.Properties.VariableNames = matlab.lang.makeValidName(N.Properties.VariableNames);
    if ~ismember('threshold_se', N.Properties.VariableNames)
        N.threshold_se = nan(height(N), 1);
    end
    if ~ismember('n_measured', N.Properties.VariableNames)
        N.n_measured = nan(height(N), 1);
    end
    N.depth = lower(string(N.depth));
    N.refLabel = lower(string(N.quadrant));
    N.axis = lower(string(N.hue_chroma));
    N.sign = lower(string(N.direction));

    depths = localOrderedDepths(unique(N.depth, 'stable'));
    purpleVals = nan(numel(depths), 1);
    orangeVals = nan(numel(depths), 1);
    purpleSD = nan(numel(depths), 1);
    orangeSD = nan(numel(depths), 1);

    for d = 1:numel(depths)
        rows = N(N.depth == depths(d), :);
        S = localNetworkThresholdStruct(rows);
        [purpleVals(d), orangeVals(d), purpleSD(d), orangeSD(d)] = localLayerRatios(S);
    end

    [~, netColor] = localNetTypeAndColor(network);
    layerData.(network).depths = depths;
    layerData.(network).purple = purpleVals;
    layerData.(network).orange = orangeVals;
    layerData.(network).purpleSD = purpleSD;
    layerData.(network).orangeSD = orangeSD;
    layerData.(network).color = netColor;

    allPurple = [allPurple; purpleVals(:)]; %#ok<AGROW>
    allOrange = [allOrange; orangeVals(:)]; %#ok<AGROW>
end

%% ------------------------- STATS AND EXPORT -----------------------------

localPrintOrangeLayerStats(layerData, allNetworks);

groupImageNet = {'resnet50','resnet18','resnet50_flips'};
groupPlaces = {'places365_resnet50','places365_resnet18'};
groupCoco = {'fasterrcnn_resnet50_fpn_coco_scratch','keypointrcnn_resnet50_fpn_coco_scratch'};

localExportIndividualPanels(layerData, outdir, twocolumn, allPurple, allOrange, humanStats, ...
    networkMarkerArea, groupImageNet, groupPlaces, groupCoco, doSave);

function depths = localOrderedDepths(depths)
    % Put network depths in anatomical/architectural order when present.
    depthOrder = ["layer_1","block_1","block_2","block_3","block_4","final_layer"];
    depths = string(depths(:));
    ordered = strings(0,1);
    for i = 1:numel(depthOrder)
        if any(depths == depthOrder(i))
            ordered(end+1,1) = depthOrder(i); %#ok<AGROW>
        end
    end
    extra = setdiff(depths, ordered, 'stable');
    depths = [ordered; extra];
end

function Sdepth = localNetworkThresholdStruct(Nrows)
    % Convert threshold rows for one network depth into a nested struct.
    refs = unique(Nrows.refLabel);
    Sdepth = struct();
    for i = 1:numel(refs)
        r = refs(i);
        R = Nrows(Nrows.refLabel == r, :);
        Sdepth.(r).chroma.pos = localGetDirStats(R, "chroma", "pos");
        Sdepth.(r).chroma.neg = localGetDirStats(R, "chroma", "neg");
        Sdepth.(r).hue.pos    = localGetDirStats(R, "hue", "pos");
        Sdepth.(r).hue.neg    = localGetDirStats(R, "hue", "neg");
    end
end

function st = localGetDirStats(T, axisName, signName)
    % Extract mean threshold and recover SD from SE for one hue/chroma axis and sign.
    idx = T.axis == axisName & T.sign == signName;
    st.mean = mean(T.threshold_mean(idx), 'omitnan');
    se = mean(T.threshold_se(idx), 'omitnan');
    n = mean(T.n_measured(idx), 'omitnan');
    if isfinite(se) && isfinite(n) && n > 0
        st.sd = se * sqrt(n);
    else
        st.sd = NaN;
    end
end

function [purpleRatio, orangeRatio, purpleSD, orangeSD] = localLayerRatios(S)
    % Convert thresholds to log10 hue/chroma sensitivity ratios for purple and
    % orange reference chromaticities.
    epsDen = 1e-12;
    mp = localMeanOfTwoStats(S.purple.chroma.pos, S.purple.chroma.neg);
    hp = localMeanOfTwoStats(S.purple.hue.pos, S.purple.hue.neg);
    mo = localMeanOfTwoStats(S.orange.chroma.pos, S.orange.chroma.neg);
    ho = localMeanOfTwoStats(S.orange.hue.pos, S.orange.hue.neg);

    purpleHueSensitivity = 1 / max(hp.mean, epsDen);
    purpleChromaSensitivity = 1 / max(mp.mean, epsDen);
    orangeHueSensitivity = 1 / max(ho.mean, epsDen);
    orangeChromaSensitivity = 1 / max(mo.mean, epsDen);

    purpleRatio = log10(purpleHueSensitivity / max(purpleChromaSensitivity, epsDen));
    orangeRatio = log10(orangeHueSensitivity / max(orangeChromaSensitivity, epsDen));
    purpleSD = localLogRatioSD(mp, hp, epsDen);
    orangeSD = localLogRatioSD(mo, ho, epsDen);
end

function out = localMeanOfTwoStats(a, b)
    % Mean positive/negative directions and combine their SDs for the averaged threshold.
    out.mean = mean([a.mean, b.mean], 'omitnan');
    sdVals = [a.sd, b.sd];
    sdVals = sdVals(isfinite(sdVals));
    if isempty(sdVals)
        out.sd = NaN;
    else
        out.sd = sqrt(sum(sdVals.^2)) / numel(sdVals);
    end
end

function sdLogRatio = localLogRatioSD(chroma, hue, epsDen)
    % Delta-method SD for log10(chroma threshold / hue threshold).
    if chroma.mean <= epsDen || hue.mean <= epsDen || ~isfinite(chroma.sd) || ~isfinite(hue.sd)
        sdLogRatio = NaN;
        return
    end
    sdLogRatio = sqrt((chroma.sd / chroma.mean)^2 + (hue.sd / hue.mean)^2) / log(10);
end

function localExportIndividualPanels(layerData, outdir, twocolumn, allPurple, allOrange, humanStats, ...
    networkMarkerArea, groupImageNet, groupPlaces, groupCoco, doSave)
    % Export six separate panels: purple/orange crossed with model family
    % (ImageNet, Places365, COCO).
    panelWidth = twocolumn / 3;
    specs = {
        'purple', 'ImageNet', groupImageNet, 'figS9a_dnn_layer_ratio_purple_imagenet.pdf';
        'purple', 'Places365', groupPlaces, 'figS9b_dnn_layer_ratio_purple_places365.pdf';
        'purple', 'COCO', groupCoco, 'figS9c_dnn_layer_ratio_purple_coco.pdf';
        'orange', 'ImageNet', groupImageNet, 'figS9d_dnn_layer_ratio_orange_imagenet.pdf';
        'orange', 'Places365', groupPlaces, 'figS9e_dnn_layer_ratio_orange_places365.pdf';
        'orange', 'COCO', groupCoco, 'figS9f_dnn_layer_ratio_orange_coco.pdf'
    };

    for i = 1:size(specs, 1)
        refName = specs{i,1};
        familyTitle = specs{i,2};
        networks = specs{i,3};
        outname = specs{i,4};

        fig = figure('Color', 'w');
        ax = axes(fig);
        localPlotLayerLines(ax, layerData, networks, allPurple, allOrange, humanStats, ...
            networkMarkerArea, refName, familyTitle);

        fig.PaperType = 'a4';
        fig.PaperUnits = 'centimeters';
        fig.Units = 'centimeters';
        fig.InvertHardcopy = 'off';
        fig.PaperPosition = [0, 10, panelWidth, panelWidth];
        fig.Position = [10, 10, panelWidth, panelWidth];
        ax.Units = 'centimeters';
        ax.Position = [1.0 0.8 panelWidth-1.3 panelWidth-1.3];

        if doSave
            pause(0.5)
            exportgraphics(fig, fullfile(outdir, outname), ...
                'ContentType', 'vector', 'BackgroundColor', 'none');
            fprintf('%s successfully saved.\n', outname);
        end
        close(fig)
    end
end

function localPlotLayerLines(ax, layerData, networks, allPurple, allOrange, humanStats, networkMarkerArea, refName, familyTitle)
    % Plot one layer-wise family panel for a single reference color. For the COCO
    % panel the two tasks are distinguished by solid/dashed line style.
    depthOrder = ["layer_1","block_1","block_2","block_3","block_4","final_layer"];
    depthLabels = {'L_1','B_1','B_2','B_3','B_4','L_f'};
    [networkLow, networkHigh] = localAllNetworkErrorLimits(layerData);
    yMin = floor(100 * min([allPurple; allOrange; networkLow], [], 'omitnan')) / 100 - 0.02;
    yMax = ceil(100 * max([allPurple; allOrange; networkHigh], [], 'omitnan')) / 100 + 0.02;
    titleColors.purple = [0.80 0.20 0.90];
    titleColors.orange = [0.85 0.33 0.10];
    xOffset = linspace(-0.07, 0.07, numel(networks));
    hold(ax, 'on');

    if strcmp(refName, 'purple')
        mu = humanStats.purple.mean;
        sd = humanStats.purple.sd;
        bandColor = [0.80 0.20 0.90];
    else
        mu = humanStats.orange.mean;
        sd = humanStats.orange.sd;
        bandColor = [0.85 0.33 0.10];
    end
    patch(ax, [0.7 numel(depthOrder)+0.55 numel(depthOrder)+0.55 0.7], ...
        [mu-sd mu-sd mu+sd mu+sd], bandColor, ...
        'EdgeColor', 'none', 'FaceAlpha', 0.10, 'HandleVisibility', 'off');
    line(ax, [0.7 numel(depthOrder)+0.55], [mu mu], ...
        'Color', bandColor, 'LineStyle', ':', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    line(ax, [0.7 numel(depthOrder)+0.55], [0 0], ...
        'Color', [0.65 0.65 0.65], 'LineStyle', '-', 'LineWidth', 0.5, 'HandleVisibility', 'off');

    for k = 1:numel(networks)
        network = networks{k};
        D = layerData.(network);
        vals = D.(refName);
        valsSD = D.([refName 'SD']);
        x = nan(size(vals));
        for i = 1:numel(D.depths)
            x(i) = find(depthOrder == D.depths(i), 1, 'first');
        end
        valid = isfinite(x) & isfinite(vals);
        xPlot = x + xOffset(k);

        if ~any(valid)
            continue
        end

        [mk, markerSize] = localNetworkMarkerStyle(network, networkMarkerArea);
        lineStyle = localNetworkLineStyle(network);

        plot(ax, xPlot(valid), vals(valid), lineStyle, ...
            'Color', D.color, 'LineWidth', 0.5, ...
            'HandleVisibility', 'off');

        errValid = valid & isfinite(valsSD) & valsSD >= 0;
        errorbar(ax, xPlot(errValid), vals(errValid), valsSD(errValid), valsSD(errValid), ...
            'Color', D.color, ...
            'LineStyle', 'none', ...
            'LineWidth', 0.5, ...
            'CapSize', 0, ...
            'HandleVisibility', 'off');
        scatter(ax, xPlot(valid), vals(valid), markerSize, ...
            'Marker', mk, ...
            'MarkerFaceColor', D.color, ...
            'MarkerEdgeColor', 'w', ...
            'LineWidth', 0.7, ...
            'HandleVisibility', 'off');

        lastIdx = find(valid, 1, 'last');
        %text(ax, xPlot(lastIdx) + 0.08, vals(lastIdx), localShortName(network), ...
        %    'Color', D.color, 'FontSize', 6, 'Clipping', 'on');
    end

    ax.XTick = 1:numel(depthOrder);
    ax.XTickLabel = depthLabels;
    ax.XLim = [0.7 numel(depthOrder)+0.55];
    ax.FontName = 'Arial';
    ax.FontSize = 7;
    ax.LineWidth = 0.5;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.Color = [0.97 0.97 0.97];
    ax.YLim = [yMin yMax];
    ax.YTick = [yMin 0 yMax];
    ax.YTickLabel = char(sprintf('%.1f', yMin), '0.0', sprintf('%.1f', yMax));
    ax.XGrid = 'off';
    ax.YGrid = 'off';
    ax.XMinorGrid = 'off';
    ax.YMinorGrid = 'off';
    box(ax, 'on');
    xlabel(ax, 'Depth', 'FontWeight', 'bold');
    ylabel(ax, sprintf('log_1_0 hue / chroma sensitivity (%s)', refName), 'FontWeight', 'bold');
end

function [networkLow, networkHigh] = localAllNetworkErrorLimits(layerData)
    % Collect network ratio +/- 1 SD ranges so axes include the new error bars.
    nets = fieldnames(layerData);
    networkLow = [];
    networkHigh = [];
    for i = 1:numel(nets)
        D = layerData.(nets{i});
        for refName = ["purple", "orange"]
            refField = char(refName);
            vals = D.(refField);
            valsSD = D.([refField 'SD']);
            ok = isfinite(vals) & isfinite(valsSD);
            networkLow = [networkLow; vals(ok) - valsSD(ok)]; %#ok<AGROW>
            networkHigh = [networkHigh; vals(ok) + valsSD(ok)]; %#ok<AGROW>
        end
    end
end

function [stats, xHuman, yHuman] = localHumanHSI(human_csv)
    % Compute human log10 hue/chroma sensitivity ratios for the reference band.
    assert(isfile(human_csv), 'Human CSV not found: %s', human_csv);
    T = readtable(human_csv, 'TextType','string');
    T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);
    if ismember('orange_hue_focused', T.Properties.VariableNames)
        T = T(T.orange_hue_focused==1, :);
    end
    T.ptID = string(T.ptID);
    T.axis = lower(string(T.hue_chroma));
    T.refLabel = lower(string(T.quadrant));

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
    stats.purple.mean = mean(xHuman, 'omitnan');
    stats.purple.sd = std(xHuman, 'omitnan');
    stats.orange.mean = mean(yHuman, 'omitnan');
    stats.orange.sd = std(yHuman, 'omitnan');
end

function [typeStr, col] = localNetTypeAndColor(netname)
    if contains(netname, "coco_scratch")
        % COCO-from-scratch ResNet50 models share one grey color (matching
        % fig8); the detection/keypoint tasks are distinguished by line style.
        if contains(netname, "keypointrcnn")
            typeStr = 'Keypoint (COCO scratch)';
        else
            typeStr = 'Detection (COCO scratch)';
        end
        col = [0.62 0.62 0.62];
    elseif startsWith(netname, "places365")
        typeStr = 'Places classifier';
        col = [255 127 2] / 255 * 0.9;
    elseif contains(netname, "fasterrcnn")
        typeStr = 'Detection';
        col = [27 152 81] / 255;
    elseif contains(netname, "keypointrcnn")
        typeStr = 'Keypoint';
        col = [68 118 181] / 255;
    elseif contains(netname, "flips")
        typeStr = 'ImageNet classifier flips';
        col = [128 51 153] / 255;
    else
        typeStr = 'ImageNet classifier';
        col = [216 47 39] / 255;
    end
end

function out = upperFirst(str)
    str = char(string(str));
    out = [upper(str(1)) str(2:end)];
end

function out = localShortName(name)
    switch char(string(name))
        case 'resnet50'
            out = 'res50 obj';
        case 'resnet18'
            out = 'res18 obj';
        case 'places365_resnet50'
            out = 'res50 scene';
        case 'places365_resnet18'
            out = 'res18 scene';
        case 'fasterrcnn_resnet50_fpn'
            out = 'res50 detect';
        case 'keypointrcnn_resnet50_fpn'
            out = 'res50 pose';
        case 'fasterrcnn_resnet50_fpn_coco_scratch'
            out = 'res50 detect (scratch)';
        case 'keypointrcnn_resnet50_fpn_coco_scratch'
            out = 'res50 pose (scratch)';
        case 'resnet50_flips'
            out = 'res50 S-flip';
        otherwise
            out = char(string(name));
    end
end

function localPrintOrangeLayerStats(layerData, allNetworks)
    excludeNetworks = {'resnet50_flips'};
    validNetworks = allNetworks(~ismember(allNetworks, excludeNetworks));
    sceneNetworks = validNetworks(contains(validNetworks, 'places365'));
    otherNetworks = setdiff(validNetworks, sceneNetworks, 'stable');

    localPrintOneGroupOrangeLayerStats(layerData, sceneNetworks, 'Places365-trained networks');
    localPrintOneGroupOrangeLayerStats(layerData, otherNetworks, 'Object-level networks');
end

function localPrintOneGroupOrangeLayerStats(layerData, validNetworks, groupLabel)
    twoBinRows = {};

    for k = 1:numel(validNetworks)
        network = validNetworks{k};
        D = layerData.(network);
        valid = isfinite(D.orange);
        depths = D.depths(valid);
        orangeVals = D.orange(valid);

        if numel(orangeVals) < 2
            continue
        end

        earlyMask = ismember(depths, ["layer_1","block_1","block_2","block_3"]);
        lateMask = ~earlyMask;
        if any(earlyMask) && any(lateMask)
            twoBinRows(end+1,:) = {network, ...
                mean(orangeVals(earlyMask), 'omitnan'), ...
                mean(orangeVals(lateMask), 'omitnan')}; %#ok<AGROW>
        end
    end

    if isempty(twoBinRows)
        return
    end

    earlyVals = cell2mat(twoBinRows(:,2));
    lateVals = cell2mat(twoBinRows(:,3));
    fprintf('\n%s (orange ratio, layer 1 + blocks 1-3 vs deeper layers):\n', groupLabel);
    localPrintPairedStats(earlyVals, lateVals, 'Layer 1 + blocks 1-3', 'Deeper layers');
end

function localPrintPairedStats(aVals, bVals, labelA, labelB)
    valid = isfinite(aVals) & isfinite(bVals);
    aVals = aVals(valid);
    bVals = bVals(valid);
    diffs = aVals - bVals;
    n = numel(diffs);
    meanA = mean(aVals, 'omitnan');
    meanB = mean(bVals, 'omitnan');
    sdA = std(aVals, 'omitnan');
    sdB = std(bVals, 'omitnan');
    meanDiff = mean(diffs, 'omitnan');
    sdDiff = std(diffs, 'omitnan');

    if n > 1 && sdDiff > 0
        semDiff = sdDiff / sqrt(n);
        df = n - 1;
        tStat = meanDiff / semDiff;
        % Two-tailed paired t-test.
        pVal = 2 * (1 - tcdf(abs(tStat), df));
        tCrit = tinv(0.975, df);
        ci = meanDiff + [-1 1] * tCrit * semDiff;
    else
        df = NaN;
        tStat = NaN;
        pVal = NaN;
        ci = [NaN NaN];
    end

    fprintf('\n%s vs %s\n', labelA, labelB);
    fprintf('%s: M = %.4f, SD = %.4f, N = %d\n', labelA, meanA, sdA, n);
    fprintf('%s: M = %.4f, SD = %.4f, N = %d\n', labelB, meanB, sdB, n);
    fprintf('Paired t-test, two-tailed (%s - %s): mean diff = %.4f, 95%% CI [%.4f, %.4f], t(%d) = %.4f, p = %.4g\n', ...
        labelA, labelB, meanDiff, ci(1), ci(2), df, tStat, pVal);
end

function [markerShape, markerArea] = localNetworkMarkerStyle(network, baseMarkerArea)
    if contains(network, 'resnet50')
        markerShape = 'd';
        markerArea = baseMarkerArea;
    elseif contains(network, 'resnet18')
        markerShape = 's';
        markerArea = baseMarkerArea * 1.4;
    else
        markerShape = '^';
        markerArea = baseMarkerArea;
    end
end

function lineStyle = localNetworkLineStyle(network)
    % COCO-from-scratch nets share one grey color, so distinguish the tasks by
    % line style: solid for detection, dashed for keypoint. All other networks
    % use a solid line as before.
    if contains(network, "coco_scratch") && contains(network, "keypointrcnn")
        lineStyle = '--';
    else
        lineStyle = '-';
    end
end
