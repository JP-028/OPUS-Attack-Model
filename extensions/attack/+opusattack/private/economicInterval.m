function ledger=economicInterval(OUT,flows,startTime,endTime,econ,costs,ownerEconomics)
% Cash-flow inputs for every owner and active shell. Collision-asset loss is
% separate from cash flow to avoid counting the same replacement twice.
    n=size(OUT.S,2); m=numel(OUT.owners.ids);
    years=endTime-startTime;
    marketRevenue=econ.intercept-econ.coef*sum(OUT.Su,2);
    discountFactor=(1+econ.discountRate).^(-OUT.T(:));
    rows=cell(2*n*m,15); row=0;
    discountedRevenue=zeros(2*n*m,1);
    discountedSpending=zeros(2*n*m,1);
    collisionProcesses={'collision_damage','collision_destruction','active_collision_loss'};
    for pop={'S','Su'}
        species=pop{1};
        for i=1:m
            owner=OUT.owners.ids{i};
            for k=1:n
                active=OUT.owners.(species)(:,k,i);
                active=active(:);
                revenue=trapz(OUT.T,active.*marketRevenue(:));
                count=OUT.launches.(species)(k,i)*years;
                unitCost=costs.cost(k)*ownerEconomics.cost_multiplier(i);
                launchCost=count*unitCost;
                lost=strcmp(flows.owner_id,owner) & strcmp(flows.population,species) & ...
                    flows.shell==k & ismember(flows.process,collisionProcesses);
                collisionLoss=sum(flows.source_count(lost));
                row=row+1;
                rows(row,:)={startTime,endTime,owner,k,species,active(1),active(end), ...
                    marketRevenue(1),marketRevenue(end),revenue,count,unitCost, ...
                    launchCost,collisionLoss,revenue-launchCost};
                discountedRevenue(row)=trapz(OUT.T,active.*marketRevenue(:).*discountFactor);
                discountedSpending(row)=unitCost*OUT.launches.(species)(k,i)* ...
                    trapz(OUT.T,discountFactor);
            end
        end
    end
    ledger=cell2table(rows,'VariableNames',{'start_time','end_time','owner_id', ...
        'shell','population','active_start','active_end', ...
        'market_revenue_per_satellite_start','market_revenue_per_satellite_end', ...
        'modeled_revenue','launched_count','deployment_cost_per_satellite', ...
        'launch_spending','collision_loss_count','cash_flow_proxy'});
    ledger.owner_id=string(ledger.owner_id);
    ledger.population=string(ledger.population);
    ledger.nominal_collision_asset_value=ledger.collision_loss_count.*ledger.deployment_cost_per_satellite;
    ledger.discounted_revenue=discountedRevenue;
    ledger.discounted_launch_spending=discountedSpending;
    ledger.discounted_cash_flow_proxy=discountedRevenue-discountedSpending;
end
