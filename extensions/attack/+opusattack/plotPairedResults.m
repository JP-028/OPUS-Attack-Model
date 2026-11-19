function report=plotPairedResults(pairFolder,outputFolder)
% Export publication-style figures from a completed attacked/control pair.
% The simulation and its input files are never modified or rerun.
    if nargin<1, error('OPUS:MissingPlotPair','Supply a paired result folder.'); end
    data=readPlotPair(pairFolder);
    if nargin<2 || isempty(outputFolder)
        outputFolder=fullfile(data.folder,'figures');
    end
    outputFolder=char(string(outputFolder));
    if isfolder(outputFolder) || isfile(outputFolder)
        error('OPUS:PlotOutputExists','Figure output already exists: %s',outputFolder);
    end
    [ok,message]=mkdir(outputFolder);
    if ~ok, error('OPUS:PlotExportFailed','%s',message); end
    style=plotAppearance();
    names=strings(0,1); subjects=strings(0,1); descriptions=strings(0,1);
    for i=1:numel(data.targetOwners)
        owner=data.targetOwners(i);
        stem=char(owner);
        f=activeFigure(data,owner,style);
        exportPaperFigure(f,outputFolder,['01-active-fleet-' stem]);
        names(end+1,1)="01-active-fleet-"+owner;
        subjects(end+1,1)=owner;
        descriptions(end+1,1)="Active S+Su and attacked-minus-control difference over time";
        f=economicFigure(data,owner,style);
        exportPaperFigure(f,outputFolder,['03-economic-trajectory-' stem]);
        names(end+1,1)="03-economic-trajectory-"+owner;
        subjects(end+1,1)=owner;
        descriptions(end+1,1)="Cumulative discounted cash-flow proxy difference";
        f=componentsFigure(data,owner,style);
        exportPaperFigure(f,outputFolder,['04-economic-components-' stem]);
        names(end+1,1)="04-economic-components-"+owner;
        subjects(end+1,1)=owner;
        descriptions(end+1,1)="Revenue and spending contributions to cash-flow difference";
        f=economicDevelopmentFigure(data,owner,style);
        exportPaperFigure(f,outputFolder,['06-economic-development-' stem]);
        names(end+1,1)="06-economic-development-"+owner;
        subjects(end+1,1)=owner;
        descriptions(end+1,1)="Annualized revenue and cash-flow proxy, with paired differences";
    end
    f=debrisFigure(data,style);
    exportPaperFigure(f,outputFolder,'02-debris-by-altitude');
    names(end+1,1)="02-debris-by-altitude";
    subjects(end+1,1)="all targeted owners";
    descriptions(end+1,1)="Shell-average debris difference over time";
    manifest=table(names,subjects,descriptions, ...
        'VariableNames',{'figure','subject','description'});
    writetable(manifest,fullfile(outputFolder,'figure-manifest.csv'));
    writeCaptions(outputFolder,data);
    fid=fopen(fullfile(outputFolder,'COMPLETE.txt'),'w','n','UTF-8');
    if fid<0, error('OPUS:PlotExportFailed','Cannot write figure completion marker.'); end
    fprintf(fid,'Figure export finished successfully.\n');
    fclose(fid);
    report=struct('output_directory',outputFolder,'manifest',manifest);
end

function f=activeFigure(data,owner,style)
    [ta,ya]=activeSeries(data.attackedOwners,owner);
    [tc,yc]=activeSeries(data.controlOwners,owner);
    baseline=interp1(tc,yc,ta,'linear');
    if any(~isfinite(baseline)), error('OPUS:InvalidPlotSeries','Control fleet times do not cover attack times.'); end
    f=paperFigure(18,12);
    layout=tiledlayout(f,2,1,'Padding','loose','TileSpacing','loose');
    title(layout,'Active fleet: '+owner,'Interpreter','none','FontWeight','normal');
    ax=nexttile(layout);
    decorate(ax,style);
    plotEventRules(ax,data.events,style);
    control=plot(ax,tc,yc,'--','Color',style.grey,'LineWidth',1.35);
    hold(ax,'on');
    attacked=plot(ax,ta,ya,'-','Color',style.orange,'LineWidth',1.65);
    ylabel(ax,'Active S + Su (satellites)');
    xlim(ax,[0 max(ta)]);
    legend(ax,[attacked control],{'Attacked','No attack'}, ...
        'Location','northeastoutside','Box','off');
    ax2=nexttile(layout);
    decorate(ax2,style);
    plotEventRules(ax2,data.events,style);
    yline(ax2,0,'-','Color',style.light,'LineWidth',0.8,'HandleVisibility','off');
    plot(ax2,ta,ya-baseline,'-','Color',style.orange,'LineWidth',1.65);
    xlabel(ax2,'Simulation time (years)');
    ylabel(ax2,'Difference (satellites)');
    xlim(ax2,[0 max(ta)]);
end

function f=debrisFigure(data,style)
    [ta,na]=debrisSeries(data.attackedShells);
    [tc,nc]=debrisSeries(data.controlShells);
    baseline=interp1(tc,nc,ta,'linear');
    if any(~isfinite(baseline(:))), error('OPUS:InvalidPlotSeries','Control debris times do not cover attack times.'); end
    delta=na-baseline;
    n=size(delta,2);
    root=fileparts(fileparts(mfilename('fullpath')));
    shells=readtable(fullfile(root,'templates','shell-reference.csv'));
    if height(shells)<n
        error('OPUS:InvalidPlotSeries','The shell reference does not cover all plotted shells.');
    end
    altitude=(shells.lower_altitude_km(1:n)+shells.upper_altitude_km(1:n))/2;
    f=paperFigure(18,10);
    ax=axes(f,'Position',[0.13 0.17 0.67 0.73]);
    decorate(ax,style);
    x=repmat(ta(:)',n,1);
    y=repmat(altitude(:),1,numel(ta));
    surf(ax,x,y,zeros(size(x)),delta','FaceColor','interp','EdgeColor','none');
    view(ax,2);
    colormap(ax,divergingMap(style));
    limit=max(abs(delta(:)));
    if limit<1e-9, limit=1; end
    clim(ax,[-limit limit]);
    colorbarHandle=colorbar(ax,'eastoutside');
    colorbarHandle.Label.String='Change in N (objects)';
    colorbarHandle.FontName=style.font;
    colorbarHandle.FontSize=style.fontSize;
    xlabel(ax,'Simulation time (years)');
    ylabel(ax,'Altitude (km)');
    title(ax,'Debris: attacked minus no attack','FontWeight','normal');
    xlim(ax,[0 max(ta)]);
    strength=max(abs(delta),[],1);
    affected=find(strength>=max(1e-8,0.01*limit));
    targets=[data.fragmentations.shell;data.disablings.shell];
    focus=unique([affected(:);targets(:)]);
    if isempty(focus), focus=(1:n)'; end
    low=max(1,min(focus)-2);
    high=min(n,max(focus)+2);
    ylim(ax,[shells.lower_altitude_km(low),shells.upper_altitude_km(high)]);
    plotEventRules(ax,data.events,style);
end

function f=economicFigure(data,owner,style)
    [ta,mainA]=economicSeries(data.attackedEconomics,owner,true);
    [tc,mainC]=economicSeries(data.controlEconomics,owner,true);
    [to,otherA]=economicSeries(data.attackedEconomics,owner,false);
    [tp,otherC]=economicSeries(data.controlEconomics,owner,false);
    if ~isequal(ta,tc,to,tp)
        error('OPUS:InvalidPlotSeries','Paired economic intervals do not match.');
    end
    f=paperFigure(18,12);
    layout=tiledlayout(f,2,1,'Padding','loose','TileSpacing','loose');
    title(layout,'Discounted cash-flow difference: '+owner, ...
        'Interpreter','none','FontWeight','normal');
    ax=nexttile(layout);
    decorate(ax,style);
    plotEventRules(ax,data.events,style);
    yline(ax,0,'-','Color',style.light,'HandleVisibility','off');
    plot(ax,ta,(mainA-mainC)/1e6,'-o','Color',style.orange, ...
        'MarkerFaceColor',style.orange,'MarkerSize',3.5,'LineWidth',1.5);
    ylabel(ax,'Attacked owner (USD million)');
    xlim(ax,[0 max(ta)]);
    ax2=nexttile(layout);
    decorate(ax2,style);
    plotEventRules(ax2,data.events,style);
    yline(ax2,0,'-','Color',style.light,'HandleVisibility','off');
    plot(ax2,ta,(otherA-otherC)/1e6,'-o','Color',style.blue, ...
        'MarkerFaceColor',style.blue,'MarkerSize',3.5,'LineWidth',1.5);
    ylabel(ax2,'Other owners (USD million)');
    xlabel(ax2,'Simulation time (years)');
    xlim(ax2,[0 max(ta)]);
end

function f=economicDevelopmentFigure(data,owner,style)
    [ta,ra,ca]=ownerEconomicRates(data.attackedEconomics,owner);
    [tc,rc,cc]=ownerEconomicRates(data.controlEconomics,owner);
    if ~isequal(ta,tc)
        error('OPUS:InvalidPlotSeries','Paired economic intervals do not match.');
    end
    f=paperFigure(22,14);
    layout=tiledlayout(f,2,2,'Padding','loose','TileSpacing','loose');
    title(layout,'Economic development: '+owner,'Interpreter','none','FontWeight','normal');
    ax=nexttile(layout,1);
    decorate(ax,style);
    plotEventRules(ax,data.events,style);
    attacked=stairs(ax,ta,[ra;ra(end)],'-','Color',style.orange,'LineWidth',1.55);
    control=stairs(ax,ta,[rc;rc(end)],'--','Color',style.grey,'LineWidth',1.25);
    ylabel(ax,'Revenue (USD million/year)');
    xlim(ax,[ta(1) ta(end)]);
    legend(ax,[attacked control],{'Attacked','No attack'}, ...
        'Location','northwest','Box','off');
    padY(ax,[ra;rc]);
    ax=nexttile(layout,2);
    decorate(ax,style);
    plotEventRules(ax,data.events,style);
    stairs(ax,ta,[ca;ca(end)],'-','Color',style.orange,'LineWidth',1.55);
    stairs(ax,ta,[cc;cc(end)],'--','Color',style.grey,'LineWidth',1.25);
    ylabel(ax,'Cash-flow proxy (USD million/year)');
    padY(ax,[ca;cc]);
    xlim(ax,[ta(1) ta(end)]);
    ax=nexttile(layout,3);
    decorate(ax,style);
    plotEventRules(ax,data.events,style);
    yline(ax,0,'-','Color',style.light,'HandleVisibility','off');
    delta=ra-rc;
    stairs(ax,ta,[delta;delta(end)],'-','Color',style.blue,'LineWidth',1.55);
    ylabel(ax,'Revenue difference (USD million/year)');
    padY(ax,[delta;0]);
    xlabel(ax,'Simulation time (years)');
    xlim(ax,[ta(1) ta(end)]);
    ax=nexttile(layout,4);
    decorate(ax,style);
    plotEventRules(ax,data.events,style);
    yline(ax,0,'-','Color',style.light,'HandleVisibility','off');
    delta=ca-cc;
    stairs(ax,ta,[delta;delta(end)],'-','Color',style.blue,'LineWidth',1.55);
    ylabel(ax,'Cash-flow difference (USD million/year)');
    padY(ax,[delta;0]);
    xlabel(ax,'Simulation time (years)');
    xlim(ax,[ta(1) ta(end)]);
end

function [edges,revenue,cashFlow]=ownerEconomicRates(rows,owner)
    rows=rows(rows.owner_id==owner,:);
    if isempty(rows)
        error('OPUS:InvalidPlotSeries','Owner %s has no economic records.',owner);
    end
    ends=unique(rows.end_time);
    starts=zeros(numel(ends),1);
    revenue=zeros(numel(ends),1);
    cashFlow=zeros(numel(ends),1);
    for j=1:numel(ends)
        segment=rows(rows.end_time==ends(j),:);
        start=unique(segment.start_time);
        if numel(start)~=1 || ends(j)<=start
            error('OPUS:InvalidPlotSeries','Invalid economic interval for %s.',owner);
        end
        starts(j)=start;
        duration=ends(j)-start;
        revenue(j)=sum(segment.modeled_revenue)/duration/1e6;
        cashFlow(j)=sum(segment.cash_flow_proxy)/duration/1e6;
    end
    if any(abs(starts(2:end)-ends(1:end-1))>1e-8)
        error('OPUS:InvalidPlotSeries','Economic intervals are not contiguous for %s.',owner);
    end
    edges=[starts(1);ends];
end
function f=componentsFigure(data,owner,style)
    row=data.impact(data.impact.owner_id==owner,:);
    if height(row)~=1, error('OPUS:InvalidPlotSeries','Expected one impact row for %s.',owner); end
    values=[row.delta_modeled_revenue; -row.delta_launch_spending; ...
        row.delta_cash_flow_proxy]/1e6;
    if abs(values(1)+values(2)-values(3))>1e-6*max(1,max(abs(values)))
        error('OPUS:InvalidPlotSeries','Cash-flow components do not balance.');
    end
    f=paperFigure(18,8);
    ax=axes(f,'Position',[0.32 0.22 0.60 0.65]);
    decorate(ax,style);
    b=barh(ax,1:3,values,0.48,'FaceColor','flat','EdgeColor','none');
    b.CData=[style.blue;style.orange;style.dark];
    ax.YDir='reverse';
    ax.YTick=1:3;
    ax.YTickLabel={'Revenue change','Less: spending change','Net cash-flow change'};
    limit=max(abs(values));
    if limit<0.01, limit=0.01; end
    xlim(ax,[-1.15*limit,1.45*limit]);
    ylim(ax,[0.45 3.55]);
    xline(ax,0,'-','Color',style.grey,'LineWidth',0.8);
    for j=1:3
        text(ax,1.35*limit,j,sprintf('%+.3f',values(j)), ...
            'HorizontalAlignment','right','VerticalAlignment','middle', ...
            'FontName',style.font,'FontSize',style.fontSize,'Color',style.dark);
    end
    title(ax,'Economic components: '+owner,'Interpreter','none','FontWeight','normal');
    xlabel(ax,'Attacked minus control (USD million)');
end

function [time,value]=activeSeries(rows,owner)
    hit=rows.owner_id==owner;
    if ~any(hit), error('OPUS:InvalidPlotSeries','Owner %s is missing from population history.',owner); end
    index=rows.sample_index(hit);
    count=max(rows.sample_index);
    time=accumarray(index,rows.time(hit),[count,1],@min);
    value=accumarray(index,rows.S(hit)+rows.Su(hit),[count,1],@sum);
    if any(diff(time)<0), error('OPUS:InvalidPlotSeries','Population times are not ordered.'); end
end

function [time,value]=debrisSeries(rows)
    count=max(rows.sample_index);
    shells=max(rows.shell);
    time=accumarray(rows.sample_index,rows.time,[count,1],@min);
    value=accumarray([rows.sample_index,rows.shell],rows.N,[count,shells],@sum);
    if any(diff(time)<0), error('OPUS:InvalidPlotSeries','Debris times are not ordered.'); end
end

function [time,value]=economicSeries(rows,owner,selectedOwner)
    endTimes=unique(rows.end_time);
    time=[0;endTimes];
    value=zeros(numel(time),1);
    if selectedOwner, mask=rows.owner_id==owner;
    else, mask=rows.owner_id~=owner;
    end
    for j=1:numel(endTimes)
        value(j+1)=value(j)+sum(rows.discounted_cash_flow_proxy( ...
            mask & rows.end_time==endTimes(j)));
    end
end

function padY(ax,values)
    low=min(values(:));
    high=max(values(:));
    span=high-low;
    if span<1e-10, span=max(1,0.05*abs(high)); end
    margin=0.08*span;
    ylim(ax,[low-margin high+margin]);
end
function f=paperFigure(width,height)
    f=figure('Visible','off','Color','white','Units','centimeters', ...
        'Position',[2 2 width height],'Renderer','painters');
end

function decorate(ax,style)
    set(ax,'FontName',style.font,'FontSize',style.fontSize, ...
        'XColor',style.dark,'YColor',style.dark,'Color',style.paper, ...
        'TickDir','out','Box','off','LineWidth',0.7);
    hold(ax,'on');
end

function map=divergingMap(style)
    t=linspace(0,1,128)';
    low=(1-t)*style.blue+t*style.paper;
    high=(1-t(2:end))*style.paper+t(2:end)*style.orange;
    map=[low;high];
end

function writeCaptions(folder,data)
    file=fullfile(folder,'FIGURE_CAPTIONS.md');
    fid=fopen(file,'w','n','UTF-8');
    if fid<0, error('OPUS:PlotExportFailed','Cannot write figure captions.'); end
    cleaner=onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'# Figure captions and interpretation\n\n');
    fprintf(fid,'All differences are attacked minus no-attack control. ');
    fprintf(fid,'F = fragmentation; D = disabling. Vertical dotted, dashed, and dash-dot rules ');
    fprintf(fid,'mark F, D, and simultaneous mixed event times. ');
    fprintf(fid,'Continuous counts are expected populations, not individual incidents. ');
    fprintf(fid,'The blue-white-orange debris scale is centred on zero. ');
    fprintf(fid,'Economic values use the OPUS-based proxy, not company profit. ');
    fprintf(fid,'The palette is inspired by UniBw M public orange/blue/grey materials; ');
    fprintf(fid,'exact university CI values were not available.\n\n');
    fprintf(fid,'| Time (years) | Type | Target owner |\n| ---: | --- | --- |\n');
    for i=1:height(data.events)
        fprintf(fid,'| %.6g | %s | %s |\n',data.events.time(i), ...
            char(data.events.type(i)),char(data.events.owner(i)));
    end
    fprintf(fid,'\n**01 Active fleet:** S + Su counts and their difference. ');
    fprintf(fid,'Repeated attack timestamps show immediate pre/post jumps.\n\n');
    fprintf(fid,'**02 Debris:** Difference in shared N by altitude and time. ');
    fprintf(fid,'The altitude view includes changed and targeted shells, with two shells of context. This is shell-average model output, not a spatial debris cloud.\n\n');
    fprintf(fid,'**03 Economic trajectory:** Cumulative discounted cash-flow proxy ');
    fprintf(fid,'at recorded interval ends; plotted segments are not smoothed estimates.\n\n');
    fprintf(fid,'**04 Economic components:** Change in revenue, negated change in ');
    fprintf(fid,'spending, and their sum as the net cash-flow proxy change. ');
    fprintf(fid,'Reduced spending is shown as a positive contribution.\n\n');
    fprintf(fid,'**06 Economic development:** Each step is one model interval, annualized ');
    fprintf(fid,'by its duration. Upper panels show attacked and control revenue and ');
    fprintf(fid,'cash-flow proxy; lower panels show attacked-minus-control differences. ');
    fprintf(fid,'These are modeled economic rates, not measured company growth or profit.\n');
end
