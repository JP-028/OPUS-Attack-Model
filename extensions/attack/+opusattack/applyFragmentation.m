function [owners,N,report] = applyFragmentation(owners,N,event,VAR)
% Apply one instantaneous fragmentation; only the selected active count and N change.
% event is a scalar struct from a validated event-table row. Owner identity remains
% in the report, but the fragments join the shell's shared standard debris class.
    if ~isscalar(event) || event.count~=1 || string(event.event_type)~="fragmentation"
        error('OPUS:UnsupportedAttackSize','Only one-satellite fragmentation is supported.');
    end
    pop=char(event.population);
    if ~ismember(string(pop),["S","Su"])
        error('OPUS:InvalidAttackEvents','Only active S or Su can be targeted.');
    end
    i=find(strcmpi(owners.ids,event.owner_id),1); k=event.shell;
    if isempty(i) || ~isscalar(k) || ~isfinite(k) || k~=fix(k) || k<1 || k>VAR.N_shell
        error('OPUS:InvalidAttackEvents','Invalid attacked owner or shell.');
    end
    available=owners.(pop)(k,i);
    if ~isfinite(available) || available<1
        error('OPUS:InsufficientAttackTargets', ...
            'Event %s at year %.15g requires 1 %s satellite from %s in shell %d; only %.15g remain.', ...
            event.event_id,event.time_year,pop,owners.ids{i},k,available);
    end
    validateattributes(VAR.mass,{'numeric'},{'vector','numel',4,'real','finite','positive'});
    source=1;
    if strcmp(pop,'Su'), source=4; end
    mass=VAR.mass(source); fragmentMass=VAR.mass(3);
    added=mass/fragmentMass;
    beforeN=N(k); beforeD=owners.D(k,i);
    if ~isfinite(added) || ~isfinite(beforeN+added) || beforeN+added==beforeN
        error('OPUS:InvalidFragmentationMass','Fragment count is not representable with these masses and debris counts.');
    end
    owners.(pop)(k,i)=available-1;
    N(k)=beforeN+added;
    report=emptyFragmentationLog();
    report(1,:)={string(event.event_id),"attack:"+string(event.event_id),event.time_year, ...
        string(owners.ids{i}),k,string(pop),1,1,mass,fragmentMass,added,available,available-1, ...
        beforeN,N(k),beforeD,owners.D(k,i),mass,added*fragmentMass,added*fragmentMass-mass};
end
