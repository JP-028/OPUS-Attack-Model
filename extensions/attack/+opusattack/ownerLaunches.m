function [launches,decisions] = ownerLaunches(owners,rules,VAR,intervalYears)
% Decide independently from each owner's CURRENT active count at an interval start.
% Replacement is population/Dt. Target follows upstream min(cap,remaining),
% with remaining/intervalYears so rates retain satellites/year units.
    validateattributes(intervalYears,{'numeric'},{'scalar','positive','finite'});
    n=VAR.N_shell; m=numel(owners.ids);
    launches.S=owners.S/VAR.Dt;
    launches.Su=owners.Su/VAR.Dt;
    rows=cell(2*n*m,8); q=0;
    for pop={'S','Su'}
        species=pop{1};
        for i=1:m
            for k=1:n
                current=owners.(species)(k,i);
                mode="replacement"; target=NaN; cap=Inf;
                hit=find(strcmpi(rules.owner_id,owners.ids{i}) & rules.shell==k & rules.population==string(species));
                rate=current/VAR.Dt;
                if ~isempty(hit)
                    mode=rules.mode(hit); target=rules.target_size(hit); cap=rules.max_launch_rate(hit);
                    switch mode
                        case "target", rate=min(cap,max(target-current,0)/intervalYears);
                        case "replacement", rate=min(cap,current/VAR.Dt);
                        case "fixed", rate=cap;
                        case "none", rate=0;
                    end
                end
                launches.(species)(k,i)=rate;
                q=q+1;
                rows(q,:)={owners.ids{i},k,species,char(mode),current,target,cap,rate};
            end
        end
    end
    decisions=cell2table(rows,'VariableNames',{'owner_id','shell','population','mode', ...
        'current_count','target_size','max_launch_rate','launch_rate'});
end
