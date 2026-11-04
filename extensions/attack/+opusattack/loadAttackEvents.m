function events = loadAttackEvents(parameter_file,owners,n)
% Optional <scenario>-events.csv for fragmentation and disabling attacks.
% Execute chronologically; equal-time rows retain their order in the CSV.
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
    validIDs=~cellfun('isempty',regexp(cellstr(data.event_id),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once'));
    if any(~validIDs) || any(data.time_year<0) || any(data.shell<1 | data.shell>n | data.shell~=fix(data.shell)) || ...
            any(~ismember(data.event_type,["fragmentation","disabling"])) || any(~ismember(data.population,["S","Su"]))
        error('OPUS:InvalidAttackEvents','Use a valid event ID, nonnegative time, shell index, fragmentation or disabling type, and S or Su.');
    end
    if numel(unique(lower(data.event_id)))~=height(data)
        error('OPUS:DuplicateAttackEventId','Every attack row must have a unique event_id, ignoring case.');
    end
    if any(data.count<1 | data.count~=fix(data.count)) || ...
            any(data.count(data.event_type=="fragmentation")~=1)
        error('OPUS:UnsupportedAttackSize','Fragmentation requires count=1; disabling requires a positive integer count.');
    end
    for row=1:height(data)
        i=find(strcmpi(owners.ids,data.owner_id(row)),1);
        if isempty(i)
            error('OPUS:InvalidAttackEvents','Event %s targets unknown owner: %s.',data.event_id(row),data.owner_id(row));
        end
        data.owner_id(row)=string(owners.ids{i});
    end
    [~,order]=sortrows([data.time_year,(1:height(data))'],[1,2]);
    events=data(order,:);
end
