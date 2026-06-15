# Color discrimination asymmetry: figure generation and data

This repository contains the source code and aggregated data required to
reproduce all main and supplementary figures for the manuscript on asymmetries
in colour discrimination, which links the chromatic statistics of natural
scenes, human psychophysical thresholds, MEG decoding, and deep neural network
models.

Each script in the repository root regenerates one figure from the aggregated
data in [`data/`](data/) and writes its output (PDF/PNG) into [`figs/`](figs/).

---

## 1. System requirements

* **Operating system:** Windows, macOS, or Linux (tested on macOS 15.3).
* **MATLAB:** R2020a or newer (the scripts use `exportgraphics`, introduced in
  R2020a; tested on R2025b).
* **Required MATLAB toolbox:**
  * Statistics and Machine Learning Toolbox — used for `ttest`, `corr`,
    `tinv`/`tcdf`, `groupsummary`, and `unstack`.

No other toolboxes are required, and **no third-party code needs to be
downloaded** — every helper function is bundled in [`utils/`](utils/). The DKL
colour-space conversion utilities (`fromDKL`, `toDKL`, `initmon`) are included
there as well.

---

## 2. Installation

Clone or download the repository:

```
git clone <repository-url>
```

No build or installation step is required. Every script resolves all paths
relative to its own location (via `mfilename`) and adds [`utils/`](utils/) to
the path automatically, so the code uses only relative paths and can be run from
any working directory.

Typical run time for the full set of figures is a few minutes on a standard
computer.

---

## 3. Demo: regenerate all figures

Open MATLAB in the **parent directory that contains this repository folder**,
add the repository to the path, and run:

```matlab
addpath('color_discrimination_asymmetry');   % the repository folder
run_all
```

This executes every figure script in order and writes all PDF/PNG outputs into
[`figs/`](figs/). The Command Window reports, for each figure, the statistics
quoted in the manuscript and a `… successfully saved.` line per output file.

To regenerate a single figure, run its script by name, e.g.:

```matlab
fig1_natural_objects_chromatic_distribution
```

---

## 4. Figure scripts

Main figures:

| Script | Figure | Content |
| --- | --- | --- |
| `fig1_natural_objects_chromatic_distribution.m` | 1 | DKL chromatic distribution of natural-object pixels |
| `fig2_hue_histogram.m` | 2 | Hue histograms across image datasets and orange/purple quadrant proportions |
| `fig3_human_thresholds.m` | 3 | Human hue/chroma discrimination thresholds |
| `fig5_decoding_acc.m` | 5 | MEG decoding-accuracy time courses |
| `fig6_human_meg.m` | 6 | Psychophysical hue superiority versus MEG decoding |
| `fig7_network_thresholds.m` | 7 | Neural-network discrimination thresholds |
| `fig8_human_network.m` | 8 | Hue superiority across psychophysics, MEG, and networks |

Supplementary figures:

| Script | Figure | Content |
| --- | --- | --- |
| `figS1_color_settings_meg.m` | S1 | Distances between odd-disc colours and references |
| `figS2_prop_correct_meg.m` | S2 | Fitted discrimination performance of the MEG colours |
| `figS3_vs_decoding_accuracy.m` | S3 | Decoding accuracy vs. performance and chromatic distance |
| `figS4_log_odds_ratio_meg.m` | S4 | Per-participant psychophysics vs. MEG asymmetry |
| `figS5_decoding_acc_color_task.m` | S5 | MVPA decoding, task-comparison colour task |
| `figS6_decoding_acc_orientation_task.m` | S6 | MVPA decoding, task-comparison orientation task |
| `figS7_taskonomy.m` | S7 | Hue/chroma ratios across 24 Taskonomy tasks (best-aligned depth) |
| `figS8_taskonomy_24tasks_layer.m` | S8 | Layer-wise hue/chroma ratios across Taskonomy tasks |
| `figS9_network_layers.m` | S9 | Layer-wise hue/chroma ratios across the main-text networks |

**Figure 4** (MEG source localization) is not generated from this code: it was
produced with dedicated source-analysis software (Curry 8.0.6, Compumedics
Ltd.). **Figure S10** (threshold-estimation schematic) is a hand-drawn diagram
and likewise has no associated code.

---

## 5. Data

The committed [`data/`](data/) folder contains all the data needed to reproduce
every figure. These are the aggregated values used by the figure scripts; the
repository is self-contained and no additional download is required.

In all colour-related arrays the convention is:

* **Chromatic axis ("hue/chroma"):** `hue` (angular, around the DKL hue circle)
  vs. `chroma` (radial, saturation).
* **Quadrant:** `orange` vs. `purple` — the two reference colours that anchor
  the discrimination asymmetry.
* **Direction:** `pos` vs. `neg` — the two directions in which the comparison
  colour is displaced from the reference along the chosen axis.

### 5.1 MATLAB (`.mat`) files

These hold nested structures; the field layout of each is documented below.

#### `data/object_pixels.mat` — variable `fruitData` *(used by Fig. 1)*

A `1 × 6` struct array, one element per photographed natural object
(`lemon`, `orange`, `carrot`, `raspberry`, `darkcabbage`, `greenPepper`). Each
element has the fields:

| Field | Size | Description |
| --- | --- | --- |
| `name` | char | Object label |
| `LAB` | *Npix* × 3 | CIELAB coordinates of every object pixel (L\*, a\*, b\*) |
| `DKL` | *Npix* × 3 | DKL coordinates of every object pixel (luminance, L–M, S–(L+M)) |
| `RGBuncorr` | *Npix* × 3 | Linear (gamma-uncorrected) RGB of every pixel, range 0–1 |
| `icon` | *H* × *W* × 4 | RGBA thumbnail image of the object, used as a plot inset |

*Npix* differs per object (≈10⁵ pixels each).

#### `data/meg_colors.mat` — variable `MEGcolors` *(used by Figs. S1, S2)*

The colour geometry and behavioural performance of the discs shown in the three
MEG experiments. Most arrays are `1 × 3` cells indexed by experiment, in the
order given by `expNames = {'supp exp', 'main exp', 'control exp'}`
(`MEGnames = {'orange-hue-focused', 'purple-focused', 'control'}`).

| Field | Type | Description |
| --- | --- | --- |
| `distDKL` | 1×3 cell | DKL distance between odd disc and reference. Each cell is a `quad × hc × direc × step × pt` array = `2 × 2 × 2 × 3 × N` (N = 27 / 29 / 19 participants) |
| `propCorr` | 1×3 cell | Proportion-correct for the same conditions, same `2 × 2 × 2 × 3 × N` layout |
| `pts` | 1×3 cell | Participant ID lists for each experiment |
| `expNames` | 1×3 cell | Experiment labels (see above) |
| `MEGnames` | 1×3 cell | Internal experiment names |
| `dims` | 1×5 string | Names of the array dimensions: `["quad","hc","direc","step","pt"]` |
| `dimLevs` | struct | Level labels per dimension: `quad = {purple, orange}`, `hc = {hue, chroma}`, `direc = {pos, neg}`, `step = [1 2 3]` |

#### `data/meg_decoding_accuracies.mat` — variable `dec` *(used by Figs. 5, 6, S3, S5, S6)*

Time-resolved MVPA decoding accuracies. Cells are indexed by experiment as
above.

| Field | Type | Description |
| --- | --- | --- |
| `acc_agg` | 1×3 cell | Per-participant decoding accuracy. Each cell is `time × quad × hc × direc × step × pt` = `241 × 2 × 2 × 2 × 3 × N` |
| `acc_gav` | 1×3 cell | Grand-average over participants: `time × quad × hc × direc × step` = `241 × 2 × 2 × 2 × 3` |
| `acc_statsAcc` | 1×3 cell | Cluster-based permutation statistics on decoding accuracy, per `(quad × hc × step)` condition (each a struct with a time-resolved p-value field `prob`) |
| `acc_statsLOR` | 1×3 cell | Cluster-based permutation statistics on the hue/chroma log-odds-ratio, per `(quad × step)` condition (same struct layout) |
| `pts`, `ptInds` | 1×3 cell | Participant IDs and indices |
| `accTime` | 1×241 | Time axis in seconds (−0.5 to 1.5 s relative to stimulus onset) |
| `accDims` | 1×6 string | Dimension names: `["time","quad","hc","direc","step","pt"]` |
| `accDimLevs` | struct | Level labels (same scheme as `MEGcolors.dimLevs`) |
| `expNames`, `MEGnames` | 1×3 cell | Experiment labels |
| `oddsFormula` | char | Formula used to convert accuracy to odds: `acc_avgOverTime ./ (1 - acc_avgOverTime)` |

#### `data/meg_log_odds_ratios.mat` *(used by Figs. 6, 8, S4, S7)*

Participant-level MEG log-odds ratios summarising the decoding asymmetry.

| Variable | Size | Description |
| --- | --- | --- |
| `logoddsratios` | 29 × 2 × 15 × 3 | `pt × colour × timeWindow × step`. Colour index **1 = orange**, **2 = purple** |
| `subs` | 1×29 cell | Participant IDs (aligned to the first dimension) |
| `timeWin` | 15 × 2 | Lower/upper edge (s) of each time window, from −0.25 to 1.25 s |

### 5.2 Human thresholds (CSV)

`data/human/human_thresholds.csv` — one row per participant × condition
(44 participants).

| Column | Description |
| --- | --- |
| `ptID` | Participant identifier |
| `hue/chroma` | Chromatic axis: `hue` or `chroma` |
| `quadrant` | Reference colour: `orange` or `purple` |
| `direction` | Displacement direction: `pos` or `neg` |
| `JND` | Just-noticeable difference (discrimination threshold, DKL units) |

### 5.3 Network thresholds (CSV)

`data/network/<network>_thresholds.csv` — discrimination thresholds for nine
networks (`resnet50`, `resnet18`, `resnet50_flips`, `places365_resnet50`,
`places365_resnet18`, `fasterrcnn_resnet50_fpn`,
`fasterrcnn_resnet50_fpn_coco_scratch`, `keypointrcnn_resnet50_fpn`,
`keypointrcnn_resnet50_fpn_coco_scratch`).

| Column | Description |
| --- | --- |
| `depth` | Processing depth: `layer_1`, `block_1`–`block_4`, `final_layer` |
| `hue/chroma` | Chromatic axis (`hue` / `chroma`) |
| `quadrant` | Reference colour (`orange` / `purple`) |
| `direction` | Displacement direction (`pos` / `neg`) |
| `threshold_mean` | Mean threshold across repeated read-out probes |
| `threshold_se` | Standard error of the threshold |
| `n_measured` | Number of probes contributing to the mean |
| `max_tested_mean` | Mean of the largest displacement tested (ceiling) |

`data/network/taskonomy_thresholds.csv` — per-task, per-iteration thresholds for
the 24 Taskonomy encoders (depths `layer_1`, `block_1`–`block_4`).

| Column | Description |
| --- | --- |
| `task` | Taskonomy task name (e.g. `autoencoding`, `normal`, `depth_zbuffer`) |
| `iter` | Repeat index for that task |
| `depth` | Processing depth (`layer_1`, `block_1`–`block_4`) |
| `hue/chroma`, `quadrant`, `direction` | As above |
| `threshold` | Discrimination threshold for that probe |
| `max_tested` | Largest displacement tested (ceiling) |

### 5.4 Natural-scene hue histograms (`data/dkl_hist_results/`)

Pre-computed DKL hue histograms used by Fig. 2, one pair of files per dataset
(`barcelona`, `cave`, `coco`, `foster_nascimento_2002/2004/2015/time_lapse`,
`granada`, `harvard`, `icvl`, `imagenet`, `imagenet_flips`, `mcgill`,
`natural_reflectance`, `places365`, `things`, `tiny_taskonomy`,
`tokyo_tech_31band/59band`, `valencia`):

* `<dataset>_hue_histogram.csv` — columns `hue_bin`, `hue_center_deg`,
  `hue_edge_lo_deg`, `hue_edge_hi_deg`, `count` (24 hue bins of 15° each, with
  the total pixel count per bin).
* `<dataset>_summary.csv` — columns `dataset`, `n_images`, `n_total_pixels`,
  `n_valid_pixels`.

The subfolder `tiny_taskonomy_dkl_histcount/` holds the per-scene counts that
Fig. 2 aggregates into `tiny_taskonomy_hue_histogram.csv`. Each
`tiny_taskonomy_<scene>_count.mat` contains a struct `Out` with:

| Field | Size | Description |
| --- | --- | --- |
| `Out.counted.all` | 24 × *Nimg* | Pixel counts per `hue × image` (summed over the chroma dimension) |
| `Out.meanLum_eachhue.all` | 24 × *Nimg* | Mean luminance per hue bin per image |
| `Out.hueedge` | 1 × 25 | Hue bin edges (radians) |
| `Out.image_files` | 1 × *Nimg* cell | Source image filenames |

`tiny_taskonomy_count_summary.csv` lists, per scene class, `n_images`,
`n_failures`, and `status`.

---

## 6. Citation

If you use this code or data, please cite:

> Laysa Hedjar✝, Takuma Morimoto✝, Arash Akbarinia, Mandy V. Bartsch,
> Hendrik Strumpf, Jens-Max Hopf, and Karl R. Gegenfurtner.
> "Environmental color statistics shape the anisotropic geometry of human color
> discrimination." *Preprint*, 2026. DOI to be added.
>
> ✝ These authors contributed equally.

---

## 7. License

Released under the [MIT License](LICENSE).
