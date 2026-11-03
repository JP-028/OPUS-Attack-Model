function events = loadAttackEvents(parameter_file,owners,n)
% Optional <scenario>-events.csv. First version: at most one satellite destroyed.
    names={'event_id','time_year','event_type','owner_id','shell','population','count'};
    empty=table('Size',[0,7],'VariableTypes',{'string','double','string','string','double','string','double'}, ...
        'VariableNames',names);
    [parent,stem]=fileparts(parameter_file);
    file=fullfile(parent,[stem '-events.csv']);
    events=empty;
    if ~isfile(file), return; end
    data=readtable(file,'TextType','string','VariableNamingRule','preserve');
    if ~isequal(sort(data.Properties.VariableNames),sort(names))
        error('OPUS:InvalidAttackEvents','Event CSV requires event_id,time_year,event_type,owner_id,shell,population,count.');
    end
    if height(data)==0, return; end
    if height(data)>1
        error('OPUS:MultipleAttackEventsNotSupported','This version permits one fragmentation event destroying one satellite.');
    end
    data=data(:,names);
    for name={'time_year','shell','count'}
        v=data.(name{1});
        if ~isnumeric(v) || ~isreal(v) || any(~isfinite(v))
            error('OPUS:InvalidAttackEvents','%s must contain finite numeric values.',name{1});
        end
    end
    for name={'event_id','event_type','owner_id','population'}
        v=string(data.(name{1}));
        if any(ismissing(v)) || any(strlength(v)==0)
            error('OPUS:InvalidAttackEvents','%s must not be blank.',name{1});
        end
        data.(name{1})=v;
    end
    if isempty(regexp(char(data.event_id),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')) || ...
            data.time_year<0 || data.shell<1 || data.shell>n || data.shell~=fix(data.shell) || ...
            data.event_type~="fragmentation" || ~ismember(data.population,["S","Su"])
        error('OPUS:InvalidAttackEvents','Use a valid event ID, nonnegative time, shell index, fragmentation type, and S or Su.');
    end
    if data.count~=1
        error('OPUS:UnsupportedAttackSize','This version destroys exactly one satellite; count must be 1.');
    end
    i=find(strcmpi(owners.ids,data.owner_id),1);
    if isempty(i), error('OPUS:InvalidAttackEvents','Unknown attacked owner: %s.',data.owner_id); end
    data.owner_id=string(owners.ids{i});
    events=data;
end
