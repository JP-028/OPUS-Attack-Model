function comparison = comparePaired(attacked,control)
% Compare runs with identical inputs and reporting checkpoints. Differences
% are attacked minus no-attack control, never an absolute company forecast.
    ids=string(attacked.final.owners.ids(:));
    if ~isequal(ids,string(control.final.owners.ids(:))) || ...
            ~isequal(attacked.parameters.x0,control.parameters.x0)
        error('OPUS:InvalidPairedRuns','Paired runs must have identical owners and initial populations.');
    end
    n=attacked.parameters.N_shell; m=numel(ids);
    initial=attacked.scenario.attack.owners;
    owner=table(ids,'VariableNames',{'owner_id'});
    names={'initial_active','control_final_active','attacked_final_active','delta_active', ...
        'control_final_derelicts','attacked_final_derelicts','delta_derelicts', ...
        'control_launched','attacked_launched','delta_launched', ...
        'control_collision_losses','attacked_collision_losses','delta_collision_losses', ...
        'control_modeled_revenue','attacked_modeled_revenue','delta_modeled_revenue', ...
        'control_launch_spending','attacked_launch_spending','delta_launch_spending', ...
        'control_cash_flow_proxy','attacked_cash_flow_proxy','delta_cash_flow_proxy', ...
        'control_discounted_cash_flow_proxy','attacked_discounted_cash_flow_proxy', ...
        'delta_discounted_cash_flow_proxy','fragmented','disabled'};
    for f=names, owner.(f{1})=zeros(m,1); end
    shellRows=cell(n*m,13); row=0;
    for i=1:m
        id=ids(i);
        owner.initial_active(i)=sum(initial.S(:,i)+initial.Su(:,i));
        owner.control_final_active(i)=sum(control.final.owners.S(:,i)+control.final.owners.Su(:,i));
        owner.attacked_final_active(i)=sum(attacked.final.owners.S(:,i)+attacked.final.owners.Su(:,i));
        owner.delta_active(i)=owner.attacked_final_active(i)-owner.control_final_active(i);
        owner.control_final_derelicts(i)=sum(control.final.owners.D(:,i));
        owner.attacked_final_derelicts(i)=sum(attacked.final.owners.D(:,i));
        owner.delta_derelicts(i)=owner.attacked_final_derelicts(i)-owner.control_final_derelicts(i);
        c=ledgerTotals(control.owner_economics,id,[]);
        a=ledgerTotals(attacked.owner_economics,id,[]);
        pairs={'launched','collision_losses','modeled_revenue','launch_spending', ...
            'cash_flow_proxy','discounted_cash_flow_proxy'};
        for p=pairs
            field=p{1};
            owner.(['control_' field])(i)=c.(field);
            owner.(['attacked_' field])(i)=a.(field);
            owner.(['delta_' field])(i)=a.(field)-c.(field);
        end
        owner.fragmented(i)=sum(attacked.fragmentations.destroyed_count( ...
            attacked.fragmentations.owner_id==id));
        owner.disabled(i)=sum(attacked.disablings.disabled_count( ...
            attacked.disablings.owner_id==id));
        for k=1:n
            row=row+1;
            initialActive=initial.S(k,i)+initial.Su(k,i);
            controlActive=control.final.owners.S(k,i)+control.final.owners.Su(k,i);
            attackedActive=attacked.final.owners.S(k,i)+attacked.final.owners.Su(k,i);
            ck=ledgerTotals(control.owner_economics,id,k);
            ak=ledgerTotals(attacked.owner_economics,id,k);
            shellRows(row,:)={id,k,initialActive,controlActive,attackedActive, ...
                attackedActive-controlActive,control.final.owners.D(k,i), ...
                attacked.final.owners.D(k,i),ck.launched,ak.launched, ...
                ak.launched-ck.launched,ck.discounted_cash_flow_proxy, ...
                ak.discounted_cash_flow_proxy-ck.discounted_cash_flow_proxy};
        end
    end
    ownerShell=cell2table(shellRows,'VariableNames',{'owner_id','shell','initial_active', ...
        'control_final_active','attacked_final_active','delta_active', ...
        'control_final_derelicts','attacked_final_derelicts', ...
        'control_launched','attacked_launched','delta_launched', ...
        'control_discounted_cash_flow_proxy','delta_discounted_cash_flow_proxy'});
    ownerShell.owner_id=string(ownerShell.owner_id);
    shell=(1:n)';
    initialDebris=attacked.parameters.x0(2*n+1:3*n);
    controlDebris=control.final.N;
    attackedDebris=attacked.final.N;
    debris=table(shell,initialDebris,controlDebris,attackedDebris, ...
        attackedDebris-controlDebris,'VariableNames',{'shell','initial_N', ...
        'control_final_N','attacked_final_N','delta_N'});
    comparison=struct('owners',owner,'owner_shells',ownerShell,'debris',debris);
end

function totals=ledgerTotals(ledger,id,k)
    selected=ledger.owner_id==id;
    if ~isempty(k), selected=selected & ledger.shell==k; end
    totals.launched=sum(ledger.launched_count(selected));
    totals.collision_losses=sum(ledger.collision_loss_count(selected));
    totals.modeled_revenue=sum(ledger.modeled_revenue(selected));
    totals.launch_spending=sum(ledger.launch_spending(selected));
    totals.cash_flow_proxy=sum(ledger.cash_flow_proxy(selected));
    totals.discounted_cash_flow_proxy=sum(ledger.discounted_cash_flow_proxy(selected));
end
