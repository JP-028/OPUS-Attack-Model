function [owners,N,report] = applyDisabling(owners,N,event,VAR)
% Transfer active satellites directly to the same owner's D in the same shell.
% D then follows existing passive dynamics; no disposal maneuver is applied.
    if ~isscalar(event) || string(event.event_type)~="disabling" || ...
            ~isscalar(event.count) || ~isfinite(event.count) || ...
            event.count<1 || event.count~=fix(event.count)
        error('OPUS:UnsupportedAttackSize','Disabling requires a positive integer count.');
    end
    pop=char(event.population);
    if ~ismember(string(pop),["S","Su"])
        error('OPUS:InvalidAttackEvents','Only active S or Su can be targeted.');
    end
    i=find(strcmpi(owners.ids,event.owner_id),1); k=event.shell;
    if isempty(i) || ~isscalar(k) || ~isfinite(k) || k~=fix(k) || k<1 || k>VAR.N_shell
        error('OPUS:InvalidAttackEvents','Invalid attacked owner or shell.');
    end
    validateDisablingPhysics(VAR,pop);
    count=event.count; available=owners.(pop)(k,i);
    if ~isfinite(available) || available<count
        error('OPUS:InsufficientAttackTargets', ...
            'Event %s at year %.15g requires %.15g %s satellites from %s in shell %d; only %.15g remain.', ...
            event.event_id,event.time_year,count,pop,owners.ids{i},k,available);
    end
    beforeD=owners.D(k,i); afterD=beforeD+count; afterActive=available-count;
    if ~isfinite(afterD) || afterD==beforeD || afterActive==available || ~isfinite(count*VAR.mass(2))
        error('OPUS:InvalidDisablingTransfer','Disabled count or mass is not representable with this state.');
    end
    owners.(pop)(k,i)=afterActive;
    owners.D(k,i)=afterD;
    residual=(afterD-beforeD)+(afterActive-available);
    report=emptyDisablingLog();
    report(1,:)={string(event.event_id),"attack:"+string(event.event_id),event.time_year, ...
        string(owners.ids{i}),k,string(pop),count,count,VAR.mass(2),VAR.A(2),VAR.diameter(2), ...
        available,afterActive,beforeD,afterD,N(k),N(k),count*VAR.mass(2),residual*VAR.mass(2),residual};
end
