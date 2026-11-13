# funcml 0.9.8

Exported functions are now glued lowercase, with no underscores. The old names
still work but are deprecated and will be removed in a future release.

| Old name | New name |
|----------|----------|
| `auc_ci()` | `aucci()` |
| `auc_weighted()` | `aucweighted()` |
| `balanced_accuracy()` | `balancedaccuracy()` |
| `calibration_curve()` | `calibrationcurve()` |
| `default_tune_grid()` | `defaulttunegrid()` |
| `group_cv()` | `groupcv()` |
| `list_interpretability_methods()` | `listinterpretabilitymethods()` |
| `list_learners()` | `listlearners()` |
| `list_metrics()` | `listmetrics()` |
| `list_tunable_learners()` | `listtunablelearners()` |
| `roc_curve()` | `roccurve()` |
| `theme_funcml()` | `themefuncml()` |
| `time_cv()` | `timecv()` |

Metric identifiers such as `"balanced_accuracy"` and `"auc_weighted"` are unchanged.

