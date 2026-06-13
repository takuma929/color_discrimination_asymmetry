function C = taskonomyClustering(taskonomy_csv, opts)
%TASKONOMYCLUSTERING  Unsupervised clustering of Taskonomy tasks by layer profile.
%   C = taskonomyClustering(TASKONOMY_CSV) builds, for every task in the CSV, a
%   feature vector from its full depth profile
%        [ purple(stem..layer4), orange(stem..layer4) ]  (10 values)
%   where each value is log10(hue sensitivity / chroma sensitivity); standardises
%   the features; runs Ward agglomerative clustering on the Euclidean distances;
%   chooses the number of clusters K by the silhouette criterion; and relabels
%   clusters by size (largest = cluster 1).
%
%   C = taskonomyClustering(TASKONOMY_CSV, OPTS) overrides defaults with the
%   fields of struct OPTS: autoSelectK (default true), kList (default 2:8),
%   fixedK (default 4, used when autoSelectK is false or evalclusters is absent).
%
%   This is the single source of truth shared by figS7_taskonomy.m (scatter) and
%   figS8_taskonomy_24tasks_layer_clustered.m (per-task grid), so both figures
%   use identical cluster assignments and colors.
%
%   Returned struct C has fields:
%     tasks         - string array of task names, in final display order
%     clusterId     - cluster index per task (aligned to C.tasks), 1 = largest
%     K             - number of clusters
%     clusterColors - K-by-3 RGB palette (row k = cluster k)
%     clusterNames  - 1-by-K string array ("Cluster 1", ...)
%     profiles      - struct array (aligned to C.tasks) with per-depth profiles:
%                     fields task, depths, purple, orange, and the per-depth
%                     standard error across iterations purpleSE, orangeSE
%     silhouette    - diagnostic struct (kList, silhouette, chosenK) or empty
%
%   Requires the Statistics and Machine Learning Toolbox (pdist / linkage /
%   cluster / optimalleaforder; evalclusters for silhouette selection).

    if nargin < 2 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts, 'autoSelectK'), opts.autoSelectK = true; end
    if ~isfield(opts, 'kList'),       opts.kList = 2:8;        end
    if ~isfield(opts, 'fixedK'),      opts.fixedK = 4;         end

    % Per-depth purple/orange profiles for every task.
    allTasks = taskonomyAllTasks(taskonomy_csv);
    profiles = taskonomyLayerProfiles(taskonomy_csv, allTasks);

    % Feature matrix: one row per task, [purple(depthOrder), orange(depthOrder)].
    depthOrder = ["stem", "layer1", "layer2", "layer3", "layer4"];
    F = buildFeatureMatrix(profiles, depthOrder);

    % Choose K (silhouette) then cluster.
    if opts.autoSelectK
        [K, sel] = selectNumClusters(F, opts.kList, opts.fixedK);
    else
        K = opts.fixedK;
        sel = struct([]);
        fprintf('Auto-selection disabled; using fixed K = %d.\n', K);
    end
    [clusterId, order] = clusterTasks(F, K);

    % Reorder everything by the clustering result (clusters contiguous).
    profiles  = profiles(order);
    clusterId = clusterId(order);

    % Report cluster membership to the console.
    fprintf('\nUnsupervised clustering of %d Taskonomy tasks into %d clusters:\n', ...
        numel(profiles), K);
    for c = 1:K
        members = arrayfun(@(p) char(p.task), profiles(clusterId == c), 'UniformOutput', false);
        fprintf('  Cluster %d: %s\n', c, strjoin(members, ', '));
    end

    C = struct();
    C.tasks         = arrayfun(@(p) p.task, profiles);
    C.clusterId     = clusterId;
    C.K             = K;
    C.clusterColors = clusterColorPalette(K);
    C.clusterNames  = "Cluster " + string(1:K);
    C.profiles      = profiles;
    C.silhouette    = sel;
end

%% ------------------------- TASKONOMY HELPERS ----------------------------

function tasks = taskonomyAllTasks(taskonomy_csv)
    % All Taskonomy tasks present in the CSV, alphabetical for reproducibility.
    assert(isfile(taskonomy_csv), 'Taskonomy CSV not found: %s', taskonomy_csv);
    N = readtable(taskonomy_csv, 'TextType', 'string');
    N.Properties.VariableNames = matlab.lang.makeValidName(N.Properties.VariableNames);
    tasks = sort(unique(lower(string(N.task))));
    fprintf('Taskonomy tasks loaded for clustering: %d\n', numel(tasks));
end

function P = taskonomyLayerProfiles(taskonomy_csv, selectedTasks)
    % Build a per-depth hue/chroma ratio profile for each selected task: the
    % log10 hue/chroma sensitivity ratio for purple and orange references at
    % every depth (averaged across iterations), kept in stem -> layer4 order.
    assert(isfile(taskonomy_csv), 'Taskonomy CSV not found: %s', taskonomy_csv);

    N = readtable(taskonomy_csv, 'TextType', 'string');
    N.Properties.VariableNames = matlab.lang.makeValidName(N.Properties.VariableNames);
    N.task = lower(string(N.task));
    N.depth = lower(string(N.depth));
    N.refLabel = lower(string(N.quadrant));
    N.dir = lower(string(N.direction));
    N.threshold_mean = N.threshold;

    selectedTasks = lower(string(selectedTasks));
    P = repmat(struct('task', "", 'depths', strings(0, 1), ...
        'purple', [], 'orange', [], 'purpleSE', [], 'orangeSE', []), ...
        numel(selectedTasks), 1);

    epsDen = 1e-12;
    for k = 1:numel(selectedTasks)
        rowsTask = N(N.task == selectedTasks(k), :);
        assert(~isempty(rowsTask), 'Task not found in Taskonomy CSV: %s', selectedTasks(k));
        iters = unique(rowsTask.iter, 'stable');
        depths = localOrderedDepths(unique(rowsTask.depth, 'stable'));

        purpleVals = nan(numel(depths), 1);
        orangeVals = nan(numel(depths), 1);
        purpleSE = nan(numel(depths), 1);
        orangeSE = nan(numel(depths), 1);
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
            purpleVals(d) = mean(xv, 'omitnan');
            orangeVals(d) = mean(yv, 'omitnan');
            % Standard error of the ratio across iterations at this depth.
            purpleSE(d) = localStandardError(xv);
            orangeSE(d) = localStandardError(yv);
        end

        P(k).task = selectedTasks(k);
        P(k).depths = depths;
        P(k).purple = purpleVals;
        P(k).orange = orangeVals;
        P(k).purpleSE = purpleSE;
        P(k).orangeSE = orangeSE;
    end
end

function se = localStandardError(vals)
    % Standard error of a set of values across iterations (NaN if none).
    vals = vals(isfinite(vals));
    if isempty(vals)
        se = NaN;
    else
        se = std(vals, 'omitnan') / sqrt(numel(vals));
    end
end

function F = buildFeatureMatrix(profiles, depthOrder)
    % One row per task: [purple(depthOrder), orange(depthOrder)], with any
    % missing depth left as NaN (filled later before clustering).
    nD = numel(depthOrder);
    F = nan(numel(profiles), 2 * nD);
    for k = 1:numel(profiles)
        Pk = profiles(k);
        pv = nan(1, nD);
        ov = nan(1, nD);
        for i = 1:numel(Pk.depths)
            j = find(depthOrder == Pk.depths(i), 1);
            if ~isempty(j)
                pv(j) = Pk.purple(i);
                ov(j) = Pk.orange(i);
            end
        end
        F(k, :) = [pv, ov];
    end
end

%% ------------------------- CLUSTERING -----------------------------------

function [clusterId, order] = clusterTasks(F, K)
    % Unsupervised agglomerative clustering of tasks by their standardised
    % profile features. Returns a cluster id per task and an ordering that makes
    % clusters contiguous with dendrogram-consistent ordering within each.
    assert(exist('linkage', 'file') == 2, ...
        'Statistics and Machine Learning Toolbox is required (linkage/cluster).');

    Z = standardizeFeatures(F);
    D = pdist(Z, 'euclidean');
    L = linkage(D, 'ward');
    rawId = cluster(L, 'maxclust', K);

    % Dendrogram leaf order (optimal), used only to break cluster-size ties.
    leafOrder = optimalleaforder(L, D);

    % Relabel clusters by size in descending order: the largest cluster becomes
    % cluster 1, the next largest cluster 2, etc. Ties are broken by first
    % appearance along the dendrogram leaf order for determinism.
    uids = unique(rawId);
    counts = arrayfun(@(u) sum(rawId == u), uids);
    firstLeaf = arrayfun(@(u) find(rawId(leafOrder) == u, 1), uids);
    [~, sortIdx] = sortrows([-counts(:), firstLeaf(:)], [1 2]);
    orderedRaw = uids(sortIdx);
    remap = zeros(max(rawId), 1);
    remap(orderedRaw) = 1:numel(orderedRaw);
    clusterId = remap(rawId);

    % Within-cluster ordering: distance from each task to its cluster centroid in
    % the standardised feature space, ascending (closest to the centroid first).
    centroidDist = zeros(numel(clusterId), 1);
    for c = unique(clusterId)'
        inC = clusterId == c;
        centroid = mean(Z(inC, :), 1);
        centroidDist(inC) = sqrt(sum((Z(inC, :) - centroid).^2, 2));
    end

    % Clusters contiguous (largest first), most-central task first within each.
    [~, order] = sortrows([clusterId, centroidDist], [1 2]);
end

function Z = standardizeFeatures(F)
    % Z-score the feature columns; fill non-finite entries with the column mean
    % (0 after z-scoring) so distances are always well defined.
    mu = mean(F, 1, 'omitnan');
    sigma = std(F, 0, 1, 'omitnan');
    sigma(sigma == 0 | ~isfinite(sigma)) = 1;
    Z = (F - mu) ./ sigma;
    Z(~isfinite(Z)) = 0;
end

function idx = wardClusterFun(X, K)
    % Clustering function passed to evalclusters so the criterion is evaluated on
    % EXACTLY the same Ward-linkage clustering used to build the figures.
    D = pdist(X, 'euclidean');
    L = linkage(D, 'ward');
    idx = cluster(L, 'maxclust', K);
end

function [chosenK, sel] = selectNumClusters(F, kList, fallbackK)
    % Pick the number of clusters by the silhouette criterion over kList, using
    % the same standardisation and Ward linkage as the final clustering. Falls
    % back to fallbackK (and returns an empty sel) if evalclusters is unavailable
    % or returns no valid optimum.
    sel = struct([]);
    if exist('evalclusters', 'file') ~= 2
        warning(['evalclusters not found (Statistics Toolbox); ', ...
            'falling back to fixed K = %d.'], fallbackK);
        chosenK = fallbackK;
        return
    end

    Z = standardizeFeatures(F);
    kList = kList(:)';
    kList = kList(kList >= 2 & kList < size(Z, 1));   % silhouette needs 2..n-1

    evaSil = evalclusters(Z, @wardClusterFun, 'silhouette', 'KList', kList);
    silVals = evaSil.CriterionValues(:)';

    chosenK = evaSil.OptimalK;
    if isempty(chosenK) || ~isfinite(chosenK) || chosenK < 2
        warning('Silhouette returned no valid K; falling back to fixed K = %d.', fallbackK);
        chosenK = fallbackK;
    end

    % Console report of the per-K silhouette scores.
    fprintf('\nData-driven cluster-number selection (silhouette, Ward linkage):\n');
    fprintf('   K  silhouette\n');
    for i = 1:numel(kList)
        fprintf('  %2d  %10.4f\n', kList(i), silVals(i));
    end
    fprintf('  -> silhouette-optimal K = %d\n', chosenK);

    sel = struct('kList', kList, 'silhouette', silVals, 'chosenK', chosenK);
end

function colors = clusterColorPalette(n)
    % A harmonious, muted-jewel/earth-tone palette: tasteful and mutually
    % distinct, dark enough to read as bold title text, and kept clear of the
    % bright purple/orange data-line colors.
    palette = [ ...
        0.169 0.365 0.549;   % deep blue
        0.180 0.545 0.498;   % teal
        0.690 0.541 0.180;   % muted gold
        0.659 0.325 0.431;   % dusty rose
        0.357 0.357 0.627;   % slate indigo
        0.549 0.384 0.224;   % warm brown
        0.247 0.247 0.306;   % charcoal
        0.133 0.471 0.286];  % forest green
    idx = mod((0:n-1), size(palette, 1)) + 1;
    colors = palette(idx, :);
end

%% ------------------------- LOW-LEVEL HELPERS ----------------------------

function depths = localOrderedDepths(depths)
    dmid = setdiff(depths, ["stem","fc"], 'stable');
    if any(depths == "stem"), dmid = ["stem"; dmid]; end
    if any(depths == "fc"), dmid = [dmid; "fc"]; end
    depths = dmid;
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
