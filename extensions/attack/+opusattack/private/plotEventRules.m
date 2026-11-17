function plotEventRules(ax,events,style)
% Event times have no in-axes text labels. Co-located types get one rule.
    if isempty(events), return; end
    times=unique(events.time);
    for j=1:numel(times)
        types=unique(events.type(events.time==times(j)));
        if numel(types)>1
            lineStyle='-.';
        elseif types=="F"
            lineStyle=':';
        else
            lineStyle='--';
        end
        xline(ax,times(j),lineStyle,'Color',style.light, ...
            'LineWidth',0.9,'HandleVisibility','off');
    end
end
