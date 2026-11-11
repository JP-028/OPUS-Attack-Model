function result = runScenario(parameter_file, years, outputDirectory, attackMode, attackedOwner)
% Annual owner decisions, shared physics, and scheduled attacks.
% Default horizon: 1 year. Default export: extensions/attack/results/<unique run>.
% Pass '' as outputDirectory for an in-memory run without file writes.
% Optional attackMode='none' keeps the event-time checkpoints but suppresses
% attack transfers, for a matched no-attack control of the same scenario.
% Optional attackedOwner selects only that owner's scheduled events. The input
% schedule is still snapshotted, and metadata records the selection.
    if nargin<2, years=1; end
    if nargin<4, attackMode="scheduled"; end
    if nargin<5, attackedOwner=""; end
    if ~isscalar(string(attackMode)) || ~ismember(string(attackMode),["scheduled","none"])
        error('OPUS:InvalidAttackMode','Use scheduled or none for attackMode.');
    end
    attackMode=string(attackMode);
    if ~isscalar(string(attackedOwner))
        error('OPUS:InvalidAttackOwner','attackedOwner must be one owner ID or empty.');
    end
    attackedOwner=string(attackedOwner);
    validateattributes(years,{'numeric'},{'scalar','real','finite','positive'});
    scenario=opusattack.prepareScenario(parameter_file);
    if ~scenario.attack.enabled
        error('OPUS:AttackNotEnabled','Use the original OPUS workflow for non-opt-in scenarios.');
    end
    configured=scenario.attack.events;
    selected=configured;
    if strlength(attackedOwner)>0
        hit=find(strcmpi(scenario.attack.owners.ids,attackedOwner),1);
        if isempty(hit)
            error('OPUS:InvalidAttackOwner','Unknown attacked owner: %s.',attackedOwner);
        end
        attackedOwner=string(scenario.attack.owners.ids{hit});
        selected=configured(configured.owner_id==attackedOwner,:);
        if isempty(selected)
            error('OPUS:NoAttacksForOwner','No scheduled attacks target %s.',attackedOwner);
        end
    end
    if any(selected.time_year>years)
        error('OPUS:EventOutsideHorizon','All configured attacks must lie within [0, %.15g] years.',years);
    end
    planned=selected;
    if attackMode=="none"
        planned=selected([],:);
    end
    if attackMode=="none" || strlength(attackedOwner)>0
        scenario.attack.events=planned;
    end
    [V,costs]=prepareDynamics(scenario);
    owners=scenario.attack.owners;
    N=V.x0(2*V.N_shell+1:3*V.N_shell);
    initialOwners=owners; initialN=N;
    annualTimes=0:1:years;
    if annualTimes(end)<years, annualTimes(end+1)=years; end
    times=unique([annualTimes,selected.time_year']);
    result.scenario=scenario;
    result.parameters=V;
    result.cost_parameters=costs;
    result.input_files=snapshotInputs(parameter_file);
    result.intervals=cell(numel(times)-1,1);
    result.launch_decisions=table;
    result.economic_decisions=table;
    result.owner_economics=table;
    result.attack_economics=table;
    result.flows=table;
    result.events=table;
    result.event_participants=table;
    result.fragmentations=emptyFragmentationLog();
    result.disablings=emptyDisablingLog();
    result.attack_snapshots=cell(0,1);
    result.history=struct('T',[],'S',[],'D',[],'Su',[],'N',[],'total',[]);
    result.history.owners=struct('ids',{owners.ids},'S',[],'D',[],'Su',[]);
    result.history.phase=strings(0,1);
    result.history.event_id=strings(0,1);
    result.history=appendState(result.history,0,owners,N,"regular","");
    executed=false(height(planned),1);
    for period=1:numel(times)
        a=times(period);
        % Attack first at a boundary, then (if scheduled) the annual decision.
        hit=find(planned.time_year==a & ~executed);
        for j=hit'
            event=table2struct(planned(j,:));
            snapshot=struct('time',a,'event_id',"attack:"+string(event.event_id), ...
                'before',struct('owners',owners,'N',N));
            switch string(event.event_type)
                case "fragmentation"
                    [owners,N,report]=opusattack.applyFragmentation(owners,N,event,V);
                    result.fragmentations=[result.fragmentations;report];
                    [flow,eventRecord,participants]=fragmentationTables(report);
                case "disabling"
                    [owners,N,report]=opusattack.applyDisabling(owners,N,event,V);
                    result.disablings=[result.disablings;report];
                    [flow,eventRecord,participants]=disablingTables(report);
                otherwise
                    error('OPUS:InvalidAttackEvents','Unsupported attack type: %s.',event.event_type);
            end
            snapshot.after=struct('owners',owners,'N',N);
            result.attack_snapshots{end+1}=snapshot;
            economics=attackEconomics(report,snapshot.before.owners, ...
                scenario.econ_params,costs,scenario.attack.owner_economics);
            result.attack_economics=[result.attack_economics;economics];
            result.flows=[result.flows;flow];
            result.events=[result.events;eventRecord];
            result.event_participants=[result.event_participants;participants];
            if result.history.phase(end)=="post_event"
                % Preserve the previous simultaneous attack's post-event record.
                result.history=appendState(result.history,a,snapshot.before.owners,snapshot.before.N, ...
                    "pre_event",report.log_event_id);
            else
                result.history.phase(end)="pre_event";
                result.history.event_id(end)=report.log_event_id;
            end
            result.history=appendState(result.history,a,owners,N,"post_event",report.log_event_id);
            executed(j)=true;
        end
        if period==numel(times), break; end
        b=times(period+1);
        if ismember(a,annualTimes)
            nextAnnual=annualTimes(find(annualTimes>a,1));
            [launches,decisions]=opusattack.ownerLaunches(owners,scenario.attack.launch_rules,V,nextAnnual-a);
            [launches,economicDecisions]=economicLaunches(owners,N,launches,decisions, ...
                V,scenario.econ_params,costs,scenario.attack.owner_economics,nextAnnual-a);
            if ~isempty(economicDecisions)
                economicDecisions.start_time=repmat(a,height(economicDecisions),1);
                economicDecisions.end_time=repmat(nextAnnual,height(economicDecisions),1);
            end
            result.economic_decisions=[result.economic_decisions;economicDecisions];
            decisions.launch_rate=economicLaunchRate(decisions,launches,owners.ids);
            decisions.start_time=repmat(a,height(decisions),1);
            decisions.end_time=repmat(nextAnnual,height(decisions),1);
            result.launch_decisions=[result.launch_decisions;decisions];
        end
        % A midyear event splits propagation but does not reset that year's rates.
        OUT=opusattack.propagateOwners(linspace(a,b,max(3,V.N_step)),owners,N,launches,V);
        result.intervals{period}=OUT;
        [flows,events,participants]=flowTables(OUT,a,b,height(result.events));
        result.owner_economics=[result.owner_economics;economicInterval(OUT,flows, ...
            a,b,scenario.econ_params,costs,scenario.attack.owner_economics)];
        result.flows=[result.flows;flows];
        result.events=[result.events;events];
        result.event_participants=[result.event_participants;participants];
        first=2; % The initial/current boundary state is already in history.
        for name={'T','S','D','Su','N','total'}
            key=name{1}; result.history.(key)=[result.history.(key);OUT.(key)(first:end,:)];
        end
        for name={'S','D','Su'}
            key=name{1}; result.history.owners.(key)=cat(1,result.history.owners.(key),OUT.owners.(key)(first:end,:,:));
        end
        result.history.phase=[result.history.phase;repmat("regular",numel(OUT.T)-1,1)];
        result.history.event_id=[result.history.event_id;repmat("",numel(OUT.T)-1,1)];
        owners=OUT.final.owners;
        N=OUT.final.N;
    end
    if ~all(executed), error('OPUS:UnexecutedAttack','An attack was not executed.'); end
    result.final=struct('owners',owners,'N',N);
    result.population_balance=populationBalance(initialOwners,initialN,result.final,result.flows);
    result.max_global_balance_residual=max(abs(result.population_balance.residual));
    result.metadata=struct('schema_version',4,'scenario_name',scenario.name, ...
        'years',years,'matlab_version',version,'created_utc',char(datetime('now','TimeZone','UTC')), ...
        'launch_default','current owner count divided by Dt', ...
        'collision_records','ordered expected flow contributions, not individual incidents', ...
        'attacks_supported',true,'attack_scope','multiple fragmentation or disabling events', ...
        'fragmentation_count','one active satellite per event', ...
        'disabling_destination','same owner and shell in D; passive derelict dynamics', ...
        'simultaneous_attack_order','CSV row order', ...
        'attack_timing','before annual decisions; midyear launches held until next annual decision', ...
        'economic_launch_mode','optional bounded owner best responses with shared OPUS linear fringe revenue', ...
        'economic_collision_risk','per-satellite hazard from original MOCAT loss terms', ...
        'cash_flow_proxy','modeled revenue minus launch spending; excludes other operating costs', ...
        'relative_tolerance',1e-8,'absolute_tolerance',1e-8);
    result.metadata.attack_mode=char(attackMode);
    result.metadata.source_event_count=height(configured);
    result.metadata.configured_event_count=height(selected);
    result.metadata.applied_event_count=height(planned);
    result.metadata.selected_attacked_owner=char(attackedOwner);
    result.metadata.control_uses_event_checkpoints=true;
    result.metadata.initial_population_mode='original_allocation';
    if isfield(scenario.attack,'additional_constellations') && scenario.attack.additional_constellations
        result.metadata.initial_population_mode='additional_constellations';
        result.metadata.generic_owner_id='generic';
    end
    result.metadata.initial_debris_source='upstream VAR.x0 N';
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
    economicsFile=fullfile(parent,[stem '-economics.csv']);
    if isfile(economicsFile), paths{end+1}=economicsFile; names{end+1}='economics.csv'; end
    eventFile=fullfile(parent,[stem '-events.csv']);
    if isfile(eventFile), paths{end+1}=eventFile; names{end+1}='events.csv'; end
    inputs=struct('path',paths,'snapshot_name',names,'contents',cell(size(paths)));
    for i=1:numel(inputs), inputs(i).contents=fileread(inputs(i).path); end
end

function h=appendState(h,time,owners,N,phase,eventId)
    n=numel(N); m=numel(owners.ids);
    h.T(end+1,1)=time;
    for name={'S','D','Su'}
        key=name{1};
        h.(key)(end+1,:)=sum(owners.(key),2)';
        h.owners.(key)=cat(1,h.owners.(key),reshape(owners.(key),1,n,m));
    end
    h.N(end+1,:)=N';
    h.total(end+1,:)=h.S(end,:)+h.D(end,:)+h.Su(end,:)+h.N(end,:);
    h.phase(end+1,1)=phase;
    h.event_id(end+1,1)=eventId;
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
