function [launches,diagnostics] = economicLaunches(owners,N,launches,decisions,V,econ,costs,ownerEconomics,intervalYears)
% Bounded owner best responses using OPUS's one-interval physical forecast.
% Only explicitly selected economic rows are optimized. Other rules stay fixed.
    rows=find(strcmp(decisions.mode,'economic'));
    diagnostics=table;
    if isempty(rows), return; end
    x0=[sum(owners.S,2);sum(owners.D,2);N;sum(owners.Su,2)];
    oldWarnings=warning; warningCleanup=onCleanup(@() warning(oldWarnings)); %#ok<NASGU>
    oldPath=path; pathCleanup=onCleanup(@() path(oldPath)); %#ok<NASGU>
    ext=fileparts(fileparts(fileparts(mfilename('fullpath'))));
    root=fileparts(fileparts(ext));
    addpath(root,fullfile(root,'MOCAT4S'));
    converged=false;
    for pass=1:20
        previous=zeros(numel(rows),1);
        for z=1:numel(rows)
            d=decisions(rows(z),:); i=find(strcmp(owners.ids,d.owner_id{1}));
            pop=d.population{1}; k=d.shell; cap=d.max_launch_rate;
            previous(z)=launches.(pop)(k,i);
            if cap==0, continue; end
            multiplier=ownerEconomics.cost_multiplier(i);
            value0=atRate(0);
            if value0<=0
                desired=0;
            else
                valueCap=atRate(cap);
                if valueCap>=0
                    desired=cap;
                else
                    lower=0; upper=cap;
                    for step=1:16
                        mid=(lower+upper)/2;
                        if atRate(mid)>0, lower=mid; else, upper=mid; end
                    end
                    desired=(lower+upper)/2;
                end
            end
            % Direct Gauss-Seidel usually settles in two sweeps. Dampen only
            % after that if coupled revenue responses have not settled.
            if numel(rows)==1 || pass<=2, damping=1; else, damping=0.5; end
            launches.(pop)(k,i)=previous(z)+damping*(desired-previous(z));
        end
        current=zeros(numel(rows),1);
        for z=1:numel(rows)
            d=decisions(rows(z),:); i=find(strcmp(owners.ids,d.owner_id{1}));
            current(z)=launches.(d.population{1})(d.shell,i);
        end
        caps=decisions.max_launch_rate(rows);
        if all(abs(current-previous)<=1e-4*max(1,caps))
            converged=true; break
        end
    end
    if ~converged
        error('OPUS:EconomicLaunchNotConverged', ...
            'Owner economic launch best responses did not converge within 20 sweeps.');
    end
    forecast=project();
    diagnostics=decisions(rows,{'owner_id','shell','population','current_count','max_launch_rate'});
    diagnostics.owner_id=string(diagnostics.owner_id);
    diagnostics.population=string(diagnostics.population);
    diagnostics.launch_rate=current;
    diagnostics.projected_revenue_per_satellite_year=zeros(numel(rows),1);
    diagnostics.projected_collision_probability=zeros(numel(rows),1);
    diagnostics.deployment_cost_per_satellite=zeros(numel(rows),1);
    diagnostics.projected_excess_return_percent=zeros(numel(rows),1);
    diagnostics.best_response_sweeps=repmat(pass,numel(rows),1);
    for z=1:numel(rows)
        d=decisions(rows(z),:); i=find(strcmp(owners.ids,d.owner_id{1}));
        [excess,revenue,prob,cost]=economicReturn(forecast,d.population{1},d.shell,V,econ,costs, ...
            ownerEconomics.cost_multiplier(i));
        diagnostics.projected_revenue_per_satellite_year(z)=revenue;
        diagnostics.projected_collision_probability(z)=prob;
        diagnostics.deployment_cost_per_satellite(z)=cost;
        diagnostics.projected_excess_return_percent(z)=excess;
    end
    function value=atRate(candidate)
        launches.(pop)(k,i)=candidate;
        projected=project();
        value=economicReturn(projected,pop,k,V,econ,costs,multiplier);
        launches.(pop)(k,i)=previous(z);
    end
    function projected=project()
        lam=[sum(launches.S,2),sum(launches.Su,2)];
        projected=MOCAT4S([0,intervalYears],x0,lam,V);
        if any(~isfinite([projected.S(end,:),projected.D(end,:), ...
                projected.N(end,:),projected.Su(end,:)]))
            error('OPUS:InvalidOwnerEconomics','Economic forecast produced a nonfinite state.');
        end
    end
end
