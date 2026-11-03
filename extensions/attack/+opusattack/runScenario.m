function result = runScenario(parameter_file, years, outputDirectory)
% Annual owner-specific decisions and shared physics; no attack events yet.
% Default horizon: 1 year. Default export: extensions/attack/results/<unique run>.
% Pass '' as outputDirectory for an in-memory run without file writes.
    if nargin<2, years=1; end
    validateattributes(years,{'numeric'},{'scalar','real','finite','positive'});
    scenario=opusattack.prepareScenario(parameter_file);
    if ~scenario.attack.enabled
        error('OPUS:AttackNotEnabled','Use the original OPUS workflow for non-opt-in scenarios.');
    end
    [V,costs]=prepareDynamics(scenario);
    owners=scenario.attack.owners;
    N=V.x0(2*V.N_shell+1:3*V.N_shell);
    times=0:1:years;
    if times(end)<years, times(end+1)=years; end
    result.scenario=scenario;
    result.parameters=V;
    result.cost_parameters=costs;
    result.input_files=snapshotInputs(parameter_file);
    result.intervals=cell(numel(times)-1,1);
    result.launch_decisions=table;
    result.flows=table;
    result.events=table;
    result.event_participants=table;
    result.history=struct('T',[],'S',[],'D',[],'Su',[],'N',[],'total',[]);
    result.history.owners=struct('ids',{owners.ids},'S',[],'D',[],'Su',[]);
    for period=1:numel(times)-1
        a=times(period); b=times(period+1);
        [launches,decisions]=opusattack.ownerLaunches(owners,scenario.attack.launch_rules,V,b-a);
        decisions.start_time=repmat(a,height(decisions),1);
        decisions.end_time=repmat(b,height(decisions),1);
        result.launch_decisions=[result.launch_decisions;decisions];
        OUT=opusattack.propagateOwners(linspace(a,b,max(3,V.N_step)),owners,N,launches,V);
        result.intervals{period}=OUT;
        [flows,events,participants]=flowTables(OUT,a,b,height(result.events));
        result.flows=[result.flows;flows];
        result.events=[result.events;events];
        result.event_participants=[result.event_participants;participants];
        first=1+(period>1);
        for name={'T','S','D','Su','N','total'}
            key=name{1}; result.history.(key)=[result.history.(key);OUT.(key)(first:end,:)];
        end
        for name={'S','D','Su'}
            key=name{1}; result.history.owners.(key)=cat(1,result.history.owners.(key),OUT.owners.(key)(first:end,:,:));
        end
        owners=OUT.final.owners;
        N=OUT.final.N;
    end
    result.final=OUT.final;
    result.metadata=struct('schema_version',1,'scenario_name',scenario.name, ...
        'years',years,'matlab_version',version,'created_utc',char(datetime('now','TimeZone','UTC')), ...
        'launch_default','current owner count divided by Dt', ...
        'collision_records','ordered expected flow contributions, not individual incidents', ...
        'attacks_supported',false, 'relative_tolerance',1e-8,'absolute_tolerance',1e-8);
    result.max_balance_residual=max(cellfun(@(o)o.max_balance_residual,result.intervals));
    result.source_manifest=sourceManifest();
    if nargin<3
        extensionRoot=fileparts(fileparts(mfilename('fullpath')));
        token=char(java.util.UUID.randomUUID());
        outputDirectory=fullfile(extensionRoot,'results',[scenario.name '_' datestr(now,'yyyymmdd_HHMMSS') '_' token(1:8)]);
    end
    result.output_directory=char(outputDirectory);
    if ~isempty(result.output_directory)
        opusattack.exportResults(result,result.output_directory);
    end
end

function inputs=snapshotInputs(parameter_file)
    [~,info]=fileattrib(parameter_file);
    [parent,stem]=fileparts(info.Name);
    paths={info.Name}; names={'scenario.csv'};
    files=dir(fullfile(parent,[stem '-owners'],'*.csv'));
    for i=1:numel(files)
        paths{end+1}=fullfile(files(i).folder,files(i).name); %#ok<AGROW>
        names{end+1}=fullfile('owners',files(i).name); %#ok<AGROW>
    end
    launchFile=fullfile(parent,[stem '-launches.csv']);
    if isfile(launchFile), paths{end+1}=launchFile; names{end+1}='launches.csv'; end
    inputs=struct('path',paths,'snapshot_name',names,'contents',cell(size(paths)));
    for i=1:numel(inputs), inputs(i).contents=fileread(inputs(i).path); end
end

function manifest=sourceManifest()
    extensionRoot=fileparts(fileparts(mfilename('fullpath')));
    root=fileparts(fileparts(extensionRoot));
    files=[dir(fullfile(root,'*.m'));dir(fullfile(root,'MOCAT4S','*.m')); ...
        dir(fullfile(extensionRoot,'+opusattack','**','*.m'));dir(fullfile(root,'x0_TLE','*.csv')); ...
        dir(fullfile(root,'MOCAT4S','LawDF_min_500_fit_range_max_10000_sols_1.csv')); ...
        dir(fullfile(root,'scenarios','parsets','constellation-parameters.csv'))];
    rows=cell(numel(files),2);
    for i=1:numel(files)
        file=fullfile(files(i).folder,files(i).name);
        fid=fopen(file,'rb'); cleanup=onCleanup(@() fclose(fid));
        bytes=fread(fid,Inf,'*uint8');
        digest=java.security.MessageDigest.getInstance('SHA-256');
        hash=typecast(digest.digest(bytes),'uint8');
        rows(i,:)={file(numel(root)+2:end),lower(reshape(dec2hex(hash,2)',1,[]))};
        clear cleanup
    end
    manifest=cell2table(rows,'VariableNames',{'path','sha256'});
end
