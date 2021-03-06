rule download_demographic_data:
    input:
        participant_file = "data/external/participant_files/{pid}.yaml"
    params:
        source = config["PARAMS_FOR_ANALYSIS"]["DEMOGRAPHIC"]["SOURCE"],
        table = config["PARAMS_FOR_ANALYSIS"]["DEMOGRAPHIC"]["TABLE"],
    output:
        "data/raw/{pid}/participant_info_raw.csv"
    script:
        "../src/data/workflow_example/download_demographic_data.R"

rule demographic_features:
    input:
        participant_info = "data/raw/{pid}/participant_info_raw.csv"
    params:
        pid = "{pid}",
        features = config["PARAMS_FOR_ANALYSIS"]["DEMOGRAPHIC"]["FEATURES"]
    output:
        "data/processed/features/{pid}/demographic_features.csv"
    script:
        "../src/features/workflow_example/demographic_features.py"

rule download_target_data:
    input:
        participant_file = "data/external/participant_files/{pid}.yaml"
    params:
        source = config["PARAMS_FOR_ANALYSIS"]["TARGET"]["SOURCE"],
        table = config["PARAMS_FOR_ANALYSIS"]["TARGET"]["TABLE"],
    output:
        "data/raw/{pid}/participant_target_raw.csv"
    script:
        "../src/data/workflow_example/download_target_data.R"

rule target_readable_datetime:
    input:
        sensor_input = "data/raw/{pid}/participant_target_raw.csv",
        time_segments = "data/interim/time_segments/{pid}_time_segments.csv"
    params:
        fixed_timezone = config["PARAMS_FOR_ANALYSIS"]["TARGET"]["SOURCE"]["TIMEZONE"],
        time_segments_type = config["TIME_SEGMENTS"]["TYPE"],
        include_past_periodic_segments = config["TIME_SEGMENTS"]["INCLUDE_PAST_PERIODIC_SEGMENTS"]
    output:
        "data/raw/{pid}/participant_target_with_datetime.csv"
    script:
        "../src/data/readable_datetime.R"

rule parse_targets:
    input:
        targets = "data/raw/{pid}/participant_target_with_datetime.csv",
        time_segments_labels = "data/interim/time_segments/{pid}_time_segments_labels.csv"
    output:
        "data/processed/targets/{pid}/parsed_targets.csv"
    script:
        "../src/models/workflow_example/parse_targets.py"

rule clean_sensor_features_for_individual_participants:
    input:
        rules.merge_sensor_features_for_individual_participants.output
    params:
        cols_nan_threshold = config["PARAMS_FOR_ANALYSIS"]["COLS_NAN_THRESHOLD"],
        cols_var_threshold = config["PARAMS_FOR_ANALYSIS"]["COLS_VAR_THRESHOLD"],
        rows_nan_threshold = config["PARAMS_FOR_ANALYSIS"]["ROWS_NAN_THRESHOLD"],
        data_yielded_hours_ratio_threshold = config["PARAMS_FOR_ANALYSIS"]["DATA_YIELDED_HOURS_RATIO_THRESHOLD"],
    output:
        "data/processed/features/{pid}/all_sensor_features_cleaned.csv"
    script:
        "../src/models/workflow_example/clean_sensor_features.R"

rule clean_sensor_features_for_all_participants:
    input:
        rules.merge_sensor_features_for_all_participants.output
    params:
        cols_nan_threshold = config["PARAMS_FOR_ANALYSIS"]["COLS_NAN_THRESHOLD"],
        cols_var_threshold = config["PARAMS_FOR_ANALYSIS"]["COLS_VAR_THRESHOLD"],
        rows_nan_threshold = config["PARAMS_FOR_ANALYSIS"]["ROWS_NAN_THRESHOLD"],
        data_yielded_hours_ratio_threshold = config["PARAMS_FOR_ANALYSIS"]["DATA_YIELDED_HOURS_RATIO_THRESHOLD"],
    output:
        "data/processed/features/all_participants/all_sensor_features_cleaned.csv"
    script:
        "../src/models/workflow_example/clean_sensor_features.R"

rule merge_features_and_targets_for_individual_model:
    input:
        cleaned_sensor_features = "data/processed/features/{pid}/all_sensor_features_cleaned.csv",
        targets = "data/processed/targets/{pid}/parsed_targets.csv",
    output:
        "data/processed/models/individual_model/{pid}/input.csv"
    script:
        "../src/models/workflow_example/merge_features_and_targets_for_individual_model.py"

rule merge_features_and_targets_for_population_model:
    input:
        cleaned_sensor_features = "data/processed/features/all_participants/all_sensor_features_cleaned.csv",
        demographic_features = expand("data/processed/features/{pid}/demographic_features.csv", pid=config["PIDS"]),
        targets = expand("data/processed/targets/{pid}/parsed_targets.csv", pid=config["PIDS"]),
    output:
        "data/processed/models/population_model/input.csv"
    script:
        "../src/models/workflow_example/merge_features_and_targets_for_population_model.py"

rule baselines_for_individual_model:
    input:
        "data/processed/models/individual_model/{pid}/input.csv"
    params:
        cv_method = "{cv_method}",
        colnames_demographic_features = config["PARAMS_FOR_ANALYSIS"]["DEMOGRAPHIC"]["FEATURES"],
    output:
        "data/processed/models/individual_model/{pid}/output_{cv_method}/baselines.csv"
    log:
        "data/processed/models/individual_model/{pid}/output_{cv_method}/baselines_notes.log"
    script:
        "../src/models/workflow_example/baselines.py"

rule baselines_for_population_model:
    input:
        "data/processed/models/population_model/input.csv"
    params:
        cv_method = "{cv_method}",
        colnames_demographic_features = config["PARAMS_FOR_ANALYSIS"]["DEMOGRAPHIC"]["FEATURES"],
    output:
        "data/processed/models/population_model/output_{cv_method}/baselines.csv"
    log:
        "data/processed/models/population_model/output_{cv_method}/baselines_notes.log"
    script:
        "../src/models/workflow_example/baselines.py"

rule modelling_for_individual_participants:
    input:
        data = "data/processed/models/individual_model/{pid}/input.csv"
    params:
        model = "{model}",
        cv_method = "{cv_method}",
        scaler = "{scaler}",
        categorical_operators = config["PARAMS_FOR_ANALYSIS"]["CATEGORICAL_OPERATORS"],
        categorical_demographic_features = config["PARAMS_FOR_ANALYSIS"]["DEMOGRAPHIC"]["CATEGORICAL_FEATURES"],
        model_hyperparams = config["PARAMS_FOR_ANALYSIS"]["MODEL_HYPERPARAMS"],
    output:
        fold_predictions = "data/processed/models/individual_model/{pid}/output_{cv_method}/{model}/{scaler}/fold_predictions.csv",
        fold_metrics = "data/processed/models/individual_model/{pid}/output_{cv_method}/{model}/{scaler}/fold_metrics.csv",
        overall_results = "data/processed/models/individual_model/{pid}/output_{cv_method}/{model}/{scaler}/overall_results.csv",
        fold_feature_importances = "data/processed/models/individual_model/{pid}/output_{cv_method}/{model}/{scaler}/fold_feature_importances.csv"
    log:
        "data/processed/models/individual_model/{pid}/output_{cv_method}/{model}/{scaler}/notes.log"
    script:
        "../src/models/workflow_example/modelling.py"

rule modelling_for_all_participants:
    input:
        data = "data/processed/models/population_model/input.csv"
    params:
        model = "{model}",
        cv_method = "{cv_method}",
        scaler = "{scaler}",
        categorical_operators = config["PARAMS_FOR_ANALYSIS"]["CATEGORICAL_OPERATORS"],
        categorical_demographic_features = config["PARAMS_FOR_ANALYSIS"]["DEMOGRAPHIC"]["CATEGORICAL_FEATURES"],
        model_hyperparams = config["PARAMS_FOR_ANALYSIS"]["MODEL_HYPERPARAMS"],
    output:
        fold_predictions = "data/processed/models/population_model/output_{cv_method}/{model}/{scaler}/fold_predictions.csv",
        fold_metrics = "data/processed/models/population_model/output_{cv_method}/{model}/{scaler}/fold_metrics.csv",
        overall_results = "data/processed/models/population_model/output_{cv_method}/{model}/{scaler}/overall_results.csv",
        fold_feature_importances = "data/processed/models/population_model/output_{cv_method}/{model}/{scaler}/fold_feature_importances.csv"
    log:
        "data/processed/models/population_model/output_{cv_method}/{model}/{scaler}/notes.log"
    script:
        "../src/models/workflow_example/modelling.py"
