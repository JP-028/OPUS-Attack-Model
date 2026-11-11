function rules = loadLaunchRules(parameter_file, owners, n)
% Optional <scenario>-launches.csv. Unlisted owner/shell/species use replacement.
    [parent,stem]=fileparts(parameter_file);
    file=fullfile(parent,[stem '-launches.csv']);
    names={'owner_id','shell','population','mode','target_size','max_launch_rate'};
    if ~isfile(file)
        rules=table('Size',[0,6],'VariableTypes',{'string','double','string','string','double','double'},'VariableNames',names);
        return
    end
    rules=readtable(file,'TextType','string','VariableNamingRule','preserve');
    if ~isequal(sort(rules.Properties.VariableNames),sort(names))
        error('OPUS:InvalidLaunchRules','Launch CSV must have owner_id,shell,population,mode,target_size,max_launch_rate columns.');
    end
    if height(rules)==0
        rules=table('Size',[0,6],'VariableTypes',{'string','double','string','string','double','double'},'VariableNames',names);
        return
    end
    rules=rules(:,names);
    for field={'shell','target_size','max_launch_rate'}
        x=rules.(field{1});
        if ~isnumeric(x) || any(~isfinite(x)) || any(x<0)
            error('OPUS:InvalidLaunchRules','%s must contain finite nonnegative numbers.',field{1});
        end
    end
    if any(rules.shell<1 | rules.shell>n | rules.shell~=fix(rules.shell)) || ...
            any(~ismember(rules.population,["S","Su"])) || ...
            any(~ismember(rules.mode,["target","replacement","fixed","none","economic"])) || ...
            any(~ismember(lower(rules.owner_id),lower(string(owners.ids))))
        error('OPUS:InvalidLaunchRules','Unknown owner, shell, population, or launch mode.');
    end
    key=lower(rules.owner_id)+"/"+string(rules.shell)+"/"+rules.population;
    if numel(unique(key))~=height(rules)
        error('OPUS:InvalidLaunchRules','Only one rule per owner, shell and population is allowed.');
    end
    unused=rules.mode~="target";
    if any(rules.target_size(unused)~=0) || any(rules.max_launch_rate(rules.mode=="none")~=0)
        error('OPUS:InvalidLaunchRules','Use target_size=0 outside target mode, and max_launch_rate=0 for none mode.');
    end
end
