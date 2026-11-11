function pair = runPairedScenarios(parameter_file,years,outputDirectory,attackedOwner)
% Run the same owner scenario with and without its scheduled attacks.
% The control retains the event-time integration checkpoints, launch rules,
% physical parameters and starting populations. Default export uses a new
% results folder with attacked/, control/ and difference summaries.
% Optional fourth argument selects only one attacked owner's event rows.
% Pass [] for the third argument to keep automatic output naming.
    if nargin<2, years=1; end
    if nargin<4, attackedOwner=""; end
    attacked=opusattack.runScenario(parameter_file,years,'','scheduled',attackedOwner);
    if attacked.metadata.configured_event_count==0
        error('OPUS:MissingPairedAttacks','A paired comparison requires at least one scheduled attack.');
    end
    control=opusattack.runScenario(parameter_file,years,'','none',attackedOwner);
    pair.attacked=attacked;
    pair.control=control;
    pair.comparison=comparePaired(attacked,control);
    pair.metadata=struct('comparison','attacked minus no-attack control', ...
        'same_scenario_input',true,'same_event_time_checkpoints',true, ...
        'configured_event_count',attacked.metadata.configured_event_count, ...
        'selected_attacked_owner',attacked.metadata.selected_attacked_owner, ...
        'years',years,'scenario_name',attacked.scenario.name);
    if nargin<3 || isequal(outputDirectory,[])
        extensionRoot=fileparts(fileparts(mfilename('fullpath')));
        token=char(java.util.UUID.randomUUID());
        label='all';
        if strlength(string(attackedOwner))>0, label=char(attackedOwner); end
        outputDirectory=fullfile(extensionRoot,'results', ...
            [attacked.scenario.name '_paired_' label '_' datestr(now,'yyyymmdd_HHMMSS') '_' token(1:8)]);
    end
    pair.output_directory=char(outputDirectory);
    if isempty(pair.output_directory), return; end
    if isfolder(pair.output_directory) || isfile(pair.output_directory)
        error('OPUS:OutputAlreadyExists','Choose a new paired output directory: %s',pair.output_directory);
    end
    [ok,message]=mkdir(pair.output_directory);
    if ~ok, error('OPUS:ExportFailed','%s',message); end
    pair.attacked.output_directory=fullfile(pair.output_directory,'attacked');
    pair.control.output_directory=fullfile(pair.output_directory,'control');
    opusattack.exportResults(pair.attacked,pair.attacked.output_directory);
    opusattack.exportResults(pair.control,pair.control.output_directory);
    writetable(pair.comparison.owners,fullfile(pair.output_directory,'owner-impact.csv'));
    writetable(pair.comparison.owner_shells,fullfile(pair.output_directory,'owner-shell-impact.csv'));
    writetable(pair.comparison.debris,fullfile(pair.output_directory,'debris-impact.csv'));
    writeText(fullfile(pair.output_directory,'metadata.json'),jsonencode(pair.metadata,'PrettyPrint',true));
    writeText(fullfile(pair.output_directory,'COMPLETE.txt'),'Paired comparison exported successfully.');
end

function writeText(file,contents)
    fid=fopen(file,'w','n','UTF-8');
    if fid<0, error('OPUS:ExportFailed','Cannot write %s.',file); end
    cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',contents);
end
