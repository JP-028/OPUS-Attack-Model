function [flows,events,participants] = flowTables(OUT,startTime,endTime,eventOffset)
% Convert integrated channels to interval records; never invent incident times.
    f=OUT.flow_definition;
    quantity=OUT.cumulative_flows(end,:)';
    flows=f(:,{'process','shell','destination_shell','owner_id','counterpart_owner_id', ...
        'population','counterpart_population','destination_population','destination_owner_id'});
    flows.start_time=repmat(startTime,height(f),1);
    flows.end_time=repmat(endTime,height(f),1);
    flows.quantity=quantity;
    flows.source_count=quantity.*(f.source_index>0);
    flows.destination_count=quantity.*f.yield;
    flows=flows(quantity~=0,:); % Zero channels remain in the MAT interval data.
    major=ismember(flows.process,{'launch','collision_damage','collision_destruction', ...
        'active_collision_loss','derelict_collision_loss','debris_generation'});
    events=flows(major,:);
    events.event_id=compose("e%09d",(eventOffset+(1:height(events)))');
    events.record_kind=repmat("interval_expectation",height(events),1);
    events.record_kind(strcmp(events.process,'launch'))="continuous_launch";
    events.event_time=nan(height(events),1); % Future instantaneous attacks set this.
    participants=table('Size',[0,4],'VariableTypes',{'string','string','string','string'}, ...
        'VariableNames',{'event_id','owner_id','role','population'});
    for i=1:height(events)
        if ~isempty(events.owner_id{i})
            participants(end+1,:)={events.event_id(i),string(events.owner_id{i}),"affected",string(events.population{i})};
        end
        if ~isempty(events.counterpart_owner_id{i})
            participants(end+1,:)={events.event_id(i),string(events.counterpart_owner_id{i}),"counterpart",string(events.counterpart_population{i})};
        end
    end
end
