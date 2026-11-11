function economics = loadOwnerEconomics(parameter_file,owners)
% Optional owner-specific multiplier on the shared upstream deployment cost.
% Revenue, discount rate and tax remain shared OPUS parameters.
    ids=string(owners.ids(:));
    economics=table(ids,ones(numel(ids),1),'VariableNames',{'owner_id','cost_multiplier'});
    [parent,stem]=fileparts(parameter_file);
    file=fullfile(parent,[stem '-economics.csv']);
    if ~isfile(file), return; end
    values=readtable(file,'TextType','string','VariableNamingRule','preserve');
    if ~isequal(sort(values.Properties.VariableNames),sort(economics.Properties.VariableNames))
        error('OPUS:InvalidOwnerEconomics','Owner economics CSV requires owner_id,cost_multiplier.');
    end
    if height(values)==0, return; end
    if any(ismissing(values.owner_id)) || ...
            ~isnumeric(values.cost_multiplier) || ...
            any(~isfinite(values.cost_multiplier) | values.cost_multiplier<=0)
        error('OPUS:InvalidOwnerEconomics','Cost multipliers must be finite and positive, with nonempty owner IDs.');
    end
    [known,index]=ismember(lower(values.owner_id),lower(ids));
    if ~all(known) || numel(unique(index))~=height(values)
        error('OPUS:InvalidOwnerEconomics','Use each existing owner at most once.');
    end
    economics.cost_multiplier(index)=values.cost_multiplier;
end
