function record=attackEconomics(report,owners,econ,costs,ownerEconomics)
% Replacement-cost reference and current annual revenue exposure at an attack.
% These are valuation inputs, not a counterfactual realized loss estimate.
    owner=string(report.owner_id(1));
    i=find(strcmp(string(owners.ids),owner),1);
    k=report.shell(1);
    revenue=econ.intercept-econ.coef*sum(owners.Su(:));
    unitCost=costs.cost(k)*ownerEconomics.cost_multiplier(i);
    type="fragmentation";
    if ismember('disabled_count',report.Properties.VariableNames), type="disabling"; end
    count=report.requested_count(1);
    record=table(string(report.event_id(1)),report.time_year(1),type,owner,k, ...
        string(report.population(1)),count,revenue,unitCost,count*unitCost, ...
        'VariableNames',{'event_id','time_year','event_type','owner_id','shell', ...
        'population','affected_count','market_revenue_per_satellite_year', ...
        'deployment_cost_per_satellite','nominal_replacement_cost'});
end
