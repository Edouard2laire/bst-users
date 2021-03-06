
% This test is run on the protocol generated by the tutorial_omega.m script

%%

% Input files
sFiles = {...
    'sub-0002_ses-0001/@rawsub-0002_task-rest_run-01_meg_notch_high/data_0raw_sub-0002_task-rest_run-01_meg_notch_high.mat'};
SubjectNames = {...
    'sub-0002_ses-0001'};

sProcess = bst_process('GetInputStruct', sFiles);

% Start a new report
bst_report('Start', sFiles);

%% Import 10-second epochs

% Process: Import MEG/EEG: Time
epochFiles = bst_process('CallProcess', 'process_import_data_time', sFiles, [], ...
    'subjectname', SubjectNames{1}, ...
    'condition',   '', ...
    'timewindow',  [], ...
    'split',       10, ...
    'ignoreshort', 1, ...
    'usectfcomp',  1, ...
    'usessp',      1, ...
    'freq',        600, ...
    'baseline',    []);

%% Source model

db_set_noisecov(sProcess.iStudy,epochFiles(1).iStudy,0,1);

% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', epochFiles, [], ...
    'Comment',     '', ...
    'sourcespace', 1, ...  % Cortex surface
    'volumegrid',  1, ...
    'meg',         3, ...  % Overlapping spheres
    'eeg',         1, ...  % 
    'ecog',        1, ...  % 
    'seeg',        1, ...  % 
    'openmeeg',    struct(...
         'BemFiles',     {{}}, ...
         'BemNames',     {{'Scalp', 'Skull', 'Brain'}}, ...
         'BemCond',      [1, 0.0125, 1], ...
         'BemSelect',    [1, 1, 1], ...
         'isAdjoint',    0, ...
         'isAdaptative', 1, ...
         'isSplit',      0, ...
         'SplitLength',  4000));

% Process: Compute sources [2016]
bst_process('CallProcess', 'process_inverse_2016', epochFiles, [], ...
    'output',  1, ...  % Kernel only: shared
    'inverse', struct(...
         'Comment',        'dSPM: MEG', ...
         'InverseMethod',  'minnorm', ...
         'InverseMeasure', 'dspm', ...
         'SourceOrient',   {{'fixed'}}, ...
         'Loose',          0.2, ...
         'UseDepth',       1, ...
         'WeightExp',      0.5, ...
         'WeightLimit',    10, ...
         'NoiseMethod',    'reg', ...
         'NoiseReg',       0.1, ...
         'SnrMethod',      'fixed', ...
         'SnrRms',         1e-06, ...
         'SnrFixed',       3, ...
         'ComputeKernel',  1, ...
         'DataTypes',      {{'MEG'}}));

sStudy = bst_get('Study', epochFiles(1).iStudy);
KernelFile = sStudy.Result(1).FileName;
assert(~isempty(strfind(KernelFile,'KERNEL')));

%% Generate scout for seed voxel

[sSubject,iSubject] = bst_get('Subject', sProcess.SubjectFile);
CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
sCortex = in_tess_bst(CortexFile);
nUserScouts = length(sCortex.Atlas(1).Scouts);
sCortex.Atlas(1).Scouts(nUserScouts+1).Label = 'Left central gyrus seed';
sCortex.Atlas(1).Scouts(nUserScouts+1).Vertices = 4075;
sCortex.Atlas(1).Scouts(nUserScouts+1).Seed = 4075;
sCortex.Atlas(1).Scouts(nUserScouts+1).Color = [0 0 0];
sCortex.Atlas(1).Scouts(nUserScouts+1).Function = 'Mean';
bst_save(file_fullpath(CortexFile),sCortex);
db_reload_subjects(iSubject)

%% Compute AEC with and without orthogonalization

for iEpoch = 1:length(epochFiles)
    sourceFiles{iEpoch} = sprintf('link|%s|%s',KernelFile,epochFiles(1).FileName);
end
sInput = bst_process('GetInputStruct', sourceFiles);
    
% Process: Amplitude Envelope Correlation 1xN
aecFile = bst_process('CallProcess', 'process_aec1', sourceFiles, [], ...
    'timewindow', [], ...
    'scouts',     {'User scouts', {'Left central gyrus seed'}}, ...
    'scoutfunc',  1, ...  % Mean
    'scouttime',  1, ...  % Before
    'freqbands',  {'alpha', '8, 13', 'mean'; 'beta', '13, 30', 'mean'}, ...
    'mirror',     0, ...
    'isorth',     0, ...
    'outputmode', 3);  % Save average connectivity matrix (one file)

% Process: Amplitude Envelope Correlation 1xN
aecFile_orth = bst_process('CallProcess', 'process_aec1', sourceFiles, [], ...
    'timewindow', [], ...
    'scouts',     {'User scouts', {'Left central gyrus seed'}}, ...
    'scoutfunc',  1, ...  % Mean
    'scouttime',  1, ...  % Before
    'freqbands',  {'alpha', '8, 13', 'mean'; 'beta', '13, 30', 'mean'}, ...
    'mirror',     0, ...
    'isorth',     1, ...
    'outputmode', 3);  % Save average connectivity matrix (one file)

%%

% Save and display report
ReportFile = bst_report('Save', sFiles);
bst_report('Open', ReportFile);
% bst_report('Export', ReportFile, ExportDir);






